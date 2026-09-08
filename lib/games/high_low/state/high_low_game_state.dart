import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../audio/audio_controller.dart';
import '../../../audio/sfx_type.dart';
import '../../../audio/voice_line.dart';
import '../../../models/agency_stage.dart';
import '../../../models/concept_tier.dart';
import '../../../models/game_status.dart';
import '../../../models/pitch_direction.dart';
import '../../../models/round_order.dart';
import '../models/high_low_instrument.dart';
import '../models/high_low_prompt.dart';
import '../models/round_instrumentation.dart';
import '../services/prompt_generator.dart';
import '../services/round_sequencer.dart';

/// Result of a single completed round (a recorded, correct answer — see
/// [HighLowGameState] for why wrong Trigger attempts never appear here).
class PromptResult {
  final HighLowPrompt prompt;
  final bool isCorrect;

  const PromptResult({required this.prompt, required this.isCorrect});
}

/// Visual feedback for a Trigger-stage (A2) drop.
enum DragFeedback { none, correct, retry }

/// State machine for the High/Low game, parametrized by [AgencyStage]
/// (Trello card 91), [ConceptTier], and [RoundOrder] (Trello card 95).
///
/// A tap on an instrument always plays its note — that's exploration, at
/// every stage, and a tap alone never *shows* a right/wrong verdict the
/// way a Trigger drop's feedback does. But at A0/A1 a repeated tap on the
/// correct instrument is still an answer, just a quiet one: five correct
/// in a row resolves the round the same way a correct Trigger drop does
/// (Trello card RqdPFKLf, "A0/A1 repeated taps") — see [tapInstrument]
/// and [_celebrateCorrect]. A wrong tap there gets nothing negative at
/// all, ever.
///
/// At every stage, whichever of Piper/Clef owns the round's target pole
/// (Piper is low, Clef is high; see [targetCharacterIsPiper] and Trello
/// card 101) stands centered as a second visual cue for what to listen
/// for, alongside the caption (Trello card 1SpHq2la) — a fixed, parent-
/// facing string (see [captionText]'s doc comment), not a transcript of
/// whichever line is currently playing. Only Trigger makes her an
/// interactive drop target — see [canDrop].
///
/// - Observe (A0): the pair auto-plays; Piper/Clef narrate low/high as
///   each note sounds (see [speakingIsPiper] for the "talker moves"
///   indicator this drives); free tapping is always available and never
///   interrupts the auto-play. No question asked in the caption, but a
///   correct tap still sparkles the owning character and a five-streak
///   still resolves the round (see above). The child can always leave via
///   [escape] (immediate) or, ~6 seconds in, [moveOn] (a resolved assist).
/// - Participate (A1): a constant prompt ("Listen for the high one"), the
///   pair auto-plays but a tap cuts it short, then free tapping continues.
///   A correct tap sparkles the owning character; five in a row resolves
///   the round automatically — no separate move-on control here (see
///   [showMoveOnControl]'s doc comment for why).
/// - Trigger (A2): same auto-play/cut-short/free-tap as Participate, plus
///   the centered character stays put as the round's drop target, and
///   two draggable instruments the child drags to her, so the character
///   speaking the prompt is always the one the child is asked to feed the
///   right instrument to. (Reversed 2026-09 from an earlier design where
///   the child dragged the character onto a fixed instrument — Trello,
///   "reverse the A2 drag interaction": this matters for planned A4,
///   ordering, where instruments are what get dragged into slots, so
///   A2-A4 now share one verb instead of switching mid-ladder.) A wrong
///   drop gets a gentle retry (fresh listen, no failure state); a correct
///   drop is recorded and auto-advances.
class HighLowGameState extends ChangeNotifier {
  /// How long each note of the intro pair rings (and its instrument
  /// wiggles/glows) before the sequence moves on — see the two call sites
  /// in [_runIntro].
  static const Duration _noteRingDuration = Duration(milliseconds: 2300);

  final AudioController _audio;
  final PromptGenerator _generator;
  final RoundSequencer _sequencer;
  final int totalPrompts;

  /// Mutable so a debug-only pre-game gate can override these (Trello card
  /// 92) before calling [startGame] — see DevSetupOverlay. Never changes
  /// mid-session.
  AgencyStage agencyStage;
  ConceptTier conceptTier;
  RoundOrder roundOrder;

  GameStatus _status = GameStatus.notStarted;
  List<HighLowPrompt> _prompts = [];
  int _currentPromptIndex = 0;
  final List<PromptResult> _results = [];
  final List<RoundInstrumentation> _instrumentation = [];

  /// Which side is audibly sounding right now, for the UI's wiggle/glow.
  int? _playingIndex;

  /// Bumped on every new round and every replay; in-flight async work
  /// (the intro sequence, a feedback-then-advance delay) checks this
  /// before acting so a stale callback from a superseded round/replay is
  /// a silent no-op instead of corrupting later state (e.g. the "Move On"
  /// arrow firing mid-feedback must not let an old delayed callback also
  /// advance a second time).
  int _roundToken = 0;

  /// The one outstanding delayed action for the current round (the intro's
  /// note-gap wait, or a post-drop feedback-then-continue delay) — a real
  /// [Timer], not a bare `Future.delayed`, specifically so it can be
  /// [Timer.cancel]ed outright whenever something supersedes it (a tap
  /// cutting the intro short, Move On, a new round). A cancelled-but-still
  /// counting-down `Future.delayed` would otherwise fire uselessly later
  /// and, in tests, trips flutter_test's "timer still pending after
  /// dispose" check.
  Timer? _pendingTimer;

  bool _introPlaying = false;

  /// Whether Participate's target-side instrument has started sparkling
  /// yet this round — used only to gate [_firstResponseCorrect] below to
  /// "before any hint existed"; no longer drives anything on screen
  /// itself (Trello card RqdPFKLf retired the old continuous
  /// instrument-sparkle hint in favor of [_characterSparkleIsPiper]'s
  /// per-tap character sparkle).
  bool _hintVisible = false;
  DragFeedback _dragFeedback = DragFeedback.none;
  int? _lastDropSide;
  VoiceLine? _activeCaption;

  /// Consecutive correct taps this round, A0/A1 only (Trello card
  /// RqdPFKLf) — a wrong tap resets this to zero; five resolves the
  /// round via [_celebrateCorrect]. Never incremented at Trigger, where
  /// tapping stays pure exploration and only a drag/drop commits.
  int _correctTapStreak = 0;

  /// Which of Piper/Clef is currently speaking a voice line, tied to real
  /// playback duration via [_speak] (Trello card PIm7xE6n) — null when
  /// neither is. See [speakingIsPiper]'s doc comment for the interlock
  /// with [_characterSparkleIsPiper].
  bool? _speakingIsPiper;

  /// Which of Piper/Clef should show the transient "found it" sparkle
  /// right now (Trello card RqdPFKLf) — see
  /// [characterSparkleIsPiper]'s doc comment.
  bool? _characterSparkleIsPiper;
  Timer? _characterSparkleTimer;

  /// Which instrument slot should show the "found it" sparkle overlay
  /// right now — see [instrumentSparkleSide]'s doc comment. Set only by
  /// [moveOn]'s resolution.
  int? _instrumentSparkleSide;

  /// Whether the round's secondary guidance (Trello card 5tdMOMh3) or the
  /// adult move-on control (Trello card xpAkja5b) should be visible right
  /// now — set true ~6 seconds into an unanswered round by [_nudgeTimer],
  /// reset on every fresh entry to [GameStatus.awaitingInput] (a new
  /// round, a replay, a retry's re-listen) so a child who's mid-retry
  /// always gets a fresh 6-second window before anything nudges again.
  bool _nudgeVisible = false;
  Timer? _nudgeTimer;

  // Per-round instrumentation (reset in _startRound; see [instrumentation]).
  bool _waitedForPlaythrough = true;
  int? _firstResponseSide;
  bool? _firstResponseCorrect;
  int _listenAgainCount = 0;

  HighLowGameState({
    AudioController? audio,
    PromptGenerator? generator,
    RoundSequencer? sequencer,
    this.totalPrompts = 5,
    this.agencyStage = AgencyStage.trigger,
    this.conceptTier = ConceptTier.t1,
    this.roundOrder = RoundOrder.blocked,
  }) : _audio = audio ?? AudioController.instance,
       _generator = generator ?? PromptGenerator(),
       _sequencer = sequencer ?? RoundSequencer();

  // ---- Session-level getters ----
  GameStatus get status => _status;
  int get currentPromptIndex => _currentPromptIndex;
  int get correctCount => _results.where((r) => r.isCorrect).length;
  List<PromptResult> get results => List.unmodifiable(_results);

  /// Local-only, in-memory behavioral signals — see [RoundInstrumentation].
  List<RoundInstrumentation> get instrumentation =>
      List.unmodifiable(_instrumentation);

  /// The round's shared instrument (see [HighLowPrompt] — both sides
  /// always match), or [HighLowInstrument.guitar] as a placeholder before
  /// [startGame] has produced a first prompt.
  HighLowInstrument get leftInstrument =>
      currentPrompt?.firstInstrument ?? HighLowInstrument.guitar;
  HighLowInstrument get rightInstrument =>
      currentPrompt?.secondInstrument ?? HighLowInstrument.guitar;

  HighLowPrompt? get currentPrompt =>
      _prompts.isNotEmpty && _currentPromptIndex < _prompts.length
      ? _prompts[_currentPromptIndex]
      : null;

  // ---- Round/phase-level getters ----
  int? get playingIndex => _playingIndex;

  /// True while the pair's auto-play sequence is actively running (i.e.
  /// hasn't finished or been cut off yet).
  bool get introPlaying => _introPlaying;

  DragFeedback get dragFeedback => _dragFeedback;

  /// Which of Piper/Clef is currently speaking, for however long the line
  /// actually takes to play (Trello card PIm7xE6n, "the talker moves") —
  /// null when neither is. Nothing else about a character moves any more
  /// (Trello card NcVPjPZ5 moved idle motion onto the instruments), which
  /// is what makes this legible as its own distinct signal.
  ///
  /// Never true for the same character [characterSparkleIsPiper] is also
  /// true for — motion means "I'm speaking", sparkle means "you found
  /// it", and a character showing both at once would blur the two
  /// (Trello cards RqdPFKLf/PIm7xE6n's shared interlock). See [_speak]
  /// and [_sparkleCorrectTapCharacter].
  bool? get speakingIsPiper => _speakingIsPiper;

  /// Which of Piper/Clef should show the transient "found it" sparkle
  /// right now (Trello card RqdPFKLf) — set for ~900ms on a correct A0/A1
  /// tap (see [tapInstrument]), then cleared. See [speakingIsPiper]'s doc
  /// comment for why this is never true for whichever character is
  /// currently speaking.
  bool? get characterSparkleIsPiper => _characterSparkleIsPiper;

  /// Which instrument slot should show the "found it" sparkle overlay
  /// right now — set only by [moveOn]'s resolution (Trello card
  /// xpAkja5b: "the correct instrument plays and sparkles"), not by an
  /// organic correct drop or the A0/A1 tap streak, whose own celebration
  /// animations already draw the eye without needing it.
  int? get instrumentSparkleSide => _instrumentSparkleSide;

  /// Which side the dragged character was last dropped on (correct or
  /// not) — the UI uses this to know which instrument to animate for
  /// [dragFeedback].
  int? get lastDropSide => _lastDropSide;

  /// Parent-facing guidance for the current round — not a transcript of
  /// the voice line (Trello card 5tdMOMh3, "Captions become parent
  /// guidance, not a transcript of the voice line"). Six captions total:
  /// keyed by [agencyStage] and pole only, never by age band or by which
  /// individual voice line happens to be playing — the parent is the same
  /// adult whatever the child's age (band-specific work all happens in
  /// the voice, not here), and this stays constant for the whole round
  /// rather than flickering per phase (intro/feedback/retry all show the
  /// same thing).
  ///
  /// Observe's two poles deliberately share one string: naming which
  /// character owns which pole here would hand the parent — and so the
  /// child — the answer before the round asks one.
  String? get captionText {
    final prompt = currentPrompt;
    if (prompt == null) return null;
    final isHigh = prompt.targetDirection == PitchDirection.higher;
    return switch (agencyStage) {
      AgencyStage.observe => 'Let them explore freely.',
      AgencyStage.participate => isHigh
          ? 'Let them tap both instruments and find the higher one. Clef '
                'sparkles when they find it.'
          : 'Let them tap both instruments and find the lower one. Piper '
                'sparkles when they find it.',
      AgencyStage.trigger => isHigh
          ? 'Help them drag the higher-sounding instrument to Clef.'
          : 'Help them drag the lower-sounding instrument to Piper.',
    };
  }

  /// Secondary guidance, shown only once [showMoveOnControl] would also
  /// be considered (~6 seconds into an unanswered round — see
  /// [_nudgeTimer]) and only for Participate; Observe/Trigger's secondary
  /// nudge is [showMoveOnControl] itself, not text — neither has
  /// Participate's five-tap-streak auto-advance, so a manual assist
  /// control is the thing worth surfacing there instead (Trello card
  /// 5tdMOMh3). Never shown immediately: arriving at the moment of
  /// confusion is help, visible from the start it's noise nobody reads,
  /// and nothing here should suggest the child is struggling while
  /// they're doing fine.
  String? get secondaryCaptionText {
    if (!_nudgeVisible ||
        agencyStage != AgencyStage.participate ||
        _status != GameStatus.awaitingInput) {
      return null;
    }
    final prompt = currentPrompt;
    if (prompt == null) return null;
    return prompt.targetDirection == PitchDirection.higher
        ? 'Encourage your child to keep tapping the one that sounds higher.'
        : 'Encourage your child to keep tapping the one that sounds lower.';
  }

  /// Whether the adult move-on control should be visible right now
  /// (Trello card xpAkja5b) — Observe/Trigger's ~6-second secondary nudge
  /// (see [_nudgeTimer]); Participate has no manual assist control (see
  /// [secondaryCaptionText]'s doc comment for why).
  bool get showMoveOnControl {
    if (!_nudgeVisible || agencyStage == AgencyStage.participate) {
      return false;
    }
    return _status == GameStatus.awaitingInput;
  }

  /// Whether the child can drag an instrument onto the centered character
  /// right now. Deliberately not gated on [_status] beyond "not finished" —
  /// a child's drop must always override whatever's currently happening on
  /// screen (a retry's replay, its voice line) rather than being locked
  /// out behind an animation or a sound (Trello card jmuMDPcT). The one
  /// exception is once this round has already been answered correctly
  /// ([DragFeedback.correct]): that guard lives in [dropInstrument] itself,
  /// to avoid double-recording a result while the advance-to-next-round
  /// delay is still pending.
  bool get canDrop =>
      agencyStage == AgencyStage.trigger && _status != GameStatus.completed;

  /// Which character stays centered this round — Piper owns the low
  /// pole, Clef owns the high pole (Trello card 101), so this always
  /// agrees with [captionText]'s first-person line ("give me the ...")
  /// in Trigger. Meaningful at every stage, not just Trigger: Observe and
  /// Participate also center this same character as a second visual cue
  /// for what to listen for (Trello card 1SpHq2la), even though only
  /// Trigger makes her an interactive drop target — see [canDrop] and
  /// `HighLowScreen._buildDropZone` for the stage gate on that part.
  /// Named for the character, not for dragging, since 2026-09's reversal
  /// made the character the stationary target and the instruments the
  /// dragged objects (see the class doc) — this getter's old name,
  /// `draggedIsPiper`, read backwards once that flipped.
  bool get targetCharacterIsPiper =>
      currentPrompt?.targetDirection == PitchDirection.lower;

  /// Start a new game.
  void startGame() {
    final targets = _sequencer.sequence(count: totalPrompts, order: roundOrder);
    _prompts = _generator.generatePrompts(
      count: totalPrompts,
      tier: conceptTier,
      targetDirections: targets,
    );
    _currentPromptIndex = 0;
    _results.clear();
    _instrumentation.clear();
    _startRound();
  }

  /// Wait for [duration], cancellably — see [_pendingTimer]. If cancelled
  /// via [_cancelPendingTimer] before it elapses, the returned future
  /// simply never completes (its awaiter stays harmlessly suspended); the
  /// real [Timer] backing it is gone, so nothing is left pending.
  Future<void> _delay(Duration duration) {
    final completer = Completer<void>();
    _pendingTimer?.cancel();
    _pendingTimer = Timer(duration, () {
      _pendingTimer = null;
      completer.complete();
    });
    return completer.future;
  }

  void _cancelPendingTimer() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
  }

  /// Run [action] after [duration], cancellably — see [_pendingTimer].
  void _schedule(Duration duration, void Function() action) {
    _pendingTimer?.cancel();
    _pendingTimer = Timer(duration, () {
      _pendingTimer = null;
      action();
    });
  }

  void _cancelNudgeTimer() {
    _nudgeTimer?.cancel();
    _nudgeTimer = null;
  }

  void _cancelSparkleTimer() {
    _characterSparkleTimer?.cancel();
    _characterSparkleTimer = null;
  }

  /// Play [line], tracking [_speakingIsPiper] for however long it
  /// actually takes to finish (Trello card PIm7xE6n, "the talker moves")
  /// — ties the speaking-bob's duration to real playback completion via
  /// [AudioController.playVoiceLineAndAwait], not a guessed timer (this
  /// codebase has been bitten twice by a bare `play()` resolving on start
  /// rather than completion). Guarded by [token] so a superseded round's
  /// late completion can't clear a newer round's speaking state. Callers
  /// that don't need to block on the line finishing wrap this in
  /// `unawaited` themselves — the tracking still happens either way.
  Future<void> _speak(int token, VoiceLine line) async {
    _speakingIsPiper = line.isPiper;
    notifyListeners();
    await _audio.playVoiceLineAndAwait(line);
    if (token != _roundToken) return;
    _speakingIsPiper = null;
    notifyListeners();
  }

  /// Transiently sparkles [isPiper]'s character on a correct A0/A1 tap
  /// (Trello card RqdPFKLf) — suppressed if that same character is
  /// currently speaking (the interlock in [speakingIsPiper]'s doc
  /// comment). The tap still counts toward the streak either way; only
  /// the visual cue is skipped for that instant.
  void _sparkleCorrectTapCharacter(bool isPiper) {
    if (_speakingIsPiper == isPiper) return;
    _characterSparkleIsPiper = isPiper;
    notifyListeners();
    _characterSparkleTimer?.cancel();
    _characterSparkleTimer = Timer(const Duration(milliseconds: 900), () {
      _characterSparkleTimer = null;
      _characterSparkleIsPiper = null;
      notifyListeners();
    });
  }

  void _startRound() {
    final token = ++_roundToken;
    _cancelPendingTimer();
    _cancelNudgeTimer();
    _cancelSparkleTimer();
    _playingIndex = null;
    _dragFeedback = DragFeedback.none;
    _lastDropSide = null;
    _hintVisible = false;
    _waitedForPlaythrough = true;
    _firstResponseSide = null;
    _firstResponseCorrect = null;
    _listenAgainCount = 0;
    _correctTapStreak = 0;
    _nudgeVisible = false;
    _speakingIsPiper = null;
    _characterSparkleIsPiper = null;
    _instrumentSparkleSide = null;

    final prompt = currentPrompt;
    _activeCaption = switch (agencyStage) {
      AgencyStage.observe => null, // narrated live as each note plays
      AgencyStage.participate =>
        prompt?.targetDirection == PitchDirection.higher
            ? VoiceLine.listenForHigh
            : VoiceLine.listenForLow,
      AgencyStage.trigger =>
        prompt?.targetDirection == PitchDirection.higher
            ? VoiceLine.giveMeHigh
            : VoiceLine.giveMeLow,
    };
    _status = GameStatus.playing;
    notifyListeners();
    if (_activeCaption != null) {
      unawaited(_playCaptionThenIntro(token, _activeCaption!));
    } else {
      unawaited(_runIntro(token));
    }
  }

  /// Speak [caption] and only start the note pair once it's actually
  /// finished — see [AudioController.playVoiceLineAndAwait]. Without this,
  /// the notes started over the top of the still-speaking prompt (Trello
  /// card KOuemvVs); [_runIntro]'s own per-note narration (Observe) doesn't
  /// go through here, since [_startRound] never sets a top-level
  /// [_activeCaption] for Observe.
  Future<void> _playCaptionThenIntro(int token, VoiceLine caption) async {
    await _speak(token, caption);
    if (token != _roundToken) return;
    await _runIntro(token);
  }

  /// Play the pair through, cancellable via [_roundToken]. In Observe,
  /// this always runs to completion (taps never cut it short); in
  /// Participate/Trigger, [tapInstrument] cancels it early.
  Future<void> _runIntro(int token) async {
    final prompt = currentPrompt;
    if (prompt == null) return;

    _introPlaying = true;
    _playingIndex = 0;
    if (agencyStage == AgencyStage.observe) {
      _activeCaption = prompt.leftIsHigher
          ? VoiceLine.clefSaysHigh
          : VoiceLine.piperSaysLow;
      unawaited(_speak(token, _activeCaption!));
    }
    notifyListeners();

    await _audio.playAssetForScale(
      leftInstrument.assetPathForMidi(prompt.firstMidi),
    );
    if (token != _roundToken) return;

    // Long enough for the first sample to decay before the splice into the
    // second note — see the original High/Low implementation notes
    // (Trello card 57/58); unchanged here.
    await _delay(_noteRingDuration);
    if (token != _roundToken) return;

    _playingIndex = 1;
    if (agencyStage == AgencyStage.observe) {
      // The "Second" variants continue the sentence the first note's
      // narration started (e.g. "Ooh! That one sounds high! ...and that
      // one sounds low!") — see VoiceLine.piperSaysLowSecond/
      // clefSaysHighSecond's doc comments. Whichever character didn't
      // narrate the first note always narrates the second, so this is
      // just the opposite branch of the first caption's condition above.
      _activeCaption = prompt.leftIsHigher
          ? VoiceLine.piperSaysLowSecond
          : VoiceLine.clefSaysHighSecond;
      unawaited(_speak(token, _activeCaption!));
    }
    notifyListeners();

    await _audio.playAssetForScale(
      rightInstrument.assetPathForMidi(prompt.secondMidi),
    );
    if (token != _roundToken) return;

    // Mirrors the first note's wait above (Trello card 97): `playNoteForScale`
    // only awaits the sample *starting*, not finishing, so without this the
    // second note's wiggle/glow was cleared by `_finishIntro` on the very
    // next microtask — before a single frame had painted it. The right-hand
    // instrument's "I'm sounding" indicator never had a chance to render.
    await _delay(_noteRingDuration);
    if (token != _roundToken) return;

    _finishIntro(token);
  }

  void _finishIntro(int token) {
    if (token != _roundToken) return;
    _introPlaying = false;
    _playingIndex = null;
    _hintVisible = agencyStage == AgencyStage.participate;
    _status = GameStatus.awaitingInput;

    // Fresh 6-second window every time a round becomes actionable — the
    // very first time, and again after every retry's re-listen (Trello
    // cards 5tdMOMh3/xpAkja5b: secondary guidance/the move-on control
    // never appears immediately, only once the child's had a real chance
    // to try).
    _nudgeVisible = false;
    _cancelNudgeTimer();
    _nudgeTimer = Timer(const Duration(seconds: 6), () {
      if (token != _roundToken) return;
      _nudgeVisible = true;
      notifyListeners();
    });

    notifyListeners();
  }

  /// A tap on an instrument — pure exploration, at every stage: it plays
  /// that instrument's note and never commits an answer. In
  /// Participate/Trigger, a tap during the intro also cuts it short (a
  /// tap must never be swallowed); in Observe the intro keeps running
  /// regardless.
  void tapInstrument(int side) {
    if (_status == GameStatus.notStarted || _status == GameStatus.completed) {
      return;
    }
    final prompt = currentPrompt;
    if (prompt == null) return;

    // Captured before `_finishIntro` (below) can flip it — the tap that
    // cuts the intro short is exactly "the tap before Clef sparkles" the
    // instrumentation cares about, so it must be judged against the hint
    // state as it stood *before* this tap, not after.
    final hintWasVisible = _hintVisible;

    if (_introPlaying && agencyStage != AgencyStage.observe) {
      _waitedForPlaythrough = false;
      _audio.stopCurrentNote();
      _cancelPendingTimer(); // the note-gap wait, if that's where this landed
      // Bump the token first so the intro's in-flight `_runIntro` (still
      // suspended on an `await` somewhere) sees a stale token on its next
      // continuation and bails instead of resuming and clobbering the
      // state `_finishIntro` is about to set.
      final token = ++_roundToken;
      _finishIntro(token);
    }

    // Record the first response of the round, if made before any hint
    // existed — Observe has no target to score against.
    if (_firstResponseSide == null &&
        agencyStage != AgencyStage.observe &&
        !hintWasVisible) {
      _firstResponseSide = side;
      _firstResponseCorrect = side == prompt.targetSide;
    }

    // Observe's per-note narration comes before the tap-streak check
    // below so its speaker is already reflected in [_speakingIsPiper] —
    // the interlock in [speakingIsPiper]'s doc comment means a tap that
    // both matches the target *and* triggers this same character's own
    // narration must not also sparkle her at the same instant.
    if (agencyStage == AgencyStage.observe) {
      _activeCaption = side == prompt.higherSide
          ? VoiceLine.clefSaysHigh
          : VoiceLine.piperSaysLow;
      unawaited(_speak(_roundToken, _activeCaption!));
    }

    // At A0/A1, a repeated tap on the same (correct) instrument is an
    // answer, not noise — a child who knows it has no other way to show
    // it (Trello card RqdPFKLf). Five correct in a row resolves the
    // round; a wrong tap resets the streak silently, with nothing
    // negative shown at all — no nudge, no correction, just business as
    // usual below (the tap still plays its own note either way).
    if (agencyStage != AgencyStage.trigger) {
      if (side == prompt.targetSide) {
        _correctTapStreak++;
        _sparkleCorrectTapCharacter(targetCharacterIsPiper);
        if (_correctTapStreak >= 5) {
          _celebrateCorrect(side, announceNote: false);
        }
      } else {
        _correctTapStreak = 0;
      }
    }

    _playingIndex = side;
    notifyListeners();

    final instrument = side == 0 ? leftInstrument : rightInstrument;
    final midi = side == 0 ? prompt.firstMidi : prompt.secondMidi;
    unawaited(
      _audio.playAssetForScale(instrument.assetPathForMidi(midi)).then((_) {
        // Only clear the wiggle if nothing newer (another tap, the
        // next round) has already taken over `_playingIndex`.
        if (_playingIndex == side) {
          _playingIndex = null;
          notifyListeners();
        }
      }),
    );
  }

  /// Trigger-only: the child drags the instrument on [side] onto the
  /// centered character (see [targetCharacterIsPiper]). Never a failure
  /// state — a wrong drop just retries with a fresh listen. [side]
  /// identifies which instrument was dragged, not where it landed — since
  /// 2026-09's reversal the character is the single fixed target, so
  /// there's nowhere else a drop could land (see HighLowScreen's single,
  /// screen-spanning drop zone).
  ///
  /// A drop is a child action, so it always overrides whatever's currently
  /// happening — a pending retry replay, its "try again" voice line, or the
  /// note pair mid-playback — rather than being swallowed while an
  /// animation or sound finishes (Trello card jmuMDPcT). See [canDrop] for
  /// the one exception (a round already answered correctly).
  void dropInstrument(int side) {
    if (!canDrop) return;
    if (_dragFeedback == DragFeedback.correct) return;
    final prompt = currentPrompt;
    if (prompt == null) return;

    _audio.stopCurrentNote();
    _audio.stopCurrentClip();
    _cancelPendingTimer();
    _introPlaying = false;
    _playingIndex = null;

    _firstResponseSide ??= side;
    _firstResponseCorrect ??= side == prompt.targetSide;

    if (side == prompt.targetSide) {
      _celebrateCorrect(side, announceNote: false);
    } else {
      final token = ++_roundToken;
      _lastDropSide = side;
      _cancelNudgeTimer();
      _nudgeVisible = false;
      _dragFeedback = DragFeedback.retry;
      _activeCaption = targetCharacterIsPiper
          ? VoiceLine.tryAgainPiper
          : VoiceLine.tryAgainClef;
      _status = GameStatus.showingFeedback;
      notifyListeners();

      unawaited(_playRetryThenIntro(token, prompt, _activeCaption!));
    }
  }

  /// Resolve this round as correct and advance after a short celebration
  /// — shared by an organic Trigger drop, A0/A1's five-correct-taps
  /// streak (Trello card RqdPFKLf), and the adult move-on control (Trello
  /// card xpAkja5b). [announceNote] additionally plays the correct
  /// instrument's own note and flashes its sparkle overlay — the "look,
  /// this one" demonstration move-on's resolution promises; an organic
  /// drop or a tap streak doesn't need it, since the child's own action
  /// already drew attention to the right instrument. The instrument
  /// visibly traveling to the character (rather than just pulsing in
  /// place) is a Trigger-only distinction the screen makes on its own,
  /// from [agencyStage] and [dragFeedback]/[lastDropSide] — not something
  /// this method needs to know about.
  void _celebrateCorrect(int side, {required bool announceNote}) {
    final prompt = currentPrompt;
    if (prompt == null) return;
    _cancelNudgeTimer();
    _nudgeVisible = false;
    final token = ++_roundToken;
    _lastDropSide = side;
    _dragFeedback = DragFeedback.correct;
    _status = GameStatus.showingFeedback;
    _audio.playSfx(SfxType.correct);
    _recordRoundResult();
    if (announceNote) {
      _instrumentSparkleSide = side;
      final instrument = side == 0 ? leftInstrument : rightInstrument;
      final midi = side == 0 ? prompt.firstMidi : prompt.secondMidi;
      unawaited(_audio.playAssetForScale(instrument.assetPathForMidi(midi)));
    }
    notifyListeners();

    _schedule(const Duration(milliseconds: 1200), () {
      if (token != _roundToken) return;
      _instrumentSparkleSide = null;
      if (_currentPromptIndex < totalPrompts - 1) {
        _currentPromptIndex++;
        _startRound();
      } else {
        _completeGame();
      }
    });
  }

  /// How long a wrong drop's feedback (the shake, the retry line) stays on
  /// screen at minimum, even if the retry line itself is shorter or
  /// missing — see [_playRetryThenIntro].
  static const Duration _retryFeedbackMinimum = Duration(milliseconds: 1400);

  /// Speak [retryLine] to full completion (or [_retryFeedbackMinimum],
  /// whichever is longer) before moving on to the round's own cue and
  /// replaying the notes. This used to fire the retry line and move on
  /// after a flat, guessed 1400ms regardless of the line's real length —
  /// exactly the trap [_playCaptionThenIntro] already avoids for the
  /// round-start cue — so a longer retry recording got cut off by
  /// `giveMeHigh`/`giveMeLow` (then named `putMeOnHigh`/`putMeOnLow`)
  /// starting over the top of it (Trello —
  /// "Clef's audio file keeps getting cut off"). Waiting for the longer of
  /// the two keeps the existing minimum dwell time for the shake/feedback
  /// when the line is short (or the asset's missing, in which case
  /// [AudioController.playVoiceLineAndAwait] resolves immediately) while
  /// letting a longer line actually finish.
  Future<void> _playRetryThenIntro(
    int token,
    HighLowPrompt prompt,
    VoiceLine retryLine,
  ) async {
    await Future.wait([_speak(token, retryLine), _delay(_retryFeedbackMinimum)]);
    if (token != _roundToken) return;
    _dragFeedback = DragFeedback.none;
    _activeCaption = prompt.targetDirection == PitchDirection.higher
        ? VoiceLine.giveMeHigh
        : VoiceLine.giveMeLow;
    _status = GameStatus.playing;
    notifyListeners();
    await _playCaptionThenIntro(token, _activeCaption!);
  }

  void _recordRoundResult() {
    final prompt = currentPrompt;
    if (prompt == null) return;
    _results.add(PromptResult(prompt: prompt, isCorrect: true));
    _instrumentation.add(
      RoundInstrumentation(
        promptNumber: prompt.promptNumber,
        waitedForPlaythrough: _waitedForPlaythrough,
        firstResponseCorrect: _firstResponseCorrect,
        listenAgainCount: _listenAgainCount,
        correctTapCount: _correctTapStreak,
      ),
    );
  }

  /// Replay the current round: the note pair, then the round's own cue
  /// (Participate's "listen for the ..." / Trigger's "put me on the ...")
  /// — in that order (Trello card DC0QKLr3, which was replaying only the
  /// notes and never the character's prompt). Observe has no separate
  /// top-level cue to replay — the notes' own live per-note narration
  /// (see [_runIntro]) already covers it. Always available except while a
  /// Trigger drop's feedback is showing or the game is over.
  Future<void> replay() async {
    if (_status == GameStatus.completed ||
        _status == GameStatus.showingFeedback) {
      return;
    }
    _listenAgainCount++;
    _audio.playSfx(SfxType.tap);
    final token = ++_roundToken;
    _status = GameStatus.playing;
    notifyListeners();
    await _runIntro(token);
    if (token != _roundToken) return;
    final cue = _activeCaption;
    if (agencyStage != AgencyStage.observe && cue != null) {
      await _speak(token, cue);
    }
  }

  /// The child's escape control (Trello card xpAkja5b, "Split Skip into
  /// two controls: escape and move-on") — immediate, no resolution, no
  /// correct answer shown. Pressed by a bored or frustrated child;
  /// evidence of difficulty, not mastery, so it must not share a code
  /// path (or a logged event) with [moveOn]. Always available regardless
  /// of phase — an adult needs to be able to advance a tiring child past
  /// a round that will never satisfy any gating condition on its own
  /// (Observe/Participate never auto-advance; Trigger might be
  /// mid-retry). This is the control the header's Skip pill calls; it
  /// was simply named `moveOn` before this card split the concept in two.
  void escape() {
    if (_status == GameStatus.completed) return;
    _audio.stopCurrentNote();
    _cancelPendingTimer();
    _cancelNudgeTimer();
    _cancelSparkleTimer();

    // Skipped rounds aren't scored — nothing to record, this isn't an
    // answer of any kind.
    if (_currentPromptIndex < totalPrompts - 1) {
      _currentPromptIndex++;
      _startRound();
    } else {
      _completeGame();
    }
  }

  /// The adult move-on control (Trello card xpAkja5b) — evidence of
  /// mastery, not difficulty, so unlike [escape] this always resolves the
  /// round first via [_celebrateCorrect]: the correct instrument plays
  /// and sparkles, and (at Trigger) visibly travels to the character,
  /// before the round turns. Only ever reachable once [showMoveOnControl]
  /// has made the button visible (~6 seconds into an unanswered round),
  /// but guarded here too rather than trusting the caller.
  void moveOn() {
    if (_status != GameStatus.awaitingInput) return;
    final prompt = currentPrompt;
    if (prompt == null) return;
    _audio.stopCurrentNote();
    _cancelPendingTimer();
    _celebrateCorrect(prompt.targetSide, announceNote: true);
  }

  void _completeGame() {
    _roundToken++;
    _cancelPendingTimer();
    _cancelNudgeTimer();
    _cancelSparkleTimer();
    _status = GameStatus.completed;
    _audio.playSfx(SfxType.reward);
    notifyListeners();
  }

  /// Reset the game to play again.
  void reset() {
    _roundToken++;
    _cancelPendingTimer();
    _cancelNudgeTimer();
    _cancelSparkleTimer();
    _status = GameStatus.notStarted;
    _prompts = [];
    _currentPromptIndex = 0;
    _results.clear();
    _instrumentation.clear();
    _activeCaption = null;
    _correctTapStreak = 0;
    _nudgeVisible = false;
    _speakingIsPiper = null;
    _characterSparkleIsPiper = null;
    _instrumentSparkleSide = null;
    notifyListeners();
  }

  PromptResult? get lastResult => _results.isNotEmpty ? _results.last : null;

  @override
  void dispose() {
    _roundToken++;
    _cancelPendingTimer();
    _cancelNudgeTimer();
    _cancelSparkleTimer();
    super.dispose();
  }
}

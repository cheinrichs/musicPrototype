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
/// Two controls, not tied to any one stage (Trello card xpAkja5b, "Two
/// controls: the adult's persistent skip, and the child's earned
/// arrow"): [escape] is the adult's, visible every stage, every phase,
/// no criterion — "we're moving on regardless," the escape valve for a
/// child who can't or won't reach whatever the stage actually asks for.
/// [tapArrow]/[showArrow] is the child's, Observe (A0) only, and never
/// timed — it appears once *earned* (see [showArrow]'s doc comment) and
/// stays until tapped. An arrow on a timer would teach a child that
/// waiting is how you progress, which works against what every stage is
/// trying to elicit; it has to be earned each time.
///
/// A tap on an instrument always plays its note — that's exploration, at
/// every stage. What counts as *done* differs by stage (Trello card
/// RqdPFKLf, "Completion criteria for A0 and A1, and the correct-tap
/// sparkle"), because only Observe has no question to answer:
///
/// - Observe (A0): the pair auto-plays; Piper/Clef narrate low/high as
///   each note sounds (see [speakingIsPiper] for the "talker moves"
///   indicator this drives); free tapping is always available and never
///   interrupts the auto-play. No question asked in the caption, and no
///   correct/wrong distinction on a tap either — completing and
///   exploring are the *same action* here, so the criterion is coverage:
///   once both instruments have been tapped at least once, the earned
///   arrow appears (see [showArrow]).
/// - Participate (A1): a constant prompt ("Listen for the high one"), the
///   pair auto-plays but a tap cuts it short, then free tapping
///   continues. A correct tap sparkles the owning character, escalating
///   with each one (Cooper: "a flat sparkle is a reward; an escalating
///   one is a promise") — five *cumulative* correct taps resolve the
///   round in a confetti burst and auto-advance; a wrong tap adds
///   nothing to that count but never subtracts either (see
///   [tapInstrument]'s doc comment for why the gate stays generous on
///   purpose).
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
///
/// At every stage, whichever of Piper/Clef owns the round's target pole
/// (Piper is low, Clef is high; see [targetCharacterIsPiper] and Trello
/// card 101) stands centered as a second visual cue for what to listen
/// for, alongside the caption (Trello card 1SpHq2la) — a fixed, parent-
/// facing string (see [captionText]'s doc comment), not a transcript of
/// whichever line is currently playing. Only Trigger makes her an
/// interactive drop target — see [canDrop].
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

  /// Cumulative correct taps this round, Participate only (Trello card
  /// RqdPFKLf) — a wrong tap does *not* reset this (see
  /// [tapInstrument]'s doc comment for why); five resolves the round via
  /// [_celebrateCorrect]. Never incremented at Observe (see
  /// [_tappedSidesObserve] instead) or Trigger, where tapping stays pure
  /// exploration and only a drag/drop commits.
  int _correctTapCumulative = 0;

  /// Wrong taps this round, Participate only — logged (see
  /// [RoundInstrumentation.wrongTapCount]) but never subtracted from
  /// [_correctTapCumulative]; assessment signal, not a gate.
  int _wrongTapCount = 0;

  /// Bumped every time the fifth cumulative correct tap fires the
  /// confetti burst (Cooper: "building to a confetti burst") — a
  /// one-shot event a [ChangeNotifier] has no other clean way to expose.
  /// The screen remembers the last value it acted on and fires its
  /// [ConfettiController] whenever this changes, rather than this class
  /// owning any Flutter-side animation controller itself.
  int _confettiTrigger = 0;

  /// Which instrument sides have been tapped at least once this round,
  /// Observe only — its completion criterion (Trello card RqdPFKLf):
  /// once both are in here, [_showArrow] flips true. No correct/wrong
  /// distinction, unlike Participate's streak — Observe has no question
  /// to answer, so any tap on a side satisfies it.
  final Set<int> _tappedSidesObserve = {};

  /// Whether Observe's earned arrow is visible this round — see
  /// [showArrow]'s doc comment.
  bool _showArrow = false;

  /// Whether the arrow's first-time voice cue has already played this
  /// *session* (not reset per round, per "once per stone" — see
  /// [VoiceLine.tapTheArrowWhenReady]'s doc comment).
  bool _arrowCueSpoken = false;

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

  /// Whether the round's secondary guidance (Trello card 5tdMOMh3) should
  /// be visible right now — set true ~6 seconds into an unanswered
  /// Participate round by [_nudgeTimer] (only ever scheduled for
  /// Participate — see [_finishIntro]; A0/A2's own six-second nudge, the
  /// adult move-on control, is gone along with the timed arrow it was
  /// replaced by), reset on every fresh entry to
  /// [GameStatus.awaitingInput] (a new round, a replay, a retry's
  /// re-listen) so a child who's mid-retry always gets a fresh 6-second
  /// window before anything nudges again.
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
  /// right now (Trello card RqdPFKLf) — set for ~900ms on a correct
  /// Participate tap (see [tapInstrument]), then cleared. See
  /// [speakingIsPiper]'s doc comment for why this is never true for
  /// whichever character is currently speaking.
  bool? get characterSparkleIsPiper => _characterSparkleIsPiper;

  /// How many cumulative correct taps Participate has banked this round
  /// (0-5) — the screen scales the sparkle's visual intensity to this so
  /// each correct tap reads as *more* than the last, building to the
  /// confetti burst [confettiTrigger] signals at five (Cooper: "a flat
  /// sparkle is a reward; an escalating one is a promise"). Always 0
  /// outside Participate.
  int get correctTapProgress => _correctTapCumulative;

  /// Bumped once every time the fifth cumulative correct tap fires the
  /// confetti burst — see [_confettiTrigger]'s doc comment for why this
  /// is a bump-counter rather than a bool. The screen compares this
  /// against the last value it saw and calls its `ConfettiController` on
  /// a change.
  int get confettiTrigger => _confettiTrigger;

  /// Whether Observe's earned arrow is visible right now (Trello card
  /// xpAkja5b, "the child's earned arrow") — true once both instrument
  /// sides have been tapped at least once this round (see
  /// [_tappedSidesObserve]), and stays true until the round turns.
  /// Deliberately **not** time-gated at all, unlike the timed move-on
  /// control this replaced: a child who hasn't earned it yet must never
  /// see it appear on its own, or tapping stops being the thing that
  /// earns it. Modelled on Duolingo ABC — you can't skip the experience,
  /// but once you've had it, you decide when you're done. Always false
  /// outside Observe.
  bool get showArrow => agencyStage == AgencyStage.observe && _showArrow;

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
  ///
  /// Kept short enough to survive two lines at the narrowest supported
  /// viewport without ellipsizing — see
  /// `test/games/high_low/widgets/high_low_header_test.dart`. The header
  /// is already tight between the close button and the Skip pill, so a
  /// caption that's too long to fit loses exactly the pole word it
  /// exists to carry (Cooper, driving the simulator: "'Find the …' tells
  /// them nothing"). Fix a future truncation by shortening the string
  /// further, not by growing the caption block.
  String? get captionText {
    final prompt = currentPrompt;
    if (prompt == null) return null;
    final isHigh = prompt.targetDirection == PitchDirection.higher;
    return switch (agencyStage) {
      AgencyStage.observe => 'Let them explore freely.',
      AgencyStage.participate => isHigh
          ? 'Let them tap both and find the higher one.'
          : 'Let them tap both and find the lower one.',
      AgencyStage.trigger => isHigh
          ? 'Help them drag the higher instrument to Clef.'
          : 'Help them drag the lower instrument to Piper.',
    };
  }

  /// Secondary guidance, shown ~6 seconds into an unanswered Participate
  /// round (see [_nudgeTimer], only ever scheduled for this stage) —
  /// Observe and Trigger's own six-second nudge is gone along with the
  /// timed move-on control it used to reveal (Trello card xpAkja5b):
  /// Observe's completion is earned, never timed (see [showArrow]), and
  /// Trigger already auto-advances on a correct drop, so neither needed
  /// a assist control in the first place. Participate's line survives
  /// because it's about what to do, not about a button appearing —
  /// guidance, not a control. Never shown immediately: arriving at the
  /// moment of confusion is help, visible from the start it's noise
  /// nobody reads, and nothing here should suggest the child is
  /// struggling while they're doing fine.
  String? get secondaryCaptionText {
    if (!_nudgeVisible ||
        agencyStage != AgencyStage.participate ||
        _status != GameStatus.awaitingInput) {
      return null;
    }
    final prompt = currentPrompt;
    if (prompt == null) return null;
    return prompt.targetDirection == PitchDirection.higher
        ? 'Encourage them to keep tapping the higher one.'
        : 'Encourage them to keep tapping the lower one.';
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
    _correctTapCumulative = 0;
    _wrongTapCount = 0;
    _tappedSidesObserve.clear();
    _showArrow = false;
    _nudgeVisible = false;
    _speakingIsPiper = null;
    _characterSparkleIsPiper = null;

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
    // card 5tdMOMh3: secondary guidance never appears immediately, only
    // once the child's had a real chance to try). Only Participate has
    // anything to reveal after the wait any more — A0/A2's own six-second
    // nudge died with the timed move-on control (Trello card xpAkja5b) —
    // so nothing schedules the timer at those stages at all now.
    _nudgeVisible = false;
    _cancelNudgeTimer();
    if (agencyStage == AgencyStage.participate) {
      _nudgeTimer = Timer(const Duration(seconds: 6), () {
        if (token != _roundToken) return;
        _nudgeVisible = true;
        notifyListeners();
      });
    }

    notifyListeners();
  }

  /// A tap on an instrument always plays that instrument's note — pure
  /// exploration at every stage, never a right/wrong verdict the way a
  /// Trigger drop's feedback is. But at Observe/Participate a tap also
  /// counts toward that stage's own completion criterion (Trello card
  /// RqdPFKLf) — see the arrow-coverage and cumulative-sparkle branches
  /// below. In Participate/Trigger, a tap during the intro also cuts it
  /// short (a tap must never be swallowed); in Observe the intro keeps
  /// running regardless.
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

    // Observe's per-note narration comes before the arrow-coverage check
    // below so its speaker is already reflected in [_speakingIsPiper] —
    // the interlock in [speakingIsPiper]'s doc comment means a character
    // must never speak and sparkle at the same instant, and Participate's
    // sparkle (below) needs the same ordering.
    if (agencyStage == AgencyStage.observe) {
      _activeCaption = side == prompt.higherSide
          ? VoiceLine.clefSaysHigh
          : VoiceLine.piperSaysLow;
      unawaited(_speak(_roundToken, _activeCaption!));

      // Observe's completion criterion is coverage, not correctness — it
      // has no question to answer, so any tap on a side satisfies it
      // (Trello card RqdPFKLf). Once both sides have been tapped at
      // least once, the earned arrow appears and stays until tapped;
      // never re-hidden by a later tap.
      _tappedSidesObserve.add(side);
      if (!_showArrow && _tappedSidesObserve.length >= 2) {
        _showArrow = true;
        if (!_arrowCueSpoken) {
          _arrowCueSpoken = true;
          unawaited(_audio.playVoiceLine(VoiceLine.tapTheArrowWhenReady));
        }
      }
    } else if (agencyStage == AgencyStage.participate) {
      // A repeated correct tap is an answer, not noise — a child who
      // knows it has no other way to show it (Trello card RqdPFKLf).
      // Cumulative, not consecutive: a wrong tap adds nothing but must
      // never subtract either, or the sparkle would go backwards — a
      // failure signal at a stage that must have none. This deliberately
      // makes the gate generous; the criterion is for progression, the
      // logged wrong-tap count is for assessment. Five cumulative
      // correct taps resolve the round in a confetti burst.
      if (side == prompt.targetSide) {
        _correctTapCumulative++;
        _sparkleCorrectTapCharacter(targetCharacterIsPiper);
        if (_correctTapCumulative >= 5) {
          _confettiTrigger++;
          _celebrateCorrect(side);
        }
      } else {
        _wrongTapCount++;
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
      _celebrateCorrect(side);
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
  /// — shared by an organic Trigger drop and Participate's
  /// five-cumulative-correct-taps gate (Trello card RqdPFKLf). The
  /// instrument visibly traveling to the character (rather than just
  /// pulsing in place) is a Trigger-only distinction the screen makes on
  /// its own, from [agencyStage] and [dragFeedback]/[lastDropSide] — not
  /// something this method needs to know about.
  void _celebrateCorrect(int side) {
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
    notifyListeners();

    _schedule(const Duration(milliseconds: 1200), () {
      if (token != _roundToken) return;
      _advanceOrComplete();
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
        correctTapCount: _correctTapCumulative,
        wrongTapCount: _wrongTapCount,
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

  /// The adult's persistent skip (Trello card xpAkja5b, "Two controls:
  /// the adult's persistent skip, and the child's earned arrow") —
  /// immediate, no resolution, no correct answer shown, visible every
  /// stage and every phase, never gated behind a criterion of any kind.
  /// "We're moving on regardless" — the escape valve for a child who
  /// can't or won't reach whatever the stage actually asks for, which is
  /// exactly what lets the child's own control ([tapArrow]) stay
  /// strictly earned. This is the control the header's Skip pill calls.
  void escape() {
    if (_status == GameStatus.completed) return;
    _audio.stopCurrentNote();
    _cancelPendingTimer();
    _cancelNudgeTimer();
    _cancelSparkleTimer();

    // Skipped rounds aren't scored — nothing to record, this isn't an
    // answer of any kind.
    _advanceOrComplete();
  }

  /// The child's earned arrow (Trello card xpAkja5b) — Observe only,
  /// reachable once [showArrow] is true. Unlike [_celebrateCorrect],
  /// Observe has no target to demonstrate (there's no question a
  /// correct/wrong verdict could attach to), so this just records the
  /// round as complete and advances — no sparkle, no note replay, no
  /// travel animation. Modelled on Duolingo ABC: the child decides when
  /// they're done, once they've done the thing that earns the choice.
  void tapArrow() {
    if (!showArrow) return;
    final prompt = currentPrompt;
    if (prompt == null) return;
    _audio.playSfx(SfxType.correct);
    _recordRoundResult();
    _advanceOrComplete();
  }

  /// Advance to the next round, or finish the session on the last one —
  /// shared by [escape] (no scoring), [tapArrow] (already recorded as
  /// complete by the caller), and [_celebrateCorrect]'s own scheduled
  /// callback (also already recorded). Never records anything itself;
  /// callers that need a result logged do so before calling this.
  void _advanceOrComplete() {
    if (_currentPromptIndex < totalPrompts - 1) {
      _currentPromptIndex++;
      _startRound();
    } else {
      _completeGame();
    }
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
    _correctTapCumulative = 0;
    _wrongTapCount = 0;
    _tappedSidesObserve.clear();
    _showArrow = false;
    _arrowCueSpoken = false;
    _nudgeVisible = false;
    _speakingIsPiper = null;
    _characterSparkleIsPiper = null;
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

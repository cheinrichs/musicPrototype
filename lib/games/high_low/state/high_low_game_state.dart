import 'dart:async';
import 'dart:math';
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

/// Visual feedback for a Trigger-stage (A2) Clef drop.
enum DragFeedback { none, correct, retry }

/// State machine for the High/Low game, parametrized by [AgencyStage]
/// (Trello card 91), [ConceptTier], and [RoundOrder] (Trello card 95).
///
/// Every stage shares one rule: tapping an instrument is *exploration* —
/// it plays that instrument's note and never commits an answer, at any
/// stage. Only Trigger's Clef-drag commits. This is the whole point of the
/// card-91 rework: a toddler's instinct to tap a sound-making thing can no
/// longer silently submit a graded answer.
///
/// - Observe (A0): the pair auto-plays; Piper/Clef narrate low/high as
///   each note sounds; free tapping is always available and never
///   interrupts the auto-play. No question, no scoring, no auto-advance —
///   the child moves on via the header's arrow.
/// - Participate (A1): a constant prompt ("Listen for the high one"), the
///   pair auto-plays but a tap cuts it short, then free tapping continues
///   with Clef sparkling on the target. No question, no wrong answers, no
///   auto-advance.
/// - Trigger (A2): same auto-play/cut-short/free-tap as Participate, plus
///   a draggable Clef the child drops onto the target instrument. A wrong
///   drop gets a gentle retry (fresh listen, no failure state); a correct
///   drop is recorded and auto-advances.
class HighLowGameState extends ChangeNotifier {
  final AudioController _audio;
  final PromptGenerator _generator;
  final RoundSequencer _sequencer;
  final Random _instrumentRandom;
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

  HighLowInstrument _leftInstrument = HighLowInstrument.guitar;
  HighLowInstrument _rightInstrument = HighLowInstrument.guitar;

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
  bool _hintVisible = false;
  DragFeedback _dragFeedback = DragFeedback.none;
  int? _lastDropSide;
  VoiceLine? _activeCaption;

  // Per-round instrumentation (reset in _startRound; see [instrumentation]).
  bool _waitedForPlaythrough = true;
  int? _firstResponseSide;
  bool? _firstResponseCorrect;
  int _listenAgainCount = 0;

  HighLowGameState({
    AudioController? audio,
    PromptGenerator? generator,
    RoundSequencer? sequencer,
    Random? instrumentRandom,
    this.totalPrompts = 5,
    this.agencyStage = AgencyStage.trigger,
    this.conceptTier = ConceptTier.t1,
    this.roundOrder = RoundOrder.blocked,
  }) : _audio = audio ?? AudioController.instance,
       _generator = generator ?? PromptGenerator(),
       _sequencer = sequencer ?? RoundSequencer(),
       _instrumentRandom = instrumentRandom ?? Random();

  // ---- Session-level getters ----
  GameStatus get status => _status;
  int get currentPromptIndex => _currentPromptIndex;
  int get correctCount => _results.where((r) => r.isCorrect).length;
  List<PromptResult> get results => List.unmodifiable(_results);

  /// Local-only, in-memory behavioral signals — see [RoundInstrumentation].
  List<RoundInstrumentation> get instrumentation =>
      List.unmodifiable(_instrumentation);

  HighLowInstrument get leftInstrument => _leftInstrument;
  HighLowInstrument get rightInstrument => _rightInstrument;

  HighLowPrompt? get currentPrompt =>
      _prompts.isNotEmpty && _currentPromptIndex < _prompts.length
      ? _prompts[_currentPromptIndex]
      : null;

  // ---- Round/phase-level getters ----
  int? get playingIndex => _playingIndex;

  /// True while the pair's auto-play sequence is actively running (i.e.
  /// hasn't finished or been cut off yet).
  bool get introPlaying => _introPlaying;

  /// True only for Participate, once the child can act — drives Clef
  /// sparkling on the target instrument.
  bool get showHint => _hintVisible;

  DragFeedback get dragFeedback => _dragFeedback;

  /// Which side Clef was last dropped on (correct or not) — the UI uses
  /// this to know which instrument to animate for [dragFeedback].
  int? get lastDropSide => _lastDropSide;

  /// Caption text to show right now (placeholder for the not-yet-recorded
  /// voice lines — see [VoiceLine]), or null between captions.
  String? get captionText => _activeCaption?.captionText;

  /// Whether the child can drop Clef onto an instrument right now.
  bool get canDropClef =>
      agencyStage == AgencyStage.trigger && _status == GameStatus.awaitingInput;

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

  void _startRound() {
    final token = ++_roundToken;
    _cancelPendingTimer();
    _playingIndex = null;
    _dragFeedback = DragFeedback.none;
    _lastDropSide = null;
    _hintVisible = false;
    _waitedForPlaythrough = true;
    _firstResponseSide = null;
    _firstResponseCorrect = null;
    _listenAgainCount = 0;
    _pickInstruments();

    final prompt = currentPrompt;
    _activeCaption = switch (agencyStage) {
      AgencyStage.observe => null, // narrated live as each note plays
      AgencyStage.participate =>
        prompt?.targetDirection == PitchDirection.higher
            ? VoiceLine.listenForHigh
            : VoiceLine.listenForLow,
      AgencyStage.trigger =>
        prompt?.targetDirection == PitchDirection.higher
            ? VoiceLine.putClefOnHigh
            : VoiceLine.putClefOnLow,
    };
    if (_activeCaption != null) {
      unawaited(_audio.playVoiceLine(_activeCaption!));
    }

    _status = GameStatus.playing;
    notifyListeners();
    unawaited(_runIntro(token));
  }

  /// Randomly pick the instrument(s) for the round about to play. Tier
  /// controls whether both sides share one instrument or use two
  /// different ones (see [ConceptTier.sameInstrument]) — each instrument
  /// has its own "1"/"2" character art, used here for whichever side
  /// (left/right) it lands on regardless of whether the pair matches.
  void _pickInstruments() {
    final values = HighLowInstrument.values;
    _leftInstrument = values[_instrumentRandom.nextInt(values.length)];
    if (conceptTier.sameInstrument) {
      _rightInstrument = _leftInstrument;
    } else {
      HighLowInstrument other;
      do {
        other = values[_instrumentRandom.nextInt(values.length)];
      } while (other == _leftInstrument);
      _rightInstrument = other;
    }
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
      unawaited(_audio.playVoiceLine(_activeCaption!));
    }
    notifyListeners();

    await _audio.playNoteForScale(
      prompt.firstNote,
      instrument: _leftInstrument.sampleInstrument,
    );
    if (token != _roundToken) return;

    // Long enough for the first sample to decay before the splice into the
    // second note — see the original High/Low implementation notes
    // (Trello card 57/58); unchanged here.
    await _delay(const Duration(milliseconds: 2300));
    if (token != _roundToken) return;

    _playingIndex = 1;
    if (agencyStage == AgencyStage.observe) {
      _activeCaption = prompt.leftIsHigher
          ? VoiceLine.piperSaysLow
          : VoiceLine.clefSaysHigh;
      unawaited(_audio.playVoiceLine(_activeCaption!));
    }
    notifyListeners();

    await _audio.playNoteForScale(
      prompt.secondNote,
      instrument: _rightInstrument.sampleInstrument,
    );
    if (token != _roundToken) return;

    _finishIntro(token);
  }

  void _finishIntro(int token) {
    if (token != _roundToken) return;
    _introPlaying = false;
    _playingIndex = null;
    _hintVisible = agencyStage == AgencyStage.participate;
    _status = GameStatus.awaitingInput;
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

    _playingIndex = side;
    if (agencyStage == AgencyStage.observe) {
      _activeCaption = side == prompt.higherSide
          ? VoiceLine.clefSaysHigh
          : VoiceLine.piperSaysLow;
      unawaited(_audio.playVoiceLine(_activeCaption!));
    }
    notifyListeners();

    final instrument = side == 0 ? _leftInstrument : _rightInstrument;
    final note = side == 0 ? prompt.firstNote : prompt.secondNote;
    unawaited(
      _audio
          .playNoteForScale(note, instrument: instrument.sampleInstrument)
          .then((_) {
            // Only clear the wiggle if nothing newer (another tap, the
            // next round) has already taken over `_playingIndex`.
            if (_playingIndex == side) {
              _playingIndex = null;
              notifyListeners();
            }
          }),
    );
  }

  /// Trigger-only: the child drops Clef onto [side]. Never a failure
  /// state — a wrong drop just retries with a fresh listen.
  void dropClef(int side) {
    if (!canDropClef) return;
    final prompt = currentPrompt;
    if (prompt == null) return;

    _lastDropSide = side;
    _firstResponseSide ??= side;
    _firstResponseCorrect ??= side == prompt.targetSide;

    final token = _roundToken;
    if (side == prompt.targetSide) {
      _dragFeedback = DragFeedback.correct;
      _status = GameStatus.showingFeedback;
      _audio.playSfx(SfxType.correct);
      _recordRoundResult();
      notifyListeners();

      _schedule(const Duration(milliseconds: 1200), () {
        if (token != _roundToken) return;
        if (_currentPromptIndex < totalPrompts - 1) {
          _currentPromptIndex++;
          _startRound();
        } else {
          _completeGame();
        }
      });
    } else {
      _dragFeedback = DragFeedback.retry;
      _activeCaption = VoiceLine.tryAgainListen;
      unawaited(_audio.playVoiceLine(_activeCaption!));
      _status = GameStatus.showingFeedback;
      notifyListeners();

      _schedule(const Duration(milliseconds: 1400), () {
        if (token != _roundToken) return;
        _dragFeedback = DragFeedback.none;
        _activeCaption = prompt.targetDirection == PitchDirection.higher
            ? VoiceLine.putClefOnHigh
            : VoiceLine.putClefOnLow;
        _status = GameStatus.playing;
        notifyListeners();
        unawaited(_runIntro(token));
      });
    }
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
      ),
    );
  }

  /// Replay the current round's pair. Always available except while a
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
  }

  /// Move on to the next round (or finish the session) right now,
  /// regardless of phase. Always available — an adult needs to be able to
  /// advance a tiring child past a round that will never satisfy any
  /// gating condition on its own (Observe/Participate never auto-advance;
  /// Trigger might be mid-retry).
  void moveOn() {
    if (_status == GameStatus.completed) return;
    _audio.stopCurrentNote();
    _cancelPendingTimer();

    // Skipped rounds aren't scored — nothing to record, this isn't an
    // answer of any kind.
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
    _status = GameStatus.completed;
    _audio.playSfx(SfxType.reward);
    notifyListeners();
  }

  /// Reset the game to play again.
  void reset() {
    _roundToken++;
    _cancelPendingTimer();
    _status = GameStatus.notStarted;
    _prompts = [];
    _currentPromptIndex = 0;
    _results.clear();
    _instrumentation.clear();
    _activeCaption = null;
    notifyListeners();
  }

  PromptResult? get lastResult => _results.isNotEmpty ? _results.last : null;

  @override
  void dispose() {
    _roundToken++;
    _cancelPendingTimer();
    super.dispose();
  }
}

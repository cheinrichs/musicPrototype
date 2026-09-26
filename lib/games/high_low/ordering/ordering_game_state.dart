import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../audio/audio_controller.dart';
import '../../../audio/sfx_type.dart';
import '../../../models/concept_tier.dart';
import '../../../models/game_status.dart';
import '../../../models/pitch_direction.dart';
import '../services/prompt_generator.dart';
import 'ordering_round.dart';

/// What happened in one ordering round, kept locally for assessment (the
/// tick and the return already tell the *child* how they did; this is for
/// the adult and for progression).
@immutable
class OrderingResult {
  final int promptNumber;

  /// How many times a full set of placements was checked.
  final int evaluations;

  /// Replays used. Three are offered; the count is the signal, not a cap.
  final int replaysUsed;

  /// How many instruments were right on the first check (never exactly
  /// `notes - 1`: see [OrderingRound.correctNotes]). Null if the round was
  /// skipped before any check.
  final int? firstEvaluationCorrect;

  final bool skipped;

  const OrderingResult({
    required this.promptNumber,
    required this.evaluations,
    required this.replaysUsed,
    required this.firstEvaluationCorrect,
    required this.skipped,
  });
}

/// State for High/Low's A4 ordering screen (Trello card 11, Panel 3): drag
/// each instrument onto a platform of the tree in pitch order.
///
/// - **An instrument sounds as it lands** — the sound follows the action.
/// - **Nothing is evaluated until every platform in play is filled**, and
///   there is no confirm button: a four-year-old shouldn't have to find one.
/// - **On evaluation the right ones are locked** (the screen ticks them and
///   they stay put) **and the wrong ones go back to their stumps.** Nothing
///   marks a wrong one — "describe the answer, not the attempt".
/// - The child can then place the returned ones again, until the round is
///   right.
///
/// Layout-agnostic on purpose: which stump an instrument came from is just
/// its note index (stable for the round, so nothing reflows when one is
/// placed), and where a wrong one travels back from is the screen's to work
/// out — this only says *which* went back ([returnedNotes]) and *when*
/// ([returnSerial]).
class OrderingGameState extends ChangeNotifier {
  /// Gap between notes in the opening playback and in a replay.
  static const noteGap = Duration(milliseconds: 1300);

  /// Pause between the last instrument landing and the check, so the tick
  /// doesn't appear before the landing has settled.
  static const evaluateDelay = Duration(milliseconds: 450);

  /// How long a finished round is celebrated before the next one.
  static const celebrateFor = Duration(milliseconds: 1400);

  /// How long a tapped or landed instrument keeps its note glow.
  static const tapRing = Duration(milliseconds: 1600);

  /// Replays offered per round (HIGH_LOW_TIERS.md: three at A4). More are
  /// never refused; how many were used is what's recorded.
  static const freeReplays = 3;

  final ConceptTier tier;
  final int totalPrompts;

  final AudioController _audio;
  final PromptGenerator _generator;
  final Future<void> Function(String assetPath) _playNote;

  OrderingGameState({
    required this.tier,
    this.totalPrompts = 5,
    AudioController? audio,
    PromptGenerator? generator,
    Future<void> Function(String assetPath)? playNote,
  }) : _audio = audio ?? AudioController.instance,
       _generator = generator ?? PromptGenerator(),
       _playNote =
           playNote ??
           ((path) =>
               (audio ?? AudioController.instance).playAssetForScale(path));

  GameStatus _status = GameStatus.notStarted;
  int _promptIndex = 0;
  OrderingRound? _round;
  final List<OrderingResult> _results = [];

  /// note index -> slot, for every instrument currently on the tree.
  final Map<int, int> _placements = {};
  final Set<int> _locked = {};
  Set<int> _returned = {};
  Map<int, int> _returnedFrom = {};
  int _returnSerial = 0;
  int? _playingIndex;
  int _evaluations = 0;
  int _replaysUsed = 0;
  int? _firstEvaluationCorrect;

  int _sequenceToken = 0;
  int _evaluationToken = 0;
  int _roundToken = 0;
  Timer? _sequenceTimer;
  Timer? _evaluationTimer;
  Timer? _advanceTimer;
  Timer? _glowTimer;

  GameStatus get status => _status;
  int get currentPromptIndex => _promptIndex;
  OrderingRound? get round => _round;
  List<OrderingResult> get results => List.unmodifiable(_results);

  /// Rounds finished properly (not skipped).
  int get correctCount => _results.where((r) => !r.skipped).length;

  /// Instruments on the tree right now, as note index -> slot.
  Map<int, int> get placements => Map.unmodifiable(_placements);

  /// Instruments whose placement was right and now stays put (ticked).
  Set<int> get lockedNotes => Set.unmodifiable(_locked);

  /// The notes the latest check sent back to their stumps. Replaced on every
  /// check; empty when the check found nothing wrong.
  Set<int> get returnedNotes => Set.unmodifiable(_returned);

  /// For each note in [returnedNotes], the platform it was sent back from —
  /// so the screen can draw the journey home from where it stood.
  Map<int, int> get returnedFrom => Map.unmodifiable(_returnedFrom);

  /// Bumped once per check that sent anything back — the screen watches it
  /// to start each returned instrument's journey home exactly once.
  int get returnSerial => _returnSerial;

  /// Which instrument's note is ringing (glowing), by note index.
  int? get playingIndex => _playingIndex;

  int get evaluations => _evaluations;
  int get replaysUsed => _replaysUsed;

  bool isPlaced(int note) => _placements.containsKey(note);

  /// The instrument on [slot], if any.
  int? occupantOf(int slot) {
    for (final entry in _placements.entries) {
      if (entry.value == slot) return entry.key;
    }
    return null;
  }

  // ---- lifecycle ----

  void startGame() {
    if (_status != GameStatus.notStarted) return;
    _startRound();
  }

  void _startRound() {
    final token = ++_roundToken;
    _cancelRoundTimers();
    _round = OrderingRound.fromPrompt(
      _generator.generatePrompt(
        promptNumber: _promptIndex + 1,
        tier: tier,
        targetDirection: PitchDirection.higher,
      ),
    );
    _placements.clear();
    _locked.clear();
    _returned = {};
    _evaluations = 0;
    _replaysUsed = 0;
    _firstEvaluationCorrect = null;
    _playingIndex = null;
    _status = GameStatus.playing;
    notifyListeners();
    unawaited(_runSequence(token));
  }

  void _advanceOrComplete() {
    if (_promptIndex < totalPrompts - 1) {
      _promptIndex++;
      _startRound();
    } else {
      _cancelRoundTimers();
      _status = GameStatus.completed;
      notifyListeners();
    }
  }

  // ---- playback ----

  Future<void> _runSequence(int roundToken) async {
    final round = _round;
    if (round == null) return;
    final token = ++_sequenceToken;
    for (var i = 0; i < round.notes.length; i++) {
      if (token != _sequenceToken || roundToken != _roundToken) return;
      _playingIndex = i;
      notifyListeners();
      unawaited(_play(round.notes[i]));
      await _wait(noteGap);
    }
    if (token != _sequenceToken || roundToken != _roundToken) return;
    _playingIndex = null;
    if (_status == GameStatus.playing) _status = GameStatus.awaitingInput;
    notifyListeners();
  }

  Future<void> _play(OrderingNote note) =>
      _playNote(note.instrument.assetPathForMidi(note.midi));

  /// Cancellable wait on the playback timer. A cancelled wait simply never
  /// completes (its awaiter stays harmlessly suspended), and the real
  /// [Timer] is gone, so nothing is left pending.
  Future<void> _wait(Duration duration) {
    final completer = Completer<void>();
    _sequenceTimer?.cancel();
    _sequenceTimer = Timer(duration, () {
      _sequenceTimer = null;
      completer.complete();
    });
    return completer.future;
  }

  void _cancelSequence() {
    _sequenceToken++;
    _sequenceTimer?.cancel();
    _sequenceTimer = null;
    if (_status == GameStatus.playing) _status = GameStatus.awaitingInput;
  }

  void _cancelRoundTimers() {
    _sequenceToken++;
    _evaluationToken++;
    for (final t in [
      _sequenceTimer,
      _evaluationTimer,
      _advanceTimer,
      _glowTimer,
    ]) {
      t?.cancel();
    }
    _sequenceTimer = _evaluationTimer = _advanceTimer = _glowTimer = null;
  }

  /// Play the notes again, in their original order. Three are offered; use
  /// beyond that is never refused, only counted.
  void replay() {
    if (_round == null ||
        _status == GameStatus.completed ||
        _status == GameStatus.showingFeedback) {
      return;
    }
    _replaysUsed++;
    _audio.stopCurrentNote();
    unawaited(_runSequence(_roundToken));
  }

  /// A tap on an instrument only plays it — exploration, never a placement.
  void tapInstrument(int note) {
    final round = _round;
    if (round == null || note < 0 || note >= round.notes.length) return;
    _cancelSequence();
    unawaited(_play(round.notes[note]));
    _glow(note);
  }

  void _glow(int note) {
    _playingIndex = note;
    _glowTimer?.cancel();
    _glowTimer = Timer(tapRing, () {
      _glowTimer = null;
      if (_playingIndex == note) {
        _playingIndex = null;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  // ---- placing ----

  /// Drop instrument [note] on platform [slot]. Returns whether it landed:
  /// a platform that's occupied, unused this round, or an instrument that's
  /// already locked in place refuses it (and the screen sends it home).
  bool dropOnSlot(int note, int slot) {
    final round = _round;
    if (round == null ||
        _status == GameStatus.notStarted ||
        _status == GameStatus.completed ||
        _status == GameStatus.showingFeedback) {
      return false;
    }
    if (note < 0 || note >= round.notes.length) return false;
    if (!round.activeSlots.contains(slot)) return false;
    if (_locked.contains(note)) return false;
    if (occupantOf(slot) != null) return false;

    _cancelSequence();
    _evaluationToken++;
    _evaluationTimer?.cancel();
    _placements[note] = slot;

    // The sound follows the action.
    unawaited(_play(round.notes[note]));
    _glow(note);

    if (_placements.length == round.activeSlots.length) {
      final token = _evaluationToken;
      final roundToken = _roundToken;
      _evaluationTimer = Timer(evaluateDelay, () {
        _evaluationTimer = null;
        if (token == _evaluationToken && roundToken == _roundToken) {
          _evaluate();
        }
      });
    }
    notifyListeners();
    return true;
  }

  /// Pick instrument [note] back up off the tree (a drag starting from a
  /// platform). Locked instruments stay where they are. Lifting one cancels
  /// a check that was about to happen.
  void lift(int note) {
    if (_locked.contains(note) || !_placements.containsKey(note)) return;
    _placements.remove(note);
    _evaluationToken++;
    _evaluationTimer?.cancel();
    _evaluationTimer = null;
    notifyListeners();
  }

  // ---- checking ----

  void _evaluate() {
    final round = _round;
    if (round == null) return;
    _evaluations++;

    final correct = round.correctNotes(_placements);
    _firstEvaluationCorrect ??= correct.length;
    _locked.addAll(correct);

    final wrong = _placements.keys.where((n) => !correct.contains(n)).toSet();
    _returnedFrom = {for (final n in wrong) n: _placements[n]!};
    for (final n in wrong) {
      _placements.remove(n);
    }
    _returned = wrong;
    if (wrong.isNotEmpty) _returnSerial++;

    if (wrong.isEmpty) {
      _finishRound(skipped: false);
    } else {
      notifyListeners();
    }
  }

  void _finishRound({required bool skipped}) {
    final round = _round;
    if (round == null) return;
    _results.add(
      OrderingResult(
        promptNumber: _promptIndex + 1,
        evaluations: _evaluations,
        replaysUsed: _replaysUsed,
        firstEvaluationCorrect: _firstEvaluationCorrect,
        skipped: skipped,
      ),
    );
    if (skipped) {
      _advanceOrComplete();
      return;
    }
    _status = GameStatus.showingFeedback;
    _audio.playSfx(SfxType.correct);
    final roundToken = _roundToken;
    _advanceTimer = Timer(celebrateFor, () {
      _advanceTimer = null;
      if (roundToken == _roundToken) _advanceOrComplete();
    });
    notifyListeners();
  }

  /// The adult's skip: move on, recording no answer.
  void escape() {
    if (_round == null ||
        _status == GameStatus.completed ||
        _status == GameStatus.notStarted) {
      return;
    }
    _audio.stopCurrentNote();
    _finishRound(skipped: true);
  }

  @override
  void dispose() {
    _cancelRoundTimers();
    super.dispose();
  }
}

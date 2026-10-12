import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import '../../../audio/audio_controller.dart';
import '../../../audio/shared_voice_line.dart';
import '../../../audio/sfx_type.dart';
import '../../../models/agency_stage.dart';
import '../../../models/concept_tier.dart';
import '../../../models/game_status.dart';
import '../../../models/round_order.dart';
import '../../high_low/models/round_instrumentation.dart';
import '../../shared/nudges.dart';
import '../models/loud_quiet_round.dart';

/// What a Decide drop is showing: nothing, a correct landing, or a gentle
/// "not that one" settling back.
enum LoudQuietDrop { none, correct, retry }

/// The Loud or Quiet game (Trello card 162): the same three agency levels as
/// High vs Low, about loudness instead of pitch.
///
/// - **Observe:** two sounds play; the child taps each as often as they like;
///   the needle swings to how loud each one is; the earned arrow moves on.
/// - **Explore:** the round asks for the loud (Clef) or the quiet (Piper)
///   one; correct taps build a sparkle on that instrument; five finish the
///   round in confetti. No failure state.
/// - **Decide:** drag the asked-for one to its end of the dial — loud to the
///   far side, quiet to the near side.
///
/// **Built directly, not on a shared template** (card 162: extract one from
/// two real examples). Parallels to `HighLowGameState`, to compare when that
/// happens: the round token, the status machine, the earned arrow, Explore's
/// five-correct-taps rule and six-second guidance, the five-tap nudge rule
/// with the shared pool, the thinking pose while a nudge plays, the skip
/// logged as its own event, and [RoundInstrumentation] (borrowed as-is).
///
/// **The needle moves only on a tap the child makes** (card 162), never
/// while a round's sounds play at its start or on a replay — that would show
/// the answer before the question. It also stays still at Decide, where the
/// child answers: a needle that read out each tap would let them answer by
/// looking instead of listening (card 167 says to decide this deliberately;
/// decided here, for Cooper to overrule).
///
/// **No voice lines are recorded yet** (card 182), so the characters say
/// nothing, rather than playing placeholder speech; only the shared nudges,
/// which exist, are heard.
class LoudQuietGameState extends ChangeNotifier {
  LoudQuietGameState({
    AudioController? audio,
    math.Random? random,
    this.totalPrompts = 5,
    this.agencyStage = AgencyStage.observe,
    this.conceptTier = ConceptTier.t1,
    this.roundOrder = RoundOrder.blocked,
    NudgePool? nudges,
  }) : _audio = audio ?? AudioController.instance,
       _random = random ?? math.Random(),
       _nudges = nudges ?? NudgePool();

  final AudioController _audio;
  final math.Random _random;
  final NudgePool _nudges;
  final int totalPrompts;

  /// Settable before [startGame], like High vs Low's.
  AgencyStage agencyStage;
  ConceptTier conceptTier;
  RoundOrder roundOrder;

  /// How long each sound is left to ring before the next, as in High vs Low.
  static const noteGap = Duration(milliseconds: 2300);

  /// How long a correct answer celebrates before the next round.
  static const celebration = Duration(milliseconds: 1200);

  /// The least time a "not that one" shows, as a wrong drop does on the tree.
  static const retryMinimum = Duration(milliseconds: 1400);

  /// When Explore's parent guidance arrives, as on High vs Low.
  static const guidanceDelay = Duration(seconds: 6);

  final List<LoudQuietRound> _rounds = [];
  int _index = 0;
  GameStatus _status = GameStatus.notStarted;
  int _token = 0;
  Timer? _timer;
  Timer? _guidanceTimer;
  Timer? _ringTimer;
  Timer? _consideringTimer;
  Timer? _retryTimer;

  int? _playingIndex;
  double _needle = 0;
  final Set<int> _heard = {};
  final List<int> _tapSequence = [];
  bool _showArrow = false;
  int _correctTaps = 0;
  int _wrongTaps = 0;
  final FiveTapCounter _exploreTaps = FiveTapCounter();
  bool _guidanceVisible = false;
  LoudQuietDrop _drop = LoudQuietDrop.none;
  int? _lastDropSide;
  bool _considering = false;
  int _replays = 0;
  bool _waitedForPlaythrough = true;
  int? _firstResponseSide;
  bool _roundRecorded = false;
  int _confettiTrigger = 0;
  int _correct = 0;
  final List<RoundInstrumentation> _records = [];

  // ---- reading ----

  GameStatus get status => _status;
  int get currentPromptIndex => _index;
  LoudQuietRound? get currentRound =>
      _index < _rounds.length ? _rounds[_index] : null;

  /// The note-playing ring on an instrument, as on High vs Low.
  int? get playingIndex => _playingIndex;

  /// Where the needle points: −1 the quiet end, 0 straight up (rest), +1 the
  /// loud end.
  double get needle => _needle;

  /// Observe: the earned arrow, once every instrument has been heard.
  bool get showArrow => agencyStage == AgencyStage.observe && _showArrow;

  /// Explore: how many correct taps so far this round (the sparkle's count).
  int get correctTapProgress => _correctTaps;

  /// Explore: the instrument wearing the sparkle, once found.
  int? get sparkleSide => agencyStage == AgencyStage.explore && _correctTaps > 0
      ? currentRound?.targetSide
      : null;

  LoudQuietDrop get drop => _drop;
  int? get lastDropSide => _lastDropSide;

  /// Whether the asking character is "considering" — the thinking pose —
  /// while a nudge plays or a wrong drop settles back.
  bool get isConsidering => _considering;

  /// Bumped when the fifth correct tap at Explore fires the confetti.
  int get confettiTrigger => _confettiTrigger;

  /// Decide: a drop can land.
  bool get canDrop =>
      agencyStage == AgencyStage.decide &&
      _status != GameStatus.completed &&
      _drop != LoudQuietDrop.correct;

  /// Whether the round asks about the loud pole — Clef's — or the quiet one,
  /// Piper's.
  bool get asksLoud => currentRound?.asksLoud ?? true;

  int get correctCount => _correct;
  List<RoundInstrumentation> get records => List.unmodifiable(_records);

  /// The parent instruction (adult-facing; the child doesn't read).
  String? get captionText {
    final round = currentRound;
    if (round == null) return null;
    final pole = round.asksLoud ? 'loud' : 'quiet';
    return switch (agencyStage) {
      AgencyStage.observe => 'Let them tap each one and watch the dial.',
      AgencyStage.explore => 'Let them tap both and find the $pole one.',
      AgencyStage.decide =>
        round.asksLoud
            ? 'Help them put the loud one over at the far side.'
            : 'Help them put the quiet one over at the near side.',
    };
  }

  /// Explore's guidance, six seconds in — beneath the instruction, never
  /// instead of it (card 193).
  String? get guidanceText {
    if (!_guidanceVisible ||
        agencyStage != AgencyStage.explore ||
        _status != GameStatus.awaitingInput) {
      return null;
    }
    return 'Encourage them to keep tapping the '
        '${asksLoud ? 'loud' : 'quiet'} one.';
  }

  // ---- the session ----

  void startGame() {
    _rounds.clear();
    final half = (totalPrompts + 1) ~/ 2;
    for (var i = 0; i < totalPrompts; i++) {
      final asksLoud = switch (roundOrder) {
        RoundOrder.blocked => i < half,
        RoundOrder.mixed => _random.nextBool(),
      };
      _rounds.add(
        LoudQuietRound.generate(
          tier: conceptTier,
          asksLoud: asksLoud,
          random: _random,
        ),
      );
    }
    _index = 0;
    _correct = 0;
    _records.clear();
    _startRound();
  }

  void _startRound() {
    final token = ++_token;
    _cancelTimers();
    _playingIndex = null;
    _needle = 0;
    _heard.clear();
    _tapSequence.clear();
    _showArrow = false;
    _correctTaps = 0;
    _wrongTaps = 0;
    _exploreTaps.reset();
    _guidanceVisible = false;
    _drop = LoudQuietDrop.none;
    _lastDropSide = null;
    _considering = false;
    _replays = 0;
    _waitedForPlaythrough = true;
    _firstResponseSide = null;
    _roundRecorded = false;
    unawaited(_playRound(token));
  }

  /// The round's two sounds, in order — at its start and on a replay. The
  /// needle does not move: it answers only the child's own taps.
  Future<void> _playRound(int token) async {
    _status = GameStatus.playing;
    notifyListeners();
    final round = currentRound;
    if (round == null) return;
    for (final side in [0, 1]) {
      if (token != _token) return;
      _ring(side);
      unawaited(_playSide(side));
      await _wait(noteGap);
    }
    if (token != _token) return;
    _becomeAnswerable(token);
  }

  void _becomeAnswerable(int token) {
    _status = GameStatus.awaitingInput;
    _guidanceVisible = false;
    _guidanceTimer?.cancel();
    if (agencyStage == AgencyStage.explore) {
      _guidanceTimer = Timer(guidanceDelay, () {
        if (token != _token) return;
        _guidanceVisible = true;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> _playSide(int side) async {
    final round = currentRound;
    if (round == null) return;
    await _audio.playAssetForScale(
      round.instrumentOf(side).assetPathForMidi(round.midi),
      volume: round.gainOf(side),
    );
  }

  void _ring(int side) {
    _playingIndex = side;
    _ringTimer?.cancel();
    _ringTimer = Timer(const Duration(milliseconds: 1200), () {
      _playingIndex = null;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _wait(Duration d) {
    final done = Completer<void>();
    _timer?.cancel();
    _timer = Timer(d, done.complete);
    return done.future;
  }

  // ---- the child ----

  /// A tap plays that instrument — exploration at every level, never an
  /// answer at Decide (a drag answers there). A tap during the round's
  /// opening sounds cuts them short.
  void tapInstrument(int side) {
    final round = currentRound;
    if (round == null ||
        _status == GameStatus.notStarted ||
        _status == GameStatus.completed) {
      return;
    }
    if (_status == GameStatus.playing) {
      _waitedForPlaythrough = false;
      _timer?.cancel();
      _becomeAnswerable(++_token);
    }
    _firstResponseSide ??= side;
    _ring(side);
    unawaited(_playSide(side));

    // The dial answers the child's own tap — at the levels with no answer
    // to give away.
    if (agencyStage != AgencyStage.decide) {
      _needle = LoudQuietRound.needlePosition(round.gainOf(side));
    }

    switch (agencyStage) {
      case AgencyStage.observe:
        _heard.add(side);
        _tapSequence.add(side);
        if (_heard.length >= 2) _showArrow = true;
      case AgencyStage.explore:
        if (side == round.targetSide) {
          _stopConsidering();
          _correctTaps++;
          if (_correctTaps >= 5) {
            _confettiTrigger++;
            _celebrate(side);
          }
        } else {
          _wrongTaps++;
        }
        final fired = _exploreTaps.tap(side);
        if (fired && side != round.targetSide) _nudge(_token);
      case AgencyStage.decide:
        break;
    }
    notifyListeners();
  }

  /// Decide: the child dropped instrument [side] on the slot.
  void dropInstrument(int side) {
    final round = currentRound;
    if (round == null || !canDrop) return;
    _firstResponseSide ??= side;
    _lastDropSide = side;
    if (side == round.targetSide) {
      _celebrate(side);
      return;
    }
    _wrongTaps++;
    _drop = LoudQuietDrop.retry;
    final token = _token;
    _nudge(token);
    // Its own timer, unguarded by the round token: a replay restarts the
    // sounds (bumping the token, reusing [_timer]) and must not strand the
    // "not that one" on screen. A new round cancels it in [_cancelTimers].
    _retryTimer?.cancel();
    _retryTimer = Timer(retryMinimum, () {
      _drop = LoudQuietDrop.none;
      notifyListeners();
    });
    notifyListeners();
  }

  /// One gentle nudge from the shared pool, in the asking character's voice,
  /// with them in the thinking pose for the line or [retryMinimum].
  void _nudge(int token) {
    final line = _nudges.next(
      asksLoud ? NudgeSpeaker.clef : NudgeSpeaker.piper,
    );
    _stopConsidering();
    _considering = true;
    final minimum = Completer<void>();
    _consideringTimer = Timer(retryMinimum, minimum.complete);
    notifyListeners();
    unawaited(
      Future.wait([_audio.playVoiceLineAndAwait(line), minimum.future]).then((
        _,
      ) {
        if (token != _token || !_considering) return;
        _considering = false;
        notifyListeners();
      }),
    );
  }

  void _stopConsidering() {
    _consideringTimer?.cancel();
    _consideringTimer = null;
    _considering = false;
  }

  void _celebrate(int side) {
    final token = ++_token;
    _guidanceTimer?.cancel();
    _guidanceVisible = false;
    _stopConsidering();
    _lastDropSide = side;
    _drop = LoudQuietDrop.correct;
    _status = GameStatus.showingFeedback;
    _audio.playSfx(SfxType.correct);
    _correct++;
    _record();
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(celebration, () {
      if (token != _token) return;
      _advance();
    });
  }

  /// Observe's earned arrow: the child decides they're done.
  void tapArrow() {
    if (!showArrow) return;
    _audio.playSfx(SfxType.correct);
    // A finished round counts, as High vs Low counts every round not
    // skipped — Observe has no wrong answer.
    _correct++;
    _record();
    _advance();
  }

  /// Tapping a character replays the round (card 195), as on High vs Low:
  /// the character first, then the two sounds. The other character gives
  /// the shared giggle, never the asking one's cue; the asking one's cue
  /// waits on this game's lines (card 182), so its tap goes straight to the
  /// sounds. Neither giggle is recorded yet, so both are silent for now.
  Future<void> tapCharacter({required bool piper}) async {
    if (_status == GameStatus.completed ||
        _status == GameStatus.showingFeedback ||
        _status == GameStatus.notStarted) {
      return;
    }
    _replays++;
    final token = ++_token;
    _guidanceTimer?.cancel();
    _timer?.cancel();
    final asking = asksLoud ? !piper : piper;
    if (!asking) {
      _status = GameStatus.playing;
      notifyListeners();
      await _audio.playVoiceLineAndAwait(
        piper ? SharedVoiceLine.gigglePiper : SharedVoiceLine.giggleClef,
      );
      if (token != _token) return;
    }
    await _playRound(token);
  }

  /// The adult's Skip: logged as a skip, never scored (card 173's rule).
  void escape() {
    if (_status == GameStatus.completed) return;
    _audio.stopCurrentNote();
    if (!_roundRecorded) _record(skipped: true);
    _advance();
  }

  void _record({bool skipped = false}) {
    final round = currentRound;
    if (round == null || _roundRecorded) return;
    _roundRecorded = true;
    _records.add(
      RoundInstrumentation(
        promptNumber: _index + 1,
        waitedForPlaythrough: _waitedForPlaythrough,
        firstResponseCorrect: agencyStage == AgencyStage.observe
            ? null
            : _firstResponseSide == null
            ? null
            : _firstResponseSide == round.targetSide,
        listenAgainCount: _replays,
        correctTapCount: _correctTaps,
        wrongTapCount: _wrongTaps,
        observeTapSequence: List.unmodifiable(_tapSequence),
        skipped: skipped,
      ),
    );
  }

  void _advance() {
    if (_index < totalPrompts - 1) {
      _index++;
      _startRound();
    } else {
      ++_token;
      _cancelTimers();
      _status = GameStatus.completed;
      _audio.playSfx(SfxType.reward);
      notifyListeners();
    }
  }

  void _cancelTimers() {
    _timer?.cancel();
    _guidanceTimer?.cancel();
    _ringTimer?.cancel();
    _retryTimer?.cancel();
    _stopConsidering();
  }

  @override
  void dispose() {
    ++_token;
    _cancelTimers();
    super.dispose();
  }
}

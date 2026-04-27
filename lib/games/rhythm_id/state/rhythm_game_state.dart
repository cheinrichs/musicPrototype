import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../audio/audio_controller.dart';
import '../../../audio/note.dart';
import '../../../audio/sfx_type.dart';
import '../../../models/game_status.dart';
import '../../../models/rhythm_pattern.dart';

enum RhythmPhase { patternA, patternB, done }

class RhythmResult {
  final bool areSame;
  final bool userSaidSame;
  bool get isCorrect => areSame == userSaidSame;
  const RhythmResult({required this.areSame, required this.userSaidSame});
}

class RhythmGameState extends ChangeNotifier {
  final AudioController _audio;
  final int totalPrompts;
  final _rng = Random();

  GameStatus _status = GameStatus.notStarted;
  RhythmPhase _phase = RhythmPhase.patternA;
  RhythmPattern? _patternA;
  RhythmPattern? _patternB;
  bool _areSame = false;
  int _currentPromptIndex = 0;
  final List<RhythmResult> _results = [];
  bool _isDisposed = false;

  RhythmGameState({AudioController? audio, this.totalPrompts = 5})
      : _audio = audio ?? AudioController.instance;

  GameStatus get status => _status;
  RhythmPhase get phase => _phase;
  int get currentPromptIndex => _currentPromptIndex;
  int get correctCount => _results.where((r) => r.isCorrect).length;
  List<RhythmResult> get results => List.unmodifiable(_results);
  RhythmResult? get lastResult => _results.isNotEmpty ? _results.last : null;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void startGame() {
    _currentPromptIndex = 0;
    _results.clear();
    _status = GameStatus.playing;
    _safeNotify();
    _playCurrentPrompt();
  }

  Future<void> _playCurrentPrompt() async {
    _areSame = _rng.nextBool();
    final indexA = _rng.nextInt(RhythmPattern.pool.length);
    _patternA = RhythmPattern.pool[indexA];

    if (_areSame) {
      _patternB = _patternA;
    } else {
      int indexB;
      do {
        indexB = _rng.nextInt(RhythmPattern.pool.length);
      } while (indexB == indexA);
      _patternB = RhythmPattern.pool[indexB];
    }

    _phase = RhythmPhase.patternA;
    _status = GameStatus.playing;
    _safeNotify();

    await _playPattern(_patternA!);
    if (_isDisposed) return;

    await Future.delayed(const Duration(milliseconds: 800));
    if (_isDisposed) return;

    _phase = RhythmPhase.patternB;
    _safeNotify();

    await _playPattern(_patternB!);
    if (_isDisposed) return;

    _phase = RhythmPhase.done;
    _status = GameStatus.awaitingInput;
    _safeNotify();
  }

  // Uses Note.c5 as beat — swap for woodblock once .aif files are converted to .mp3/.wav
  Future<void> _playPattern(RhythmPattern pattern) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    for (final offset in pattern.beatOffsets) {
      if (_isDisposed) return;
      final elapsed = DateTime.now().millisecondsSinceEpoch - start;
      final delay = offset - elapsed;
      if (delay > 0) await Future.delayed(Duration(milliseconds: delay));
      if (_isDisposed) return;
      _audio.playNote(Note.c5);
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> replay() async {
    if (_status != GameStatus.awaitingInput || _patternA == null || _isDisposed) return;
    _status = GameStatus.playing;
    _phase = RhythmPhase.patternA;
    _safeNotify();

    await _playPattern(_patternA!);
    if (_isDisposed) return;
    await Future.delayed(const Duration(milliseconds: 800));
    if (_isDisposed) return;

    _phase = RhythmPhase.patternB;
    _safeNotify();

    await _playPattern(_patternB!);
    if (_isDisposed) return;

    _phase = RhythmPhase.done;
    _status = GameStatus.awaitingInput;
    _safeNotify();
  }

  void submitAnswer(bool userSaidSame) {
    if (_status != GameStatus.awaitingInput || _isDisposed) return;

    _results.add(RhythmResult(areSame: _areSame, userSaidSame: userSaidSame));

    if (userSaidSame == _areSame) {
      _audio.playSfx(SfxType.correct);
    } else {
      _audio.playSfx(SfxType.incorrect);
    }

    _status = GameStatus.showingFeedback;
    _safeNotify();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_isDisposed) return;
      if (_currentPromptIndex < totalPrompts - 1) {
        _currentPromptIndex++;
        _playCurrentPrompt();
      } else {
        _status = GameStatus.completed;
        _audio.playSfx(SfxType.reward);
        _safeNotify();
      }
    });
  }
}

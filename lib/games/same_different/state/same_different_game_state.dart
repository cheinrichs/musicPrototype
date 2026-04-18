import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../audio/audio_controller.dart';
import '../../../audio/note.dart';
import '../../../audio/sfx_type.dart';
import '../../../models/game_status.dart';
import '../models/same_different_prompt.dart';
import '../services/same_different_generator.dart';

/// Result of a single prompt
class SameDifferentResult {
  final SameDifferentPrompt prompt;
  final bool userSaidSame;
  final bool isCorrect;

  const SameDifferentResult({
    required this.prompt,
    required this.userSaidSame,
    required this.isCorrect,
  });
}

/// Which melody is currently being played
enum MelodyPhase { first, second, done }

/// State management for the Same or Different game
class SameDifferentGameState extends ChangeNotifier {
  final AudioController _audio;
  final SameDifferentGenerator _generator;
  final int totalPrompts;

  GameStatus _status = GameStatus.notStarted;
  MelodyPhase _melodyPhase = MelodyPhase.first;
  List<SameDifferentPrompt> _prompts = [];
  int _currentPromptIndex = 0;
  final List<SameDifferentResult> _results = [];
  int _consecutiveCorrect = 0;
  bool _isDisposed = false;

  SameDifferentGameState({
    AudioController? audio,
    SameDifferentGenerator? generator,
    this.totalPrompts = 5,
  }) : _audio = audio ?? AudioController.instance,
       _generator = generator ?? SameDifferentGenerator();

  // Getters
  GameStatus get status => _status;
  MelodyPhase get melodyPhase => _melodyPhase;
  int get currentPromptIndex => _currentPromptIndex;
  int get correctCount => _results.where((r) => r.isCorrect).length;
  int get consecutiveCorrect => _consecutiveCorrect;
  List<SameDifferentResult> get results => List.unmodifiable(_results);
  bool get isGameComplete => _status == GameStatus.completed;

  SameDifferentPrompt? get currentPrompt =>
      _prompts.isNotEmpty && _currentPromptIndex < _prompts.length
      ? _prompts[_currentPromptIndex]
      : null;

  double get progress =>
      totalPrompts > 0 ? _currentPromptIndex / totalPrompts : 0;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Start a new game
  void startGame() {
    _prompts = _generator.generatePrompts(count: totalPrompts);
    _currentPromptIndex = 0;
    _results.clear();
    _consecutiveCorrect = 0;
    _status = GameStatus.playing;
    _safeNotifyListeners();

    // Play the first prompt
    _playCurrentPrompt();
  }

  /// Play both melodies with a pause between
  Future<void> _playCurrentPrompt() async {
    final prompt = currentPrompt;
    if (prompt == null || _isDisposed) return;

    _status = GameStatus.playing;
    _melodyPhase = MelodyPhase.first;
    _safeNotifyListeners();

    // Play first melody
    await _playMelody(prompt.firstMelody);

    if (_isDisposed) return;

    // Brief pause between melodies
    await Future.delayed(const Duration(milliseconds: 800));

    if (_isDisposed) return;

    // Play second melody
    _melodyPhase = MelodyPhase.second;
    _safeNotifyListeners();

    await _playMelody(prompt.secondMelody);

    if (_isDisposed) return;

    // Now awaiting input
    _melodyPhase = MelodyPhase.done;
    _status = GameStatus.awaitingInput;
    _safeNotifyListeners();
  }

  /// Play a melody (sequence of notes)
  Future<void> _playMelody(List<Note> melody) async {
    for (final note in melody) {
      if (_isDisposed) return;
      await _audio.playNoteForScale(note);
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  /// Replay the current prompt
  Future<void> replayPrompt() async {
    if (_status != GameStatus.awaitingInput || _isDisposed) return;
    await _playCurrentPrompt();
  }

  /// Submit an answer for the current prompt
  void submitAnswer(bool userSaidSame) {
    if (_status != GameStatus.awaitingInput || _isDisposed) return;

    final prompt = currentPrompt;
    if (prompt == null) return;

    final isCorrect = prompt.isCorrect(userSaidSame);

    // Record result
    _results.add(
      SameDifferentResult(
        prompt: prompt,
        userSaidSame: userSaidSame,
        isCorrect: isCorrect,
      ),
    );

    // Update streak
    if (isCorrect) {
      _consecutiveCorrect++;
      _audio.playSfx(SfxType.correct);
    } else {
      _consecutiveCorrect = 0;
      _audio.playSfx(SfxType.incorrect);
    }

    // Show feedback
    _status = GameStatus.showingFeedback;
    _safeNotifyListeners();

    // After feedback delay, advance or complete
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_isDisposed) return;
      if (_currentPromptIndex < totalPrompts - 1) {
        _nextPrompt();
      } else {
        _completeGame();
      }
    });
  }

  void _nextPrompt() {
    _currentPromptIndex++;
    _playCurrentPrompt();
  }

  void _completeGame() {
    _status = GameStatus.completed;
    _audio.playSfx(SfxType.reward);
    _safeNotifyListeners();
  }

  /// Reset the game to play again
  void reset() {
    _status = GameStatus.notStarted;
    _melodyPhase = MelodyPhase.first;
    _prompts = [];
    _currentPromptIndex = 0;
    _results.clear();
    _consecutiveCorrect = 0;
    _safeNotifyListeners();
  }

  /// Get the result of the last answered prompt
  SameDifferentResult? get lastResult =>
      _results.isNotEmpty ? _results.last : null;
}

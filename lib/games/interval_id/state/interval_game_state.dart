import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../audio/audio_controller.dart';
import '../../../audio/sfx_type.dart';
import '../../../models/game_status.dart';
import '../../../models/interval_type.dart';
import '../models/interval_prompt.dart';
import '../services/interval_generator.dart';

/// Result of a single prompt
class IntervalPromptResult {
  final IntervalPrompt prompt;
  final IntervalType userAnswer;
  final bool isCorrect;

  const IntervalPromptResult({
    required this.prompt,
    required this.userAnswer,
    required this.isCorrect,
  });
}

/// State management for the Interval Identification game
class IntervalGameState extends ChangeNotifier {
  final AudioController _audio;
  final IntervalGenerator _generator;
  final int totalPrompts;

  GameStatus _status = GameStatus.notStarted;
  List<IntervalPrompt> _prompts = [];
  int _currentPromptIndex = 0;
  final List<IntervalPromptResult> _results = [];
  int _consecutiveCorrect = 0;

  IntervalGameState({
    AudioController? audio,
    IntervalGenerator? generator,
    this.totalPrompts = 5,
  }) : _audio = audio ?? AudioController.instance,
       _generator = generator ?? IntervalGenerator();

  // Getters
  GameStatus get status => _status;
  int get currentPromptIndex => _currentPromptIndex;
  int get correctCount => _results.where((r) => r.isCorrect).length;
  int get consecutiveCorrect => _consecutiveCorrect;
  List<IntervalPromptResult> get results => List.unmodifiable(_results);
  bool get isGameComplete => _status == GameStatus.completed;

  IntervalPrompt? get currentPrompt =>
      _prompts.isNotEmpty && _currentPromptIndex < _prompts.length
      ? _prompts[_currentPromptIndex]
      : null;

  double get progress =>
      totalPrompts > 0 ? _currentPromptIndex / totalPrompts : 0;

  /// Start a new game
  void startGame() {
    _prompts = _generator.generatePrompts(count: totalPrompts);
    _currentPromptIndex = 0;
    _results.clear();
    _consecutiveCorrect = 0;
    _status = GameStatus.playing;
    notifyListeners();

    // Play the first prompt
    _playCurrentPrompt();
  }

  /// Play the current prompt's interval
  Future<void> _playCurrentPrompt() async {
    final prompt = currentPrompt;
    if (prompt == null) return;

    _status = GameStatus.playing;
    notifyListeners();

    // Play root note
    await _audio.playNoteForScale(prompt.rootNote);
    await Future.delayed(const Duration(milliseconds: 600));

    // Play second note
    await _audio.playNoteForScale(prompt.secondNote);

    // Now awaiting input
    _status = GameStatus.awaitingInput;
    notifyListeners();
  }

  /// Replay the current prompt
  Future<void> replayPrompt() async {
    if (_status != GameStatus.awaitingInput) return;
    await _playCurrentPrompt();
  }

  /// Submit an answer for the current prompt
  void submitAnswer(IntervalType answer) {
    if (_status != GameStatus.awaitingInput) return;

    final prompt = currentPrompt;
    if (prompt == null) return;

    final isCorrect = prompt.isCorrect(answer);

    // Record result
    _results.add(
      IntervalPromptResult(
        prompt: prompt,
        userAnswer: answer,
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
    notifyListeners();

    // After feedback delay, advance or complete
    Future.delayed(const Duration(milliseconds: 1200), () {
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
    notifyListeners();
  }

  /// Reset the game to play again
  void reset() {
    _status = GameStatus.notStarted;
    _prompts = [];
    _currentPromptIndex = 0;
    _results.clear();
    _consecutiveCorrect = 0;
    notifyListeners();
  }

  /// Get the result of the last answered prompt
  IntervalPromptResult? get lastResult =>
      _results.isNotEmpty ? _results.last : null;
}

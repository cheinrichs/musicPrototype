import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../audio/audio_controller.dart';
import '../../../audio/sfx_type.dart';
import '../../../models/game_status.dart';
import '../../../models/scale_direction.dart';
import '../models/scale_direction_prompt.dart';
import '../services/scale_generator.dart';

/// Result of a single prompt
class ScalePromptResult {
  final ScaleDirectionPrompt prompt;
  final ScaleDirection userAnswer;
  final bool isCorrect;

  const ScalePromptResult({
    required this.prompt,
    required this.userAnswer,
    required this.isCorrect,
  });
}

/// State management for the Scale Direction game
class ScaleDirectionGameState extends ChangeNotifier {
  final AudioController _audio;
  final ScaleGenerator _generator;
  final int totalPrompts;

  GameStatus _status = GameStatus.notStarted;
  List<ScaleDirectionPrompt> _prompts = [];
  int _currentPromptIndex = 0;
  final List<ScalePromptResult> _results = [];
  int _consecutiveCorrect = 0;

  ScaleDirectionGameState({
    AudioController? audio,
    ScaleGenerator? generator,
    this.totalPrompts = 5,
  }) : _audio = audio ?? AudioController.instance,
       _generator = generator ?? ScaleGenerator();

  // Getters
  GameStatus get status => _status;
  int get currentPromptIndex => _currentPromptIndex;
  int get correctCount => _results.where((r) => r.isCorrect).length;
  int get consecutiveCorrect => _consecutiveCorrect;
  List<ScalePromptResult> get results => List.unmodifiable(_results);
  bool get isGameComplete => _status == GameStatus.completed;

  ScaleDirectionPrompt? get currentPrompt =>
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

  /// Play the current prompt's scale
  Future<void> _playCurrentPrompt() async {
    final prompt = currentPrompt;
    if (prompt == null) return;

    _status = GameStatus.playing;
    notifyListeners();

    // Play each note in the scale with delays between them
    // Use playNoteForScale to stop previous note before playing next
    for (final note in prompt.scaleNotes) {
      await _audio.playNoteForScale(note);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    // Stop the last note after a short delay
    await Future.delayed(const Duration(milliseconds: 200));
    _audio.stopCurrentNote();

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
  void submitAnswer(ScaleDirection answer) {
    if (_status != GameStatus.awaitingInput) return;

    final prompt = currentPrompt;
    if (prompt == null) return;

    final isCorrect = prompt.isCorrect(answer);

    // Record result
    _results.add(
      ScalePromptResult(
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
  ScalePromptResult? get lastResult =>
      _results.isNotEmpty ? _results.last : null;
}

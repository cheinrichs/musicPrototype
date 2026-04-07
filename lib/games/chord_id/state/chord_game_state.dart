import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../audio/audio_controller.dart';
import '../../../audio/sfx_type.dart';
import '../../../models/game_status.dart';
import '../../../models/chord_type.dart';
import '../models/chord_prompt.dart';
import '../services/chord_generator.dart';

/// Result of a single prompt
class ChordPromptResult {
  final ChordPrompt prompt;
  final ChordType userAnswer;
  final bool isCorrect;

  const ChordPromptResult({
    required this.prompt,
    required this.userAnswer,
    required this.isCorrect,
  });
}

/// State management for the Chord Identification game
class ChordGameState extends ChangeNotifier {
  final AudioController _audio;
  final ChordGenerator _generator;
  final int totalPrompts;

  GameStatus _status = GameStatus.notStarted;
  List<ChordPrompt> _prompts = [];
  int _currentPromptIndex = 0;
  final List<ChordPromptResult> _results = [];
  int _consecutiveCorrect = 0;

  ChordGameState({
    AudioController? audio,
    ChordGenerator? generator,
    this.totalPrompts = 10,
  }) : _audio = audio ?? AudioController.instance,
       _generator = generator ?? ChordGenerator();

  // Getters
  GameStatus get status => _status;
  int get currentPromptIndex => _currentPromptIndex;
  int get correctCount => _results.where((r) => r.isCorrect).length;
  int get consecutiveCorrect => _consecutiveCorrect;
  List<ChordPromptResult> get results => List.unmodifiable(_results);
  bool get isGameComplete => _status == GameStatus.completed;

  ChordPrompt? get currentPrompt =>
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

  /// Play the current prompt's chord
  Future<void> _playCurrentPrompt() async {
    final prompt = currentPrompt;
    if (prompt == null) return;

    _status = GameStatus.playing;
    notifyListeners();

    // Play all chord notes simultaneously
    await _audio.playChord(prompt.chordNotes);

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
  void submitAnswer(ChordType answer) {
    if (_status != GameStatus.awaitingInput) return;

    final prompt = currentPrompt;
    if (prompt == null) return;

    final isCorrect = prompt.isCorrect(answer);

    // Record result
    _results.add(
      ChordPromptResult(
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
  ChordPromptResult? get lastResult =>
      _results.isNotEmpty ? _results.last : null;
}

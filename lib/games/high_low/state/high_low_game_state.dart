import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../audio/audio_controller.dart';
import '../../../audio/sfx_type.dart';
import '../../../models/game_status.dart';
import '../../../models/pitch_direction.dart';
import '../models/high_low_prompt.dart';
import '../services/prompt_generator.dart';

/// Result of a single prompt
class PromptResult {
  final HighLowPrompt prompt;
  final PitchDirection userAnswer;
  final bool isCorrect;

  const PromptResult({
    required this.prompt,
    required this.userAnswer,
    required this.isCorrect,
  });
}

/// State management for the High/Low game
class HighLowGameState extends ChangeNotifier {
  final AudioController _audio;
  final PromptGenerator _generator;
  final int totalPrompts;
  final int difficulty;

  GameStatus _status = GameStatus.notStarted;
  List<HighLowPrompt> _prompts = [];
  int _currentPromptIndex = 0;
  final List<PromptResult> _results = [];
  int _consecutiveCorrect = 0;

  /// Which note is currently sounding: 0 = first (left guitar), 1 = second
  /// (right guitar), null = nothing playing right now. UI uses this to
  /// glow the guitar that's currently making sound.
  int? _playingIndex;

  HighLowGameState({
    AudioController? audio,
    PromptGenerator? generator,
    this.totalPrompts = 5,
    this.difficulty = 1,
  }) : _audio = audio ?? AudioController.instance,
       _generator = generator ?? PromptGenerator();

  // Getters
  GameStatus get status => _status;
  int get currentPromptIndex => _currentPromptIndex;
  int get correctCount => _results.where((r) => r.isCorrect).length;
  int get consecutiveCorrect => _consecutiveCorrect;
  List<PromptResult> get results => List.unmodifiable(_results);
  bool get isGameComplete => _status == GameStatus.completed;
  int? get playingIndex => _playingIndex;

  HighLowPrompt? get currentPrompt =>
      _prompts.isNotEmpty && _currentPromptIndex < _prompts.length
      ? _prompts[_currentPromptIndex]
      : null;

  double get progress =>
      totalPrompts > 0 ? _currentPromptIndex / totalPrompts : 0;

  /// Start a new game
  void startGame() {
    _prompts = _generator.generatePrompts(
      count: totalPrompts,
      difficulty: difficulty,
    );
    _currentPromptIndex = 0;
    _results.clear();
    _consecutiveCorrect = 0;
    _status = GameStatus.playing;
    notifyListeners();

    // Play the first prompt
    _playCurrentPrompt();
  }

  /// Play the current prompt's notes
  Future<void> _playCurrentPrompt() async {
    final prompt = currentPrompt;
    if (prompt == null) return;

    _status = GameStatus.playing;
    _playingIndex = 0;
    notifyListeners();

    // Play first note (left guitar)
    await _audio.playNoteForScale(prompt.firstNote);

    // Wait between notes
    await Future.delayed(const Duration(milliseconds: 800));

    // Play second note (right guitar)
    _playingIndex = 1;
    notifyListeners();
    await _audio.playNoteForScale(prompt.secondNote);

    // Now awaiting input
    _playingIndex = null;
    _status = GameStatus.awaitingInput;
    notifyListeners();
  }

  /// Skip the current prompt without recording a right/wrong result.
  /// Replays nothing — just advances (or completes the game if this was
  /// the last prompt).
  void skipPrompt() {
    if (_status != GameStatus.awaitingInput) return;
    _audio.playSfx(SfxType.tap);

    if (_currentPromptIndex < totalPrompts - 1) {
      _nextPrompt();
    } else {
      _completeGame();
    }
  }

  /// Replay the current prompt
  Future<void> replayPrompt() async {
    if (_status != GameStatus.awaitingInput) return;
    await _playCurrentPrompt();
  }

  /// Submit an answer for the current prompt
  void submitAnswer(PitchDirection answer) {
    if (_status != GameStatus.awaitingInput) return;

    final prompt = currentPrompt;
    if (prompt == null) return;

    final isCorrect = prompt.isCorrect(answer);

    // Record result
    _results.add(
      PromptResult(prompt: prompt, userAnswer: answer, isCorrect: isCorrect),
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
  PromptResult? get lastResult => _results.isNotEmpty ? _results.last : null;
}

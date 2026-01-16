import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../audio/audio_controller.dart';
import '../../../audio/sfx_type.dart';
import '../../../models/game_status.dart';
import '../models/match_note_prompt.dart';
import '../services/match_note_generator.dart';

/// Result of a single prompt
class MatchNotePromptResult {
  final MatchNotePrompt prompt;
  final int userChoiceIndex;
  final bool isCorrect;

  const MatchNotePromptResult({
    required this.prompt,
    required this.userChoiceIndex,
    required this.isCorrect,
  });
}

/// State management for the Match the Note game
class MatchNoteGameState extends ChangeNotifier {
  final AudioController _audio;
  final MatchNoteGenerator _generator;
  final int totalPrompts;

  GameStatus _status = GameStatus.notStarted;
  List<MatchNotePrompt> _prompts = [];
  int _currentPromptIndex = 0;
  final List<MatchNotePromptResult> _results = [];
  int _consecutiveCorrect = 0;
  int? _selectedChoiceIndex;

  MatchNoteGameState({
    AudioController? audio,
    MatchNoteGenerator? generator,
    this.totalPrompts = 10,
  }) : _audio = audio ?? AudioController.instance,
       _generator = generator ?? MatchNoteGenerator();

  // Getters
  GameStatus get status => _status;
  int get currentPromptIndex => _currentPromptIndex;
  int get correctCount => _results.where((r) => r.isCorrect).length;
  int get consecutiveCorrect => _consecutiveCorrect;
  List<MatchNotePromptResult> get results => List.unmodifiable(_results);
  bool get isGameComplete => _status == GameStatus.completed;
  int? get selectedChoiceIndex => _selectedChoiceIndex;
  bool get hasSelection => _selectedChoiceIndex != null;

  MatchNotePrompt? get currentPrompt =>
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
    _selectedChoiceIndex = null;
    _status = GameStatus.playing;
    notifyListeners();

    // Play the first prompt's target note
    _playTargetNote();
  }

  /// Play the current prompt's target note
  Future<void> _playTargetNote() async {
    final prompt = currentPrompt;
    if (prompt == null) return;

    _status = GameStatus.playing;
    notifyListeners();

    await _audio.playNote(prompt.targetNote);

    // Now awaiting input
    _status = GameStatus.awaitingInput;
    _selectedChoiceIndex = null;
    notifyListeners();
  }

  /// Replay the target note
  Future<void> replayTarget() async {
    if (_status != GameStatus.awaitingInput) return;

    final prompt = currentPrompt;
    if (prompt == null) return;

    await _audio.playNote(prompt.targetNote);
  }

  /// Select a choice (plays the note and highlights it)
  Future<void> selectChoice(int index) async {
    if (_status != GameStatus.awaitingInput) return;

    final prompt = currentPrompt;
    if (prompt == null || index < 0 || index >= prompt.choiceCount) return;

    _selectedChoiceIndex = index;
    notifyListeners();

    // Play the selected choice's note
    await _audio.playNote(prompt.getChoice(index));
  }

  /// Submit the selected answer
  void submitAnswer() {
    if (_status != GameStatus.awaitingInput) return;
    if (_selectedChoiceIndex == null) return;

    final prompt = currentPrompt;
    if (prompt == null) return;

    final isCorrect = prompt.isCorrect(_selectedChoiceIndex!);

    // Record result
    _results.add(
      MatchNotePromptResult(
        prompt: prompt,
        userChoiceIndex: _selectedChoiceIndex!,
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
    _selectedChoiceIndex = null;
    _playTargetNote();
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
    _selectedChoiceIndex = null;
    notifyListeners();
  }

  /// Get the result of the last answered prompt
  MatchNotePromptResult? get lastResult =>
      _results.isNotEmpty ? _results.last : null;
}

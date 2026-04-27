import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../audio/audio_controller.dart';
import '../../../audio/sfx_type.dart';
import '../../../models/game_status.dart';
import '../../../models/solfege_note.dart';

class PitchNameResult {
  final SolfegeNote correct;
  final SolfegeNote selected;
  bool get isCorrect => correct.solfege == selected.solfege;
  const PitchNameResult({required this.correct, required this.selected});
}

class PitchNameGameState extends ChangeNotifier {
  final AudioController _audio;
  final int totalPrompts;
  final _rng = Random();

  GameStatus _status = GameStatus.notStarted;
  SolfegeNote? _currentNote;
  SolfegeNote? _selectedNote;
  List<SolfegeNote> _choices = [];
  int _currentPromptIndex = 0;
  final List<PitchNameResult> _results = [];
  bool _isDisposed = false;

  PitchNameGameState({AudioController? audio, this.totalPrompts = 5})
      : _audio = audio ?? AudioController.instance;

  GameStatus get status => _status;
  SolfegeNote? get currentNote => _currentNote;
  SolfegeNote? get selectedNote => _selectedNote;
  List<SolfegeNote> get choices => List.unmodifiable(_choices);
  int get currentPromptIndex => _currentPromptIndex;
  int get correctCount => _results.where((r) => r.isCorrect).length;
  List<PitchNameResult> get results => List.unmodifiable(_results);
  PitchNameResult? get lastResult => _results.isNotEmpty ? _results.last : null;

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
    final note = SolfegeNote.cMajorScale[_rng.nextInt(SolfegeNote.cMajorScale.length)];
    _currentNote = note;
    _selectedNote = null;

    // Correct answer + 3 random distractors
    final others = SolfegeNote.cMajorScale
        .where((n) => n.solfege != note.solfege)
        .toList()
      ..shuffle(_rng);
    _choices = [note, ...others.take(3)]..shuffle(_rng);

    _status = GameStatus.playing;
    _safeNotify();

    await _audio.playNote(note.note);
    if (_isDisposed) return;

    // Give the note time to sound before buttons appear
    await Future.delayed(const Duration(milliseconds: 1000));
    if (_isDisposed) return;

    _status = GameStatus.awaitingInput;
    _safeNotify();
  }

  Future<void> replay() async {
    if (_status != GameStatus.awaitingInput || _currentNote == null || _isDisposed) return;
    await _audio.playNote(_currentNote!.note);
  }

  void submitAnswer(SolfegeNote selected) {
    if (_status != GameStatus.awaitingInput || _currentNote == null || _isDisposed) return;

    _selectedNote = selected;
    _results.add(PitchNameResult(correct: _currentNote!, selected: selected));

    if (selected.solfege == _currentNote!.solfege) {
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

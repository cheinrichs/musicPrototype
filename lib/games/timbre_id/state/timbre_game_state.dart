import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../audio/audio_controller.dart';
import '../../../audio/sfx_type.dart';
import '../../../models/game_status.dart';
import '../../../models/instrument.dart';

const List<Instrument> timbrePool = [
  Instrument.guitar,
  Instrument.drums,
  Instrument.trumpet,
  Instrument.violin,
];

class TimbreResult {
  final Instrument correct;
  final Instrument selected;
  bool get isCorrect => correct == selected;
  const TimbreResult({required this.correct, required this.selected});
}

class TimbreGameState extends ChangeNotifier {
  final AudioController _audio;
  final int totalPrompts;
  final _rng = Random();

  GameStatus _status = GameStatus.notStarted;
  Instrument? _currentInstrument;
  String? _currentAssetPath;
  Instrument? _selectedInstrument;
  int _currentPromptIndex = 0;
  final List<TimbreResult> _results = [];
  bool _isDisposed = false;

  TimbreGameState({AudioController? audio, this.totalPrompts = 5})
      : _audio = audio ?? AudioController.instance;

  GameStatus get status => _status;
  Instrument? get currentInstrument => _currentInstrument;
  Instrument? get selectedInstrument => _selectedInstrument;
  int get currentPromptIndex => _currentPromptIndex;
  int get correctCount => _results.where((r) => r.isCorrect).length;
  List<TimbreResult> get results => List.unmodifiable(_results);
  TimbreResult? get lastResult => _results.isNotEmpty ? _results.last : null;

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
    _selectedInstrument = null;
    _status = GameStatus.playing;
    _safeNotify();
    _playCurrentPrompt();
  }

  Future<void> _playCurrentPrompt() async {
    final instrument = timbrePool[_rng.nextInt(timbrePool.length)];
    _currentInstrument = instrument;
    _currentAssetPath = instrument.randomAssetPath;
    _selectedInstrument = null;
    _status = GameStatus.playing;
    _safeNotify();

    await _audio.playClipAndAwait(_currentAssetPath!);

    if (_isDisposed) return;
    _status = GameStatus.awaitingInput;
    _safeNotify();
  }

  Future<void> replay() async {
    if (_status != GameStatus.awaitingInput || _currentAssetPath == null || _isDisposed) return;
    _status = GameStatus.playing;
    _safeNotify();
    await _audio.playClipAndAwait(_currentAssetPath!);
    if (_isDisposed) return;
    _status = GameStatus.awaitingInput;
    _safeNotify();
  }

  void submitAnswer(Instrument selected) {
    if (_status != GameStatus.awaitingInput || _currentInstrument == null || _isDisposed) return;

    _selectedInstrument = selected;
    _results.add(TimbreResult(correct: _currentInstrument!, selected: selected));

    if (selected == _currentInstrument!) {
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

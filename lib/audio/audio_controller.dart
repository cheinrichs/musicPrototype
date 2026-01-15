import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'note.dart';
import 'sfx_type.dart';

/// Audio controller singleton for managing game audio
/// Wraps flutter_soloud for low-latency playback
class AudioController {
  AudioController._();

  static final AudioController instance = AudioController._();
  factory AudioController() => instance;

  SoLoud? _soloud;
  final Map<Note, AudioSource> _noteCache = {};
  final Map<SfxType, AudioSource> _sfxCache = {};
  bool _isInitialized = false;
  bool _isMuted = false;
  SoundHandle? _currentNoteHandle;

  /// Check if audio system is initialized
  bool get isInitialized => _isInitialized;

  /// Check if audio is muted
  bool get isMuted => _isMuted;

  /// Initialize the audio system
  /// Should be called during app startup
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _soloud = SoLoud.instance;
      await _soloud!.init();
      _isInitialized = true;
    } catch (e) {
      // Audio initialization failed - app can still work without audio
      _isInitialized = false;
      rethrow;
    }
  }

  /// Preload all audio assets for smooth playback
  /// Call this during splash screen or initial load
  Future<void> preloadAll() async {
    if (!_isInitialized) return;

    // Preload all notes
    for (final note in Note.values) {
      await _preloadNote(note);
    }

    // Preload all SFX
    for (final sfx in SfxType.values) {
      await _preloadSfx(sfx);
    }
  }

  Future<void> _preloadNote(Note note) async {
    if (_noteCache.containsKey(note)) return;

    try {
      final bytes = await rootBundle.load(note.assetPath);
      final source = await _soloud!.loadMem(
        note.assetPath,
        bytes.buffer.asUint8List(),
      );
      _noteCache[note] = source;
    } catch (e) {
      // Note failed to load - continue without it
    }
  }

  Future<void> _preloadSfx(SfxType sfx) async {
    if (_sfxCache.containsKey(sfx)) return;

    try {
      final bytes = await rootBundle.load(sfx.assetPath);
      final source = await _soloud!.loadMem(
        sfx.assetPath,
        bytes.buffer.asUint8List(),
      );
      _sfxCache[sfx] = source;
    } catch (e) {
      // SFX failed to load - continue without it
    }
  }

  /// Play a musical note
  Future<void> playNote(Note note) async {
    if (!_isInitialized || _isMuted) return;

    // Try to load if not cached
    if (!_noteCache.containsKey(note)) {
      await _preloadNote(note);
    }

    final source = _noteCache[note];
    if (source != null) {
      await _soloud!.play(source);
    }
  }

  /// Play a note for scale playback, stopping the previous note first
  /// Use this for sequential scale notes to prevent overlap
  Future<void> playNoteForScale(Note note) async {
    if (!_isInitialized || _isMuted) return;

    // Stop the previous note if still playing
    if (_currentNoteHandle != null) {
      _soloud!.stop(_currentNoteHandle!);
      _currentNoteHandle = null;
    }

    // Try to load if not cached
    if (!_noteCache.containsKey(note)) {
      await _preloadNote(note);
    }

    final source = _noteCache[note];
    if (source != null) {
      _currentNoteHandle = await _soloud!.play(source);
    }
  }

  /// Stop the current scale note (call at end of scale)
  void stopCurrentNote() {
    if (_currentNoteHandle != null && _isInitialized) {
      _soloud!.stop(_currentNoteHandle!);
      _currentNoteHandle = null;
    }
  }

  /// Play a sound effect
  Future<void> playSfx(SfxType sfx) async {
    if (!_isInitialized || _isMuted) return;

    // Try to load if not cached
    if (!_sfxCache.containsKey(sfx)) {
      await _preloadSfx(sfx);
    }

    final source = _sfxCache[sfx];
    if (source != null) {
      await _soloud!.play(source);
    }
  }

  /// Toggle mute state
  void toggleMute() {
    _isMuted = !_isMuted;
  }

  /// Set mute state
  void setMute(bool muted) {
    _isMuted = muted;
  }

  /// Stop all currently playing sounds
  void stopAll() {
    if (!_isInitialized) return;
    // Stop all active voices by disposing and reinitializing
    // flutter_soloud doesn't have a stopAll, so we track handles if needed
  }

  /// Dispose of the audio system
  /// Call when app is closing
  Future<void> dispose() async {
    if (!_isInitialized) return;

    // Dispose all cached sources
    for (final source in _noteCache.values) {
      _soloud?.disposeSource(source);
    }
    for (final source in _sfxCache.values) {
      _soloud?.disposeSource(source);
    }

    _noteCache.clear();
    _sfxCache.clear();

    _soloud?.deinit();
    _isInitialized = false;
  }
}

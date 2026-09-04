import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'audio_session.dart';
import 'note.dart';
import 'sfx_type.dart';
import 'voice_line.dart';

/// Audio controller singleton for managing game audio
/// Wraps flutter_soloud for low-latency playback
class AudioController {
  AudioController._();

  static final AudioController instance = AudioController._();
  factory AudioController() => instance;

  SoLoud? _soloud;
  // Keyed by asset path rather than by Note, since High/Low plays notes by
  // real MIDI pitch through its own per-instrument asset paths (see
  // HighLowInstrument.assetPathForMidi) rather than through Note.assetPath.
  final Map<String, AudioSource> _noteCache = {};
  final Map<SfxType, AudioSource> _sfxCache = {};
  final Map<String, AudioSource> _clipCache = {};
  bool _isInitialized = false;
  bool _isMuted = false;
  SoundHandle? _currentNoteHandle;
  SoundHandle? _currentClipHandle;
  AppLifecycleListener? _lifecycleListener;

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

      // Opt out of the iOS ring/silent switch. This has to happen *after*
      // the engine starts: flutter_soloud configures the shared
      // AVAudioSession while it spins up its device, so a category set
      // before this point can be overwritten. No-op off iOS.
      await AudioSession.configureForPlayback();
      _registerLifecycleListener();

      _isInitialized = true;
    } catch (e) {
      // Audio initialization failed - app can still work without audio
      _isInitialized = false;
      rethrow;
    }
  }

  /// Re-assert the playback audio session when the app comes back to the
  /// foreground — an interruption (phone call, Siri, another audio app) can
  /// leave the session deactivated behind us.
  void _registerLifecycleListener() {
    _lifecycleListener ??= AppLifecycleListener(
      onResume: () {
        unawaited(AudioSession.configureForPlayback());
      },
    );
  }

  /// Preload all audio assets for smooth playback
  /// Call this during splash screen or initial load
  ///
  /// [highLowAssetPaths] lets callers hand in every High/Low instrument's
  /// note asset paths (`HighLowInstrument.values.expand((i) =>
  /// i.allAssetPaths)`) so the first round doesn't pay a decode cost inline
  /// the first time a given instrument is picked. Optional and defaults to
  /// none, so callers that don't touch High/Low (and tests) don't need to
  /// know about it — kept as a parameter here rather than an import of
  /// `HighLowInstrument`, since this file is generic audio infrastructure
  /// and High/Low is one feature among the games that use it.
  Future<void> preloadAll({List<String> highLowAssetPaths = const []}) async {
    if (!_isInitialized) return;

    // Preload all notes
    for (final note in Note.values) {
      await _preloadNote(note);
    }

    for (final path in highLowAssetPaths) {
      await _preloadAssetPath(path);
    }

    // Preload all SFX
    for (final sfx in SfxType.values) {
      await _preloadSfx(sfx);
    }
  }

  Future<void> _preloadNote(Note note) => _preloadAssetPath(note.assetPath());

  Future<void> _preloadAssetPath(String path) async {
    if (_noteCache.containsKey(path)) return;

    try {
      final bytes = await rootBundle.load(path);
      final source = await _soloud!.loadMem(path, bytes.buffer.asUint8List());
      _noteCache[path] = source;
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

  /// Play a musical note (the shared, instrument-agnostic tone).
  Future<void> playNote(Note note) async {
    if (!_isInitialized || _isMuted) return;

    final path = note.assetPath();
    if (!_noteCache.containsKey(path)) {
      await _preloadNote(note);
    }

    final source = _noteCache[path];
    if (source != null) {
      await _soloud!.play(source);
    }
  }

  /// Play a note for scale playback, stopping the previous note first.
  /// Use this for sequential scale notes to prevent overlap.
  Future<void> playNoteForScale(Note note) =>
      playAssetForScale(note.assetPath());

  /// Same as [playNoteForScale] but for a raw asset path rather than a
  /// [Note] — High/Low plays its own instruments' notes by real MIDI pitch
  /// through `HighLowInstrument.assetPathForMidi` instead of through
  /// [Note], since an instrument's real range isn't always this enum's
  /// fixed C4-B5 (see [Note.assetPath]'s doc comment).
  Future<void> playAssetForScale(String path) async {
    if (!_isInitialized || _isMuted) return;

    // Stop the previous note if still playing. Awaited so the engine has
    // actually freed the voice before we request a new one below, instead
    // of racing the stop against the next play call.
    if (_currentNoteHandle != null) {
      await _soloud!.stop(_currentNoteHandle!);
      _currentNoteHandle = null;
    }

    if (!_noteCache.containsKey(path)) {
      await _preloadAssetPath(path);
    }

    final source = _noteCache[path];
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

  /// Play multiple notes simultaneously (for chords)
  Future<void> playChord(List<Note> notes) async {
    if (!_isInitialized || _isMuted) return;

    for (final note in notes) {
      final path = note.assetPath();
      // Try to load if not cached
      if (!_noteCache.containsKey(path)) {
        await _preloadNote(note);
      }

      final source = _noteCache[path];
      if (source != null) {
        // Play without awaiting - allows simultaneous playback
        _soloud!.play(source);
      }
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

  /// Preload a list of audio clip asset paths (e.g., playground melodies)
  Future<void> preloadClips(List<String> assetPaths) async {
    if (!_isInitialized) return;
    for (final path in assetPaths) {
      await _preloadClip(path);
    }
  }

  Future<void> _preloadClip(String assetPath) async {
    if (_clipCache.containsKey(assetPath)) return;
    try {
      final bytes = await rootBundle.load(assetPath);
      final source = await _soloud!.loadMem(
        assetPath,
        bytes.buffer.asUint8List(),
      );
      _clipCache[assetPath] = source;
    } catch (e) {
      // Clip not found — playground is silent for this instrument until added
    }
  }

  /// Play a clip by asset path, stopping any currently playing clip first
  Future<void> playClip(String assetPath) async {
    if (!_isInitialized || _isMuted) return;

    if (_currentClipHandle != null) {
      _soloud!.stop(_currentClipHandle!);
      _currentClipHandle = null;
    }

    if (!_clipCache.containsKey(assetPath)) {
      await _preloadClip(assetPath);
    }

    final source = _clipCache[assetPath];
    if (source != null) {
      _currentClipHandle = await _soloud!.play(source);
    }
  }

  /// Play a clip and await its natural completion before returning.
  /// Falls back to a 3-second delay when muted or uninitialized.
  Future<void> playClipAndAwait(String assetPath) async {
    if (!_isInitialized || _isMuted) {
      await Future.delayed(const Duration(seconds: 3));
      return;
    }

    if (_currentClipHandle != null) {
      _soloud!.stop(_currentClipHandle!);
      _currentClipHandle = null;
    }

    if (!_clipCache.containsKey(assetPath)) {
      await _preloadClip(assetPath);
    }

    final source = _clipCache[assetPath];
    if (source == null) {
      await Future.delayed(const Duration(seconds: 3));
      return;
    }

    final handle = await _soloud!.play(source);
    _currentClipHandle = handle;

    while (_soloud!.getIsValidVoiceHandle(handle)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (_currentClipHandle == handle) _currentClipHandle = null;
  }

  /// Play a spoken line (Trello card 91/93). The recordings don't exist
  /// yet, so this shares the clip cache/loader used for playground
  /// melodies, which already no-ops silently when an asset is missing —
  /// callers pair this with an on-screen caption (see [VoiceLine]) so the
  /// moment still reads without audio.
  Future<void> playVoiceLine(VoiceLine line) => playClip(line.assetPath);

  /// Play a spoken line and await its natural completion, so the caller can
  /// sequence something after it finishes speaking (Trello card KOuemvVs —
  /// a round's intro line was getting cut off by the notes starting over
  /// it). Deliberately doesn't share [playClipAndAwait]'s synthetic
  /// 3-second fallback for the uninitialized/muted case: that stand-in
  /// exists so a silent Sound Playground melody still "takes" roughly as
  /// long as the real clip would, but here it would just be dead air
  /// wedged in front of the notes (and would break tests that pump a
  /// fixed, much shorter duration), so this returns immediately instead
  /// when there's nothing to actually wait for.
  Future<void> playVoiceLineAndAwait(VoiceLine line) async {
    if (!_isInitialized || _isMuted) return;

    if (_currentClipHandle != null) {
      _soloud!.stop(_currentClipHandle!);
      _currentClipHandle = null;
    }

    final assetPath = line.assetPath;
    if (!_clipCache.containsKey(assetPath)) {
      await _preloadClip(assetPath);
    }

    final source = _clipCache[assetPath];
    if (source == null) return;

    final handle = await _soloud!.play(source);
    _currentClipHandle = handle;

    while (_soloud!.getIsValidVoiceHandle(handle)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (_currentClipHandle == handle) _currentClipHandle = null;
  }

  /// Stop the currently playing clip
  void stopCurrentClip() {
    if (_currentClipHandle != null && _isInitialized) {
      _soloud!.stop(_currentClipHandle!);
      _currentClipHandle = null;
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

    _lifecycleListener?.dispose();
    _lifecycleListener = null;

    // Dispose all cached sources
    for (final source in _noteCache.values) {
      _soloud?.disposeSource(source);
    }
    for (final source in _sfxCache.values) {
      _soloud?.disposeSource(source);
    }
    for (final source in _clipCache.values) {
      _soloud?.disposeSource(source);
    }

    _noteCache.clear();
    _sfxCache.clear();
    _clipCache.clear();

    _soloud?.deinit();
    _isInitialized = false;
  }
}

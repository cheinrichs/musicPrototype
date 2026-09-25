import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A coarse loudness curve for one voice line, computed at build time by
/// `tool/build_voice_envelopes.py` and shipped as JSON (see
/// [VoiceEnvelopeLibrary]) — never computed on-device. Drives the
/// speaking indicator's mouth/scale cues on the rhythm of the actual
/// speech, rather than a flat loop (Cooper rejected a looping bob and a
/// looping sway for exactly that reason: steady repeating motion reads as
/// a state the character is in, not as talking).
///
/// [samples] are RMS loudness per [hopMs] block, each normalized 0-1
/// against that clip's own peak block.
@immutable
class VoiceEnvelope {
  final int hopMs;
  final List<double> samples;

  const VoiceEnvelope({required this.hopMs, required this.samples});

  factory VoiceEnvelope.fromJson(int hopMs, List<dynamic> json) =>
      VoiceEnvelope(
        hopMs: hopMs,
        samples: [for (final v in json) (v as num).toDouble()],
      );

  Duration get duration => Duration(milliseconds: hopMs * samples.length);

  /// Linearly interpolated amplitude at [elapsed] time since the line
  /// started speaking. 0 before the line starts and once playback has run
  /// past the last sample — a caller still driving this after the line
  /// should have finished (state moved on already, or the on-device
  /// decoder's real duration drifted slightly from what this was built
  /// from) settles to silence rather than holding the last loud moment.
  double amplitudeAt(Duration elapsed) {
    if (samples.isEmpty || elapsed.isNegative) return 0;
    final posInHops = elapsed.inMicroseconds / (hopMs * 1000);
    if (posInHops >= samples.length - 1) {
      return posInHops <= samples.length ? samples.last : 0;
    }
    final i = posInHops.floor();
    final frac = posInHops - i;
    return samples[i] + (samples[i + 1] - samples[i]) * frac;
  }
}

/// Loads `assets/audio/voice/envelopes.json` (produced by
/// `tool/build_voice_envelopes.py`) once and caches every line's
/// [VoiceEnvelope] by its asset name (`VoiceLine.name`, not the enum type
/// itself — keeps this file audio-content-agnostic and independent of
/// where `VoiceLine` lives). A line missing from the manifest (not yet
/// recorded, or added since the manifest was last regenerated) simply has
/// no entry; callers fall back to a flat cue rather than crashing.
class VoiceEnvelopeLibrary {
  static const String assetPath = 'assets/audio/voice/envelopes.json';

  static Map<String, VoiceEnvelope>? _cache;
  static Future<Map<String, VoiceEnvelope>>? _loading;

  /// Load the manifest ahead of time — call during app startup, alongside
  /// `AudioController.preloadAll`, so [envelopeForSync] has data the first
  /// time a character speaks instead of racing the first lookup.
  static Future<void> preload() async {
    await (_loading ??= _load());
  }

  static Future<Map<String, VoiceEnvelope>> _load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final hopMs = json['hopMs'] as int;
      final lines = json['lines'] as Map<String, dynamic>;
      return _cache = {
        for (final entry in lines.entries)
          entry.key: VoiceEnvelope.fromJson(hopMs, entry.value as List),
      };
    } catch (_) {
      // Missing manifest (a fresh checkout that hasn't run the build
      // script, or a test environment without the asset) — every lookup
      // just falls back, same as a line with no entry.
      return _cache = const {};
    }
  }

  /// Synchronous lookup for use inside a build method. Returns null both
  /// when [lineName] has no envelope and when [preload] hasn't resolved
  /// yet — callers must already have a non-envelope fallback for "no data
  /// yet" regardless, so there's no separate "still loading" state to
  /// plumb through.
  static VoiceEnvelope? envelopeForSync(String lineName) => _cache?[lineName];

  /// Test-only: inject (or clear, with null) the cache directly, without
  /// touching the asset bundle.
  @visibleForTesting
  static void debugSetCache(Map<String, VoiceEnvelope>? cache) {
    _cache = cache;
    _loading = null;
  }
}

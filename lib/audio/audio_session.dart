import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS audio session configuration.
///
/// iOS hands every app the `soloAmbient` audio session category by default,
/// and that category is silenced by the physical ring/silent switch. Apps
/// whose whole point is sound (music players, games, this ear trainer) opt
/// out by asking for the `playback` category instead, which Apple documents
/// as *not* silenced by the Ring/Silent switch.
///
/// flutter_soloud (miniaudio under the hood) doesn't expose the session
/// category, so we set it ourselves over a method channel handled in
/// ios/Runner/AppDelegate.swift.
///
/// Every method here is a no-op off iOS — Android and the desktop/web
/// targets have no equivalent switch, so there is nothing to configure.
class AudioSession {
  AudioSession._();

  static const MethodChannel _channel = MethodChannel(
    'ear_trainer/audio_session',
  );

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Ask iOS for a `playback` audio session so the app stays audible with
  /// the ring/silent switch set to silent.
  ///
  /// Call this *after* the audio engine has started, so that whatever the
  /// engine configured on the shared session doesn't overwrite us, and again
  /// on app resume, since an interruption (a phone call, Siri) can leave the
  /// session deactivated.
  ///
  /// Returns true when the session was configured, false on failure or on a
  /// platform where this doesn't apply.
  static Future<bool> configureForPlayback() async {
    if (!_isIOS) return false;
    try {
      final configured = await _channel.invokeMethod<bool>(
        'configureForPlayback',
      );
      return configured ?? false;
    } on PlatformException catch (e) {
      debugPrint('AVAudioSession configuration failed: ${e.message}');
      return false;
    } on MissingPluginException {
      // Running against a build without the native handler (e.g. a widget
      // test) — audio still works, it just respects the silent switch.
      return false;
    }
  }
}

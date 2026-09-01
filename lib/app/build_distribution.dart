import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Which distribution channel installed this exact binary.
///
/// TestFlight and the App Store ship the same signed archive, so nothing
/// about the build itself (release vs. debug, a compile-time dart-define)
/// can tell them apart at build time — see lib/app/config.dart's
/// `devToolsEnabled`. Only a runtime check of the install can, over a
/// method channel handled in ios/Runner/AppDelegate.swift.
class BuildDistribution {
  BuildDistribution._();

  static const MethodChannel _channel = MethodChannel('ear_trainer/build_info');

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// True when this install is *not* a genuine public App Store release
  /// (i.e. it's TestFlight, or a local Xcode/debug run).
  ///
  /// Fails closed: any platform without the native check (non-iOS, or a
  /// build without the handler, e.g. a widget test) reports false, so
  /// developer-only tools default to hidden rather than risk being shown
  /// in a shipped build we can't positively identify as internal.
  static Future<bool> isInternalDistribution() async {
    if (!_isIOS) return false;
    try {
      final internal = await _channel.invokeMethod<bool>(
        'isInternalDistribution',
      );
      return internal ?? false;
    } on PlatformException catch (e) {
      debugPrint('Build-distribution check failed: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

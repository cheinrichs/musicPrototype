import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/app/config.dart';

void main() {
  // flutter test always runs in a debug-like environment, so kDebugMode is
  // true here — resolveDevToolsEnabled should short-circuit on that alone
  // and never need to reach the (unavailable in a plain test) native
  // build_info channel. This is the same branch a local `flutter run`
  // (debug, no dart-define) now takes.
  test('resolves to true under a debug build without reaching the native channel', () async {
    expect(kDebugMode, isTrue);
    devToolsEnabled = false;

    await resolveDevToolsEnabled();

    expect(devToolsEnabled, isTrue);
  });
}

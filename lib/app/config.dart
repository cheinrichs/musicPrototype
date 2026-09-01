import 'package:flutter/foundation.dart';
import 'build_distribution.dart';

/// Compile-time override: pass --dart-define=DEV_MODE=true (e.g. via `make
/// run-ios-dev`) to force developer-only UI on regardless of how the build
/// was installed. Never set by CI (see .github/workflows/deploy.yml) — the
/// TestFlight/App Store distinction is handled at runtime instead, by
/// [resolveDevToolsEnabled].
const bool kForceDevMode = bool.fromEnvironment('DEV_MODE', defaultValue: false);

/// Whether developer-only UI (the agency/tier/round-order gate, "Report
/// this round") is shown: the skill profile's seed/reset buttons, the
/// High/Low pre-game dev gate, and anything else gated the same way.
///
/// This used to be a compile-time constant gated on [kForceDevMode] alone,
/// which meant it was false in *every* build that goes through CI —
/// including the release build TestFlight ships, since CI never passes
/// `--dart-define=DEV_MODE=true` (and must not: that same archive can be
/// promoted straight to the public App Store, so anything CI bakes in as
/// "on" would ship to children too). TestFlight and the App Store hand out
/// the same signed binary, so "debug vs. release" was never the right
/// distinction — "internal vs. public" is, and only a runtime check of how
/// the app was actually installed can tell those apart (see
/// [BuildDistribution]).
///
/// Mutable, resolved once during app bootstrap (see main.dart) by
/// [resolveDevToolsEnabled], *before* [runApp] — every read of this flag
/// happens after that resolution completes, including field initializers
/// like `bool _showDevGate = devToolsEnabled` that run synchronously at
/// widget-construction time.
bool devToolsEnabled = false;

/// Resolves [devToolsEnabled]. Call once, and await it, before [runApp].
///
/// - [kForceDevMode] or a plain debug build (`flutter run`, no release
///   flag): always on, no native call needed.
/// - Otherwise: on only for a genuinely internal install (TestFlight, or a
///   release build run straight from Xcode) — off for the public App
///   Store, which is what makes this safe to ship at all.
Future<void> resolveDevToolsEnabled() async {
  if (kForceDevMode || kDebugMode) {
    devToolsEnabled = true;
    return;
  }
  devToolsEnabled = await BuildDistribution.isInternalDistribution();
}

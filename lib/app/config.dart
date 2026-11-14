import 'package:flutter/foundation.dart';
import 'build_distribution.dart';

/// Compile-time override: pass --dart-define=DEV_MODE=true (e.g. via `make
/// run-ios-dev`) to force developer-only UI on regardless of how the build
/// was installed. Never set by CI (see .github/workflows/deploy.yml) — the
/// TestFlight/App Store distinction is handled at runtime instead, by
/// [resolveDevToolsEnabled].
const bool kForceDevMode = bool.fromEnvironment(
  'DEV_MODE',
  defaultValue: false,
);

/// Compile-time: an INTERNAL build — TestFlight (CI passes
/// --dart-define=INTERNAL_BUILD=true) or a developer's own run. Without it,
/// the build is RELEASE-FLAVOURED.
///
/// ⚠️ The standing rule (docs/product/STANDING_RULES.md, Builds): the dev
/// profile is COMPILED OUT of a release build entirely, not merely gated.
/// Every reference to it sits behind [kDevProfileCompiledIn], a const, so
/// in a release-flavoured build that code is dead and the compiler drops it
/// — there is nothing left to reach, whatever the runtime says.
///
/// ⚠️ This means a TestFlight archive (built WITH the flag) must never be
/// promoted to the App Store: the public build is its own build, made
/// without it.
const bool kInternalBuild = bool.fromEnvironment('INTERNAL_BUILD');

/// Whether this binary contains the dev profile at all: an internal build,
/// a forced dev build, or a debug run. A const, so a release-flavoured
/// build drops everything guarded by it.
const bool kDevProfileCompiledIn =
    kInternalBuild || kForceDevMode || kDebugMode;

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
  // A release-flavoured binary has no dev tools whoever installed it.
  if (!kDevProfileCompiledIn) {
    devToolsEnabled = false;
    return;
  }
  if (kForceDevMode || kDebugMode) {
    devToolsEnabled = true;
    return;
  }
  devToolsEnabled = await BuildDistribution.isInternalDistribution();
}

/// Compile-time configuration flags.
/// Pass --dart-define=DEV_MODE=true (e.g. via `make run-ios-dev`) to enable
/// developer-only UI like the skill profile seed/reset buttons.
const bool kDevMode = bool.fromEnvironment('DEV_MODE', defaultValue: false);

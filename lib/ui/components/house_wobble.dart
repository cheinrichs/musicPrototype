import 'dart:math' as math;

/// The app's one wobble: a damped oscillation, two and a half swings
/// decaying to rest. The dial needle wobbles with it on arrival, and map
/// decorations react with it, so the world moves the same way everywhere
/// (STANDING_RULES.md: reuse the established feel rather than authoring a
/// new one).
abstract final class HouseWobble {
  /// Swings over the whole wobble.
  static const double cycles = 2.5;

  /// The wobble's displacement at [w] (0 to 1 through it), as a share of
  /// its amplitude: starts and ends at rest.
  static double at(double w) {
    if (w <= 0 || w >= 1) return 0;
    return math.sin(2 * math.pi * cycles * w) * math.pow(1 - w, 2);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A wrongly-dropped instrument's return to its stump — the whole "not that
/// one" gesture, as a single motion.
///
/// The child starts [from] (where the drop released it, relative to its
/// resting place) and springs back home with an elastic overshoot, so the
/// wobble *is* the settling: it ends exactly when the instrument does,
/// rather than being a return followed by a separate shake, which reads as
/// a reprimand. The spring is the only motion — there is no second shake
/// layered on top.
///
/// Runs for a fixed [duration] and stops, however long it stays mounted. It
/// deliberately does *not* track the retry voice line's length: this is a
/// feedback gesture, not a speaking indicator, so it has its own natural
/// length regardless of what's said over it (tying it to clip length would
/// also time differently for every line in a future nudge pool, which would
/// read as arbitrary).
class RetrySettle extends StatelessWidget {
  static const Duration duration = Duration(milliseconds: 700);

  /// Where the drop released the instrument, as an offset from its stump.
  /// [Offset.zero] (release point unknown) just means no travel.
  final Offset from;
  final Widget child;

  const RetrySettle({super.key, required this.from, required this.child});

  @override
  Widget build(BuildContext context) {
    return child.animate().move(
      begin: from,
      end: Offset.zero,
      duration: duration,
      curve: Curves.elasticOut,
    );
  }
}

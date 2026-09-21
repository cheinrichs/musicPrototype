import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The brief side-to-side wobble on a wrongly-dropped instrument — a "not
/// that one" gesture, never a verdict.
///
/// Runs for a fixed [duration] once and stops, however long it stays
/// mounted. It deliberately does *not* track the retry voice line's length:
/// this is a feedback gesture, not a speaking indicator, so it has its own
/// natural length regardless of what's said over it (a shake tied to clip
/// length would also time differently for every line in a future nudge
/// pool, which would read as arbitrary). Kept short on purpose too — the
/// longer a shake runs the more it reads as disapproval instead of a nudge.
class RetryShake extends StatelessWidget {
  static const Duration duration = Duration(milliseconds: 700);

  final Widget child;

  const RetryShake({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child.animate().shake(
      hz: 3,
      offset: const Offset(6, 0),
      duration: duration,
    );
  }
}

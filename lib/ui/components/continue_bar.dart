import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/theme.dart';

/// The child's earned way on (Trello card 209): a wide, low bar with one
/// arrow centred in it, **in the same place in every game**.
///
/// - **The shape is the point.** A bar is far easier for a three-year-old to
///   hit than the 72 px circle it replaces. No text; a darker bottom edge
///   says it can be pressed.
/// - **One fixed position, owned here** — [rectFor], centred in the safe area
///   along the bottom, under the stumps. A non-reader learns "the way on is
///   always there" from position alone, which only works if no game puts it
///   anywhere else. Every game places it with [rectFor] rather than its own
///   layout.
/// - **Sized for landscape**: the reference was a portrait phone where the
///   bar spans most of the width; across a landscape scene that would cut
///   the meadow in half, so it is [widthShare] of the safe width.
/// - **A cool colour, deliberately** — the design kit's own blue action, not
///   the reference's blue. Everything else in these scenes is warm, and in
///   Loud or Quiet orange IS the loud end of the dial: the old burnt-orange
///   circle read as part of the scale. Blue sits outside that ramp, and
///   outside red, which reads as wrong to a child.
/// - It **pops in once when earned, then holds still** — idle motion would
///   muddy what motion means here (a character speaking).
class ContinueBar extends StatelessWidget {
  final VoidCallback onTap;

  const ContinueBar({super.key, required this.onTap});

  /// The bar's share of the safe area's width.
  static const double widthShare = 0.45;

  /// The bar's height, lip included: a generous, easy target.
  static const double height = 52;

  /// The darker bottom edge that makes it read as pressable.
  static const double lip = 5;

  /// Space between the bar and the bottom of the screen (or the home
  /// indicator's inset, whichever is larger).
  static const double bottomGap = 8;

  /// Where the bar goes on a [screen] with [insets]: centred in the safe area,
  /// along the bottom.
  static Rect rectFor(Size screen, EdgeInsets insets) {
    final safeLeft = insets.left;
    final safeWidth = screen.width - insets.left - insets.right;
    final w = safeWidth * widthShare;
    final bottom = screen.height - math.max(insets.bottom, bottomGap);
    return Rect.fromLTWH(
      safeLeft + (safeWidth - w) / 2,
      bottom - height,
      w,
      height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return Tooltip(
      message: 'Tap when ready',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child:
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.buttonBlueShadow,
                borderRadius: radius,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: lip),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonBlueGradient,
                    borderRadius: radius,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ).animate().scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1, 1),
              duration: AppAnimations.medium,
              curve: Curves.elasticOut,
            ),
      ),
    );
  }
}

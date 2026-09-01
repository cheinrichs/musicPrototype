import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/theme.dart';

/// Visual progress indicator showing dots for each prompt.
///
/// Restyled as the Lumi "pill stepper" (`.c-stepper` in
/// SongStone-UI-Kit/UI/kit.css): a parchment pill housing a row of dots
/// that are muted sage when upcoming, gold and enlarged when current, and
/// filled gold once done. Deliberately doesn't distinguish a missed round
/// from a correct one — it used to turn a completed dot rose/red for a
/// wrong answer, which is a per-round failure state the design forbids at
/// low agency levels, and in practice let one child point out to another
/// that they'd gotten one wrong. This is a progress indicator, not a
/// scoreboard: it shows how far through the stage the child is, nothing
/// about how they did.
class ProgressDots extends StatelessWidget {
  final int totalDots;
  final int currentIndex;

  /// How many rounds have been completed so far — drives which dots show
  /// as "done" (gold) versus upcoming (sage). Not what the round's answer
  /// was; see the class doc for why.
  final int completedCount;

  const ProgressDots({
    super.key,
    required this.totalDots,
    required this.currentIndex,
    this.completedCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
        border: Border.all(color: AppColors.cardEdge, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(totalDots, (index) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.progressDotSpacing / 2,
            ),
            child: _buildDot(index),
          );
        }),
      ),
    );
  }

  Widget _buildDot(int index) {
    final isCompleted = index < completedCount;
    final isCurrent = index == currentIndex;

    Color fill;
    Color border;
    double size = 15;

    if (isCompleted) {
      fill = AppColors.gold;
      border = AppColors.goldDeep;
    } else if (isCurrent) {
      fill = AppColors.gold;
      border = AppColors.goldDeep;
      size = 19;
    } else {
      fill = const Color(0xFFB9C7A4);
      border = AppColors.sage;
    }

    Widget dot = AnimatedContainer(
      duration: AppAnimations.dotFill,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: isCurrent ? 2 : 1.5),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.3),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              ]
            : const [BoxShadow(color: Colors.white24, offset: Offset(0, 1))],
      ),
    );

    // Animate the current dot with a pulse
    if (isCurrent) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.15, 1.15),
            duration: const Duration(milliseconds: 800),
          )
          .then()
          .scale(
            begin: const Offset(1.15, 1.15),
            end: const Offset(1, 1),
            duration: const Duration(milliseconds: 800),
          );
    }

    // Animate newly completed dots
    if (isCompleted && index == completedCount - 1) {
      dot = dot
          .animate()
          .scale(
            begin: const Offset(0.5, 0.5),
            end: const Offset(1, 1),
            duration: AppAnimations.dotFill,
            curve: AppAnimations.bounceCurve,
          )
          .fade(begin: 0, end: 1, duration: AppAnimations.dotFill);
    }

    return dot;
  }
}

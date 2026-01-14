import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/theme.dart';

/// Visual progress indicator showing dots for each prompt
class ProgressDots extends StatelessWidget {
  final int totalDots;
  final int currentIndex;
  final List<bool?>
  results; // true = correct, false = incorrect, null = not answered

  const ProgressDots({
    super.key,
    required this.totalDots,
    required this.currentIndex,
    this.results = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalDots, (index) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.progressDotSpacing / 2,
          ),
          child: _buildDot(index),
        );
      }),
    );
  }

  Widget _buildDot(int index) {
    final isCompleted = index < results.length;
    final isCurrent = index == currentIndex;
    final result = isCompleted ? results[index] : null;

    Color color;
    Color borderColor;

    if (isCompleted) {
      color = result == true ? AppColors.correct : AppColors.incorrect;
      borderColor = color;
    } else if (isCurrent) {
      color = AppColors.primary.withValues(alpha: 0.3);
      borderColor = AppColors.primary;
    } else {
      color = Colors.transparent;
      borderColor = AppColors.textSecondary.withValues(alpha: 0.3);
    }

    Widget dot = AnimatedContainer(
      duration: AppAnimations.dotFill,
      width: AppSpacing.progressDotSize,
      height: AppSpacing.progressDotSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
    );

    // Animate the current dot with a pulse
    if (isCurrent) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.2, 1.2),
            duration: const Duration(milliseconds: 800),
          )
          .then()
          .scale(
            begin: const Offset(1.2, 1.2),
            end: const Offset(1, 1),
            duration: const Duration(milliseconds: 800),
          );
    }

    // Animate newly completed dots
    if (isCompleted && index == results.length - 1) {
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

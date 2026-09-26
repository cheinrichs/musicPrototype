import 'package:flutter/material.dart';
import '../../../ui/components/progress_dots.dart';
import '../../../ui/theme/theme.dart';
import 'high_low_header.dart';

/// The bottom row of the High/Low screens: Listen Again at the left, and
/// progress and Skip together in the bottom-right corner — which leaves the
/// centre of the screen clear for the characters and the task.
///
/// **Progress and Skip are two separate objects and must stay that way.**
/// Progress is passive information and the most colourful, most glanceable
/// thing on screen, which is exactly what a small child will poke; Skip is
/// the *adult's* control, deliberately quiet and uninviting to a
/// four-year-old. Merging them would make the adult's escape hatch the most
/// tappable object in the scene and produce accidental skips from a child
/// counting dots. So they share a corner, but progress is small and
/// non-interactive ([IgnorePointer]) and Skip stays a quiet pill beside it.
class HighLowFooter extends StatelessWidget {
  /// Listen Again (and whatever accompanies it), bottom-left.
  final Widget? leading;

  final int totalDots;
  final int currentIndex;
  final int completedCount;

  final bool skipEnabled;
  final VoidCallback? onSkip;

  const HighLowFooter({
    super.key,
    this.leading,
    required this.totalDots,
    required this.currentIndex,
    required this.completedCount,
    required this.skipEnabled,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // The left side yields: it scales down to whatever room the
        // right-hand corner leaves rather than overflowing, so the row can
        // never push progress or Skip off the screen.
        Expanded(
          child: leading == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: leading,
                  ),
                ),
        ),
        IgnorePointer(
          child: ProgressDots(
            totalDots: totalDots,
            currentIndex: currentIndex,
            completedCount: completedCount,
            compact: true,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        HighLowSkipPill(enabled: skipEnabled, onTap: onSkip),
      ],
    );
  }
}

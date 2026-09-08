import 'package:flutter/material.dart';
import '../../../ui/components/circle_icon_button.dart';
import '../../../ui/theme/theme.dart';
import 'high_low_caption.dart';

/// Close (left), the round's caption (center, see [HighLowCaption]), and
/// the child's skip control plus (dev builds only) the report button
/// (right) — extracted from `HighLowScreen._buildHeader` (Trello, "Split
/// Skip into two controls: escape and move-on" and its sibling cards land
/// a lot of change on this screen at once; this extraction is a pure move
/// with no behavior change, landed on its own first).
///
/// [Expanded] alone isn't enough to keep the caption clear of the close
/// button: it constrains the caption's *available* width, but nothing
/// stops the caption's own content from rendering flush against that
/// boundary with zero margin (Trello card hIKjobsB, found driving the
/// simulator — a long caption's centered text, wide enough to need nearly
/// the full Expanded width, measured with its own left edge exactly
/// touching the close button's right edge: no true overlap, but no
/// breathing room either, which reads as "running underneath" it). The
/// explicit [SizedBox] gaps below are the fix: they guarantee a minimum
/// margin on both sides regardless of how wide the caption's own text
/// needs to be.
class HighLowHeader extends StatelessWidget {
  final VoidCallback onClose;
  final String? captionText;

  /// Dev-only "Report this round" button (Trello card on0EymSu) — gated
  /// the same way as the dev gate, so a public App Store build never
  /// shows it. Null hides it entirely.
  final GlobalKey? reportButtonKey;
  final VoidCallback? onReportTap;
  final bool sharingReport;

  final bool skipEnabled;
  final VoidCallback? onSkip;

  const HighLowHeader({
    super.key,
    required this.onClose,
    required this.captionText,
    this.reportButtonKey,
    this.onReportTap,
    this.sharingReport = false,
    required this.skipEnabled,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          onTap: onClose,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: HighLowCaption(text: captionText)),
        const SizedBox(width: AppSpacing.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reportButtonKey != null) ...[
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleIconButton(
                    key: reportButtonKey,
                    icon: Icons.ios_share_rounded,
                    tooltip: 'Report this round',
                    onTap: sharingReport ? null : onReportTap,
                  ),
                  // Immediate acknowledgement that the tap landed — a slow
                  // capture-and-share otherwise gives no feedback at all
                  // until (or unless) the share sheet finally appears.
                  if (sharingReport)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            HighLowSkipPill(enabled: skipEnabled, onTap: onSkip),
          ],
        ),
      ],
    );
  }
}

/// The child's escape control — a parchment pill in the header's top-right
/// corner, opposite the close X (Trello card "Move Skip back to the top
/// right as an icon-plus-text pill"). Available from the very start of
/// every round, at every stage, and never gated on game phase — a child
/// who wants out should be able to get out, same as before (Trello card
/// 91), just from a spot they can actually find and reach themselves.
/// Sized generously ([AppSpacing.largeTapTarget]) so a child can still
/// find and hit it even though it reads visually quieter than the arrow
/// this replaced.
class HighLowSkipPill extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const HighLowSkipPill({super.key, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Skip',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.4,
          duration: AppAnimations.fast,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.largeTapTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
              border: Border.all(color: AppColors.cardEdge, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fast_forward_rounded,
                  color: AppColors.textSecondary,
                  size: 26,
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skip',
                      style: AppTypography.bodyLarge.copyWith(fontSize: 18),
                    ),
                    Text(
                      "I'm ready to move on",
                      style: AppTypography.label.copyWith(letterSpacing: 0),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

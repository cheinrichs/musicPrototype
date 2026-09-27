import 'package:flutter/material.dart';
import '../../../ui/components/circle_icon_button.dart';
import '../../../ui/theme/theme.dart';
import 'high_low_caption.dart';

/// The top of the High/Low screens: close (top-left), skip (top-right), the
/// round's caption centred between them (see [HighLowCaption]), and Listen
/// Again directly beneath the caption, also centred. That leaves the middle of
/// the screen holding nothing but the caption and Listen Again; the bottom
/// has no controls at all (progress is gone — see
/// `docs/product/HIGH_LOW_SCREEN_LAYOUT.md`).
///
/// **The caption is centred by construction.** Both sides reserve the same
/// width ([sideWidth]) whatever they hold, so the caption is centred on the
/// *screen*, not on whatever room happens to be left between a close button
/// on one side and a differently sized cluster on the other. (It used to sit
/// well left of centre: the right-hand side was narrower than the left.)
/// The explicit gaps also guarantee a minimum margin either side, however
/// wide the caption's own text needs to be (Trello card hIKjobsB: a long
/// caption's text once ran flush against the close button).
class HighLowHeader extends StatelessWidget {
  /// Width reserved on each side of the caption, the same in every build so
  /// the caption is always centred. Wide enough for Skip; the dev-only report
  /// button beside it scales the cluster down a little rather than taking
  /// room from the caption (a wider column made the longest captions wrap to
  /// a third line and ellipsize on an iPhone 17 — caught in a simulator
  /// screenshot).
  static const double sideWidth = 120;

  final VoidCallback onClose;
  final String? captionText;

  /// Listen Again, centred beneath the caption.
  final Widget? below;

  final bool skipEnabled;
  final VoidCallback? onSkip;

  /// Dev-only "Report this round" button (Trello card on0EymSu) — gated
  /// the same way as the dev gate, so a public App Store build never
  /// shows it. Null hides it entirely.
  final GlobalKey? reportButtonKey;
  final VoidCallback? onReportTap;
  final bool sharingReport;

  const HighLowHeader({
    super.key,
    required this.onClose,
    required this.captionText,
    required this.skipEnabled,
    required this.onSkip,
    this.below,
    this.reportButtonKey,
    this.onReportTap,
    this.sharingReport = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: sideWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: CircleIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onTap: onClose,
                ),
              ),
            ),
            Expanded(child: HighLowCaption(text: captionText)),
            SizedBox(
              width: sideWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
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
                          // Immediate acknowledgement that the tap landed — a
                          // slow capture-and-share otherwise gives no
                          // feedback at all until (or unless) the share sheet
                          // finally appears.
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
              ),
            ),
          ],
        ),
        if (below != null) below!,
      ],
    );
  }
}

/// The escape control: a small, quiet cream pill with an icon and the word
/// "Skip", top-right. Available from the very start of every round, at every
/// stage, and never gated on game phase — a child who wants out should be
/// able to get out (Trello card 91).
///
/// It had a subtitle ("I want something new") and a large tap target; both
/// went (Cooper: "far too big" / "ok losing the text on skip for now"). The
/// subtitle was doing a job — marking this as the *child's* bored-now control
/// as opposed to the adult's move-on control — so that distinction now rests
/// on the two controls *looking* different: this one is small, cream and
/// quiet, while the earned arrow is big, bright and gradient-filled. Keep
/// them from converging into a matched pair.
class HighLowSkipPill extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const HighLowSkipPill({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Skip',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.4,
          duration: AppAnimations.fast,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
              border: Border.all(color: AppColors.cardEdge, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fast_forward_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  'Skip',
                  style: AppTypography.bodyLarge.copyWith(
                    fontSize: 15,
                    color: AppColors.inkBrown,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

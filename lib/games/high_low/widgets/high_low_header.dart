import 'dart:math' as math;

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
///
/// **Close and Skip hug the true screen edges, at every screen size**
/// (2026-09-28, Cooper, on device: "Close button as far left as possible,
/// Skip as far right" — the stated principle behind it: "on a phone held in
/// landscape, a small child's thumbs reach the bottom corners and very
/// little else... keep adult and destructive controls up top where they
/// can't be hit by accident," which argues for these two sitting hard
/// against the top corners rather than drifting inward). This widget is
/// always built inside [GameScreenLayout]'s own `SafeArea` +
/// `EdgeInsets.symmetric(horizontal: AppSpacing.lg)` padding, so canceling
/// that fixed inset with an equal, opposite [Transform.translate] on each
/// side lands both controls flush against the safe-content edge — the
/// notch/inset itself is already carved out by the ancestor `SafeArea`
/// before this padding is applied, so this still respects a notch, it just
/// removes the *extra* margin GameScreenLayout adds for every other screen.
/// A translate (not a layout change) is deliberate: it moves the paint (and
/// the hit-test region, which `RenderTransform` carries along) without
/// touching how much width this row still reserves for [sideWidth] — the
/// caption's own centering is unaffected.
///
/// **The dev-only report button no longer lives here** (2026-09-28 — it used
/// to sit beside Skip). Cooper: "the report button only exists for dev
/// testing and really only for my profile" — a control no child ever sees
/// doesn't need to compete with Skip for top-right room, and per the
/// thumb-reach principle above, [HighLowScreen] now renders it itself as its
/// own bottom-left overlay instead.
class HighLowHeader extends StatelessWidget {
  /// Width reserved on each side of the caption, the same in every build so
  /// the caption is always centred. Wide enough for Skip on its own (the
  /// dev-only report button that used to share this column is gone —
  /// 2026-09-28); [FittedBox] below is still the safety net if a platform's
  /// text scaling makes Skip wider than this regardless.
  static const double sideWidth = 120;

  /// Cancels [GameScreenLayout]'s own horizontal padding so Close/Skip land
  /// on the true safe-content edge instead of sitting inset by it — see the
  /// class doc. Kept as its own named constant (rather than importing
  /// `AppSpacing.lg` at the call site) so the one number this depends on is
  /// obvious from here.
  static const double _edgeCancel = AppSpacing.lg;

  final VoidCallback onClose;
  final String? captionText;

  /// Guidance shown beneath [captionText], never instead of it — see
  /// [HighLowCaption.guidance].
  final String? guidanceText;

  /// Listen Again, centred beneath the caption.
  final Widget? below;

  final bool skipEnabled;
  final VoidCallback? onSkip;

  /// Where the caption goes, as insets from this header's own left and right
  /// edges. Null centres it on the screen between equal [sideWidth] columns.
  /// High/Low passes the meadow's span instead (Trello card 187): the
  /// composition is no longer symmetric, and screen-centred text lands in the
  /// tree's canopy. Close and Skip stay at the edges either way.
  final EdgeInsets? captionPadding;

  const HighLowHeader({
    super.key,
    required this.onClose,
    required this.captionText,
    this.guidanceText,
    required this.skipEnabled,
    required this.onSkip,
    this.below,
    this.captionPadding,
  });

  /// The narrowest the caption may be. Below this a two-line instruction
  /// wraps to three and is cut off; on a phone whose meadow is narrower (an
  /// SE), the plate reaches into the canopy instead, which it can because it
  /// is opaque.
  static const double minCaptionWidth = 280;

  /// Gap between the close button and the caption's plate.
  static const double _captionGap = AppSpacing.sm;

  /// The close button's width: [CircleIconButton]'s default size.
  static const double _closeButtonSize = 44;

  /// A [captionPadding] that centres the caption over the meadow: from just
  /// right of Close to [meadowRight] (the tree's left edge), on a [screen]
  /// with these safe-area [insets]. This header sits inside
  /// `GameScreenLayout`'s safe area and its horizontal [AppSpacing.lg]
  /// padding, so screen x minus both is header x. Shared by every screen on
  /// the tree (Trello cards 187, 188).
  static EdgeInsets meadowCaptionPadding({
    required Size screen,
    required EdgeInsets insets,
    required double meadowRight,
  }) {
    final headerLeft = insets.left + AppSpacing.lg;
    final headerWidth = screen.width - insets.horizontal - 2 * AppSpacing.lg;
    // Close is drawn flush with the safe edge (the padding is cancelled for
    // it), so its right edge is the inset plus its own width.
    final spanLeft = insets.left + _closeButtonSize + _captionGap;
    final spanRight = math.max(meadowRight, spanLeft + minCaptionWidth);
    return EdgeInsets.only(
      left: spanLeft - headerLeft,
      right: math.max(0, headerWidth - (spanRight - headerLeft)),
    );
  }

  /// Close, hugging the left edge — see the class doc.
  Widget _close() => Transform.translate(
    offset: const Offset(-_edgeCancel, 0),
    child: CircleIconButton(
      icon: Icons.close_rounded,
      tooltip: 'Close',
      onTap: onClose,
    ),
  );

  /// Skip, hugging the right edge.
  Widget _skip() => Transform.translate(
    offset: const Offset(_edgeCancel, 0),
    child: HighLowSkipPill(enabled: skipEnabled, onTap: onSkip),
  );

  @override
  Widget build(BuildContext context) {
    final padding = captionPadding;
    if (padding != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: padding,
                child: HighLowCaption(
                  text: captionText,
                  guidance: guidanceText,
                ),
              ),
              Positioned(left: 0, child: _close()),
              Positioned(right: 0, child: _skip()),
            ],
          ),
          // Under the caption, not the screen's middle: it belongs to it.
          if (below != null)
            Padding(
              padding: EdgeInsets.only(
                left: padding.left,
                right: padding.right,
              ),
              child: below!,
            ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: sideWidth,
              child: Align(alignment: Alignment.centerLeft, child: _close()),
            ),
            Expanded(
              child: HighLowCaption(text: captionText, guidance: guidanceText),
            ),
            SizedBox(
              width: sideWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _skip(),
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

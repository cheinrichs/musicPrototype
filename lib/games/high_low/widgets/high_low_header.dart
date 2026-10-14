import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../ui/components/round_set_progress_bar.dart';
import '../../../ui/theme/theme.dart';
import 'high_low_caption.dart';

/// The top row of every game screen (Trello card 216): Close on a cream
/// plate, a short progress bar, the round's caption, and Skip on a cream
/// pill — one row, top of the screen, out of the scene.
///
/// - **No game title.** A non-reader cannot use it, and a child looking at
///   the screen already knows what they are playing.
/// - **The caption lives in the row**, between the bar and Skip. One short
///   line, so the copy is written short (card 211 demotes captions to quiet
///   redundancy now the voice carries the instruction). Explore's six-second
///   guidance joins beneath it, never in its place (card 193): the caption's
///   plate grows downward, and nothing else in the row moves. Keeping it out
///   of the scene also ends the SE collision where that second line pushed
///   the caption over Piper's head.
/// - **Close sits on a solid plate, as Skip does.** A light glyph with no
///   backing vanishes into busy art — the third time that failure shipped
///   (card 150's credits button, card 215's "?"). The whole plate is the tap
///   target.
/// - **Laid out where they sit.** Nothing here is moved by a translate: a
///   translated control is only tappable where its painted and laid-out
///   boxes overlap, which once left most of the close button dead.
class HighLowHeader extends StatelessWidget {
  final VoidCallback onClose;
  final String? captionText;

  /// Guidance shown beneath [captionText], never instead of it — see
  /// [HighLowCaption.guidance].
  final String? guidanceText;

  /// Shown beneath the caption (the ordering screen's replay control).
  final Widget? below;

  final bool skipEnabled;
  final VoidCallback? onSkip;

  /// How far through the round set the child is, 0 to 1 (Trello card 196);
  /// null for a screen with no set, which then has no bar.
  final double? progress;

  const HighLowHeader({
    super.key,
    required this.onClose,
    required this.captionText,
    this.guidanceText,
    required this.skipEnabled,
    required this.onSkip,
    this.below,
    this.progress,
  });

  /// The close plate's size, and its tap target.
  static const double closeSize = 44;

  /// About what Skip measures, for sizing the bar against the row.
  static const double _skipWidth = 80;

  /// The bar's length in a row [rowWidth] wide: a third of what it was when
  /// it filled the row between Close and Skip (Cooper, card 216: "1/3 of its
  /// current length"). It is chunkier to make up for it — see
  /// [RoundSetProgressBar.height].
  static double barWidthFor(double rowWidth) => math.max(
    0,
    (rowWidth - closeSize - AppSpacing.xs - AppSpacing.md - _skipWidth) / 3,
  );

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HighLowClosePlate(onTap: onClose),
          if (progress != null) ...[
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: barWidthFor(constraints.maxWidth),
              height: closeSize,
              child: Center(child: RoundSetProgressBar(progress: progress)),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HighLowCaption(text: captionText, guidance: guidanceText),
                if (below != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  below!,
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: closeSize,
            child: Center(
              child: HighLowSkipPill(enabled: skipEnabled, onTap: onSkip),
            ),
          ),
        ],
      ),
    );
  }
}

/// Close, on a solid cream plate with a bold warm-brown cross — the same
/// backing Skip has, so it reads on any art. The whole plate takes the tap.
class HighLowClosePlate extends StatelessWidget {
  final VoidCallback onTap;

  const HighLowClosePlate({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close',
      child: GestureDetector(
        key: const ValueKey('close-plate'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: HighLowHeader.closeSize,
          height: HighLowHeader.closeSize,
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.cardEdge, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const CustomPaint(painter: _CrossPainter()),
        ),
      ),
    );
  }
}

/// A bold cross with round ends — heavier than the icon font's.
class _CrossPainter extends CustomPainter {
  const _CrossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = AppColors.inkBrown
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;
    final a = size.width * 0.34;
    final b = size.width - a;
    canvas.drawLine(Offset(a, a), Offset(b, b), pen);
    canvas.drawLine(Offset(b, a), Offset(a, b), pen);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => false;
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
/// quiet, while the earned bar is big, bright and blue. Keep them from
/// converging into a matched pair.
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

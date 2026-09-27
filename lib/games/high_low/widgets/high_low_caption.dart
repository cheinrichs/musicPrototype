import 'package:flutter/material.dart';
import '../../../ui/theme/theme.dart';

/// The round's caption, shown at the top of [HighLowScreen]'s header
/// (extracted from `_buildPromptArea` so the header's controls and its
/// caption area are two separately readable pieces — Trello, "Split Skip
/// into two controls: escape and move-on" and its sibling cards land a lot
/// of change on this screen at once, and this extraction is a pure move
/// with no behavior change, landed on its own first).
///
/// Reserves two lines' worth of height even when [text] is null so the
/// header doesn't jump as it toggles on and off between rounds.
///
/// **The plate is a switch, not a layout.** With [plate] on the text sits on
/// the same cream plaque as the other controls; off, it is bare text with a
/// soft shadow. Both use identical padding, so flipping [defaultPlate]
/// cannot move or resize anything. Cooper is undecided (most concept art has
/// no background; the newest concept uses a banner and he likes that too);
/// the case for the plate is legibility — this layout puts the caption over
/// trees and hills, and a caption whose audience is the watching adult is
/// worthless if it vanishes. It is on by default.
class HighLowCaption extends StatelessWidget {
  /// The one place to flip the plate for the whole app.
  static const bool defaultPlate = true;

  final String? text;
  final bool plate;

  const HighLowCaption({
    super.key,
    required this.text,
    this.plate = defaultPlate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Two lines of text plus the plate's own padding and border, so a
      // two-line caption is never clipped by the switcher's bounds (it was:
      // the descenders of the second line were cut off).
      height:
          AppTypography.heading3.fontSize! *
              AppTypography.heading3.height! *
              2 +
          2 * AppSpacing.xs +
          3,
      child: Center(
        child: AnimatedSwitcher(
          duration: AppAnimations.medium,
          child: text == null
              ? const SizedBox.shrink(key: ValueKey('caption-empty'))
              : DecoratedBox(
                  key: ValueKey('caption-$text'),
                  decoration: plate
                      ? BoxDecoration(
                          gradient: AppColors.cardGradient,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusRound,
                          ),
                          border: Border.all(
                            color: AppColors.cardEdge,
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        )
                      : const BoxDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      text!,
                      style: AppTypography.heading3.copyWith(
                        color: plate ? AppColors.inkBrown : Colors.white,
                        shadows: plate
                            ? null
                            : const [
                                Shadow(color: Color(0xCC2E2116), blurRadius: 6),
                              ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

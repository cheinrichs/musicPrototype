import 'package:flutter/material.dart';
import '../../../ui/theme/theme.dart';

/// The top of [HighLowScreen]'s header: the game's name, large, with the
/// round's parent instruction smaller beneath it — both inside the same
/// plate (2026-09-27, Cooper: "game name large, parent instruction smaller
/// beneath it, both inside the tan bubble").
///
/// **Both lines are adult-facing.** The child can't read either one — the
/// name is orientation for whoever's sitting alongside ("what game is
/// this?"), not a heading for the player, same audience as the instruction
/// it sits above.
///
/// **The name is constant; only the instruction changes per round**, so
/// only the instruction crossfades between rounds (the plate itself, and
/// the name, never rebuild for that). Reserves the instruction's own
/// two-line height even when [text] is null (briefly, before the intro
/// finishes) so the plate doesn't resize as it toggles on.
///
/// **Grows taller, never wider.** A second line of text was the reason for
/// this restructure in the first place; if it were solved by growing the
/// bubble sideways instead, it would crowd the close button on one side and
/// Skip on the other (Cooper's own warning). [HighLowHeader] reserves a
/// fixed width on each side regardless of what this contains — this widget
/// only ever asks for *height*.
///
/// **The plate is a switch, not a layout.** With [plate] on, both lines sit
/// on the same cream plaque as the other controls; off, they're bare text
/// with a soft shadow. Both use identical padding, so flipping
/// [defaultPlate] cannot move or resize anything. Cooper is undecided (most
/// concept art has no background; the newest concept uses a banner and he
/// likes that too); the case for the plate is legibility — this layout puts
/// the caption over trees and hills, and a caption whose audience is the
/// watching adult is worthless if it vanishes. It is on by default.
class HighLowCaption extends StatelessWidget {
  /// The one place to flip the plate for the whole app.
  static const bool defaultPlate = true;

  /// This game's name, shown above the round instruction every round.
  static const String gameName = 'High vs Low';

  /// The round's parent instruction — the smaller, second line. Null only
  /// briefly, before the intro has a round to describe.
  final String? text;
  final bool plate;

  const HighLowCaption({
    super.key,
    required this.text,
    this.plate = defaultPlate,
  });

  static double get _nameHeight =>
      AppTypography.heading2.fontSize! * AppTypography.heading2.height!;

  // Two lines of the instruction, plus the plate's own padding/border, so a
  // two-line instruction is never clipped by the switcher's bounds (it was:
  // the descenders of the second line were cut off).
  static double get _instructionHeight =>
      AppTypography.bodyLarge.fontSize! * AppTypography.bodyLarge.height! * 2;

  static const double _gap = AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final textColor = plate ? AppColors.inkBrown : Colors.white;
    final shadows = plate
        ? null
        : const [Shadow(color: Color(0xCC2E2116), blurRadius: 6)];

    return SizedBox(
      height: _nameHeight + _gap + _instructionHeight + 2 * AppSpacing.sm + 3,
      child: Center(
        child: DecoratedBox(
          decoration: plate
              ? BoxDecoration(
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
                )
              : const BoxDecoration(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gameName,
                  style: AppTypography.heading2.copyWith(
                    color: textColor,
                    shadows: shadows,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
                const SizedBox(height: _gap),
                SizedBox(
                  height: _instructionHeight,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: AppAnimations.medium,
                      child: text == null
                          ? const SizedBox.shrink(key: ValueKey('instr-empty'))
                          : Text(
                              text!,
                              key: ValueKey('instr-$text'),
                              style: AppTypography.bodyLarge.copyWith(
                                color: textColor,
                                shadows: shadows,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
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

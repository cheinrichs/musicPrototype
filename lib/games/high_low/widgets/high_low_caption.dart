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
/// with a soft shadow. Both use identical padding regardless, so flipping
/// [defaultPlate] cannot move or resize anything, in either dimension.
///
/// **Off by default (2026-09-28, Cooper, on device: "no tan bubble — plain
/// text, legibility via colour choice, not a plate"), reversing the earlier
/// decision recorded above.** Legibility over the meadow now comes from the
/// text shadow ([shadows]) instead of a plaque behind it. Both lines are
/// also smaller than before, per the same note ("smaller text") — this is
/// adult-facing orientation copy, not something a child reads, so it never
/// needed heading-sized type; shrinking it is also the first move in
/// reclaiming vertical room at the top of the screen, ahead of anything
/// that moves the stumps.
class HighLowCaption extends StatelessWidget {
  /// The one place to flip the plate for the whole app.
  static const bool defaultPlate = false;

  /// This game's name, shown above the round instruction every round.
  static const String gameName = 'High vs Low';

  /// Font sizes with the plate gone (2026-09-28) — down from [heading2]'s 36
  /// and [bodyLarge]'s 20; same families/weights via `.copyWith`, so this is
  /// a size change only, not a restyle.
  static const double _gameNameFontSize = 22;
  static const double _instructionFontSize = 15;

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
      _gameNameFontSize * AppTypography.heading2.height!;

  // Two lines of the instruction, plus the plate's own padding/border, so a
  // two-line instruction is never clipped by the switcher's bounds (it was:
  // the descenders of the second line were cut off).
  static double get _instructionHeight =>
      _instructionFontSize * AppTypography.bodyLarge.height! * 2;

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
                    fontSize: _gameNameFontSize,
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
                                fontSize: _instructionFontSize,
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

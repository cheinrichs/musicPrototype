import 'package:flutter/material.dart';
import '../../../ui/theme/theme.dart';

/// The round's parent instruction, on its cream plate in the top row
/// (Trello card 216). **Adult-facing** — the child can't read it; the voice
/// carries the instruction, and this is quiet redundancy for whoever is
/// sitting alongside (card 211).
///
/// - **One line.** It sits in a row-height slot, so the copy is written short
///   rather than set smaller; anything longer is cut with an ellipsis, never
///   wrapped. The game's name is gone (card 216): a non-reader cannot use it.
/// - **The instruction only crossfades between rounds**; the plate itself
///   never rebuilds for that, and it reserves its line even when [text] is
///   null (briefly, before the intro finishes), so nothing resizes.
/// - **Guidance joins beneath, never replaces** (card 193): the plate grows
///   downward by one line when it arrives. Nothing else in the row moves.
/// - **The plate is a switch, not a layout**: [plate] off draws bare text
///   with a soft shadow, at identical size.
class HighLowCaption extends StatelessWidget {
  /// The one place to flip the plate for the whole app.
  static const bool defaultPlate = true;

  static const double _fontSize = 15;

  /// The longest caption, in characters, that fits whole on an SE (about
  /// 260 px inside the plate). Every game's copy stays at or under it —
  /// checked in each game's tests.
  static const int maxLength = 30;

  /// The instruction line's height: the same as the row's controls, so the
  /// plate lines up with Close and Skip.
  static const double lineHeight = 44;

  /// The round's parent instruction. Null only briefly, before the intro has
  /// a round to describe.
  final String? text;

  /// Parent guidance that arrives partway through a round (Explore's
  /// six-second line), shown **beneath** [text], never in place of it. The
  /// timing stays: guidance on screen from the start is noise, arriving as a
  /// parent starts wondering it is help.
  final String? guidance;
  final bool plate;

  const HighLowCaption({
    super.key,
    required this.text,
    this.guidance,
    this.plate = defaultPlate,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = plate ? AppColors.inkBrown : Colors.white;
    // Quieter than the instruction, so it reads as an aside to the parent.
    final guidanceColor = plate ? AppColors.warmGray : Colors.white70;
    final shadows = plate
        ? null
        : const [Shadow(color: Color(0xCC2E2116), blurRadius: 6)];
    TextStyle style(Color color) => AppTypography.bodyLarge.copyWith(
      fontSize: _fontSize,
      color: color,
      shadows: shadows,
    );

    return DecoratedBox(
      decoration: plate
          ? BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(lineHeight / 2),
              border: Border.all(color: AppColors.cardEdge, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            )
          : const BoxDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: lineHeight,
              child: Center(
                child: AnimatedSwitcher(
                  duration: AppAnimations.medium,
                  child: text == null
                      ? const SizedBox.shrink(key: ValueKey('instr-empty'))
                      : Text(
                          text!,
                          key: ValueKey('instr-$text'),
                          style: style(textColor),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ),
            if (guidance != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: AppAnimations.medium,
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: Text(
                    guidance!,
                    key: const ValueKey('caption-guidance'),
                    style: style(guidanceColor),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

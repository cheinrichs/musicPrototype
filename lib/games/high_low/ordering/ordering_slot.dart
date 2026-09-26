import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../ui/theme/theme.dart';

/// The four states of an ordering platform's drop slot (Trello card 11).
///
/// There is deliberately no "wrong" state. A slot never marks a mistake:
/// right placements are ticked ([confirmed]) and wrong ones simply go back
/// to their stumps — "describe the answer, not the attempt", expressed in
/// symbols (docs/product/LEARNING_ARCHITECTURE.md). The obvious instinct
/// here is a red cross for symmetry; that would undo it.
enum SlotState {
  /// Nothing on this platform yet — an affordance saying *something goes
  /// here*.
  empty,

  /// An instrument is being dragged over it.
  hovering,

  /// An instrument stands on it and hasn't been checked (or was checked
  /// and sent home — the slot is empty again then, not marked).
  filled,

  /// The instrument here was right and stays.
  confirmed,
}

/// What a slot looks like in one state. Plain data, so a whole treatment can
/// be swapped by swapping the [SlotStyle] that produces it, and so each
/// state's look can be checked directly.
@immutable
class SlotLook {
  final Color color;
  final double opacity;

  /// Strength of the soft shadow under the disc (0 = none).
  final double shadowOpacity;

  final Color? ringColor;

  /// Whether the "?" shows.
  final bool glyph;
  final Color glyphColor;
  final double scale;

  const SlotLook({
    required this.color,
    required this.opacity,
    this.shadowOpacity = 0,
    this.ringColor,
    this.glyph = false,
    this.glyphColor = Colors.white,
    this.scale = 1.0,
  });

  @override
  bool operator ==(Object other) =>
      other is SlotLook &&
      other.color == color &&
      other.opacity == opacity &&
      other.shadowOpacity == shadowOpacity &&
      other.ringColor == ringColor &&
      other.glyph == glyph &&
      other.glyphColor == glyphColor &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(
    color,
    opacity,
    shadowOpacity,
    ringColor,
    glyph,
    glyphColor,
    scale,
  );
}

/// One complete visual treatment for the slots. The look of the whole
/// affordance is this single decision — [orderingSlotStyle] — so trying a
/// different one is a one-line change that touches no layout.
abstract class SlotStyle {
  const SlotStyle();
  SlotLook look(SlotState state);
}

/// A soft dark depression with a shadow. The tree's platforms are curved
/// rather than rectangular, and a crisp outline reads as UI pasted onto a
/// painting; this reads as a dip in the wood that something belongs in,
/// while still being slightly artificial — it's an affordance, not scenery.
class SoftDepressionSlotStyle extends SlotStyle {
  const SoftDepressionSlotStyle();

  @override
  SlotLook look(SlotState state) => switch (state) {
    SlotState.empty => const SlotLook(
      color: Color(0xFF2A1D10),
      opacity: 0.55,
      shadowOpacity: 0.45,
      glyph: true,
      glyphColor: Color(0xCCF3E9CE),
    ),
    SlotState.hovering => const SlotLook(
      color: Color(0xFF3A2A14),
      opacity: 0.35,
      shadowOpacity: 0.3,
      ringColor: AppColors.gold,
      scale: 1.12,
    ),
    SlotState.filled => const SlotLook(
      color: Color(0xFF2A1D10),
      opacity: 0.30,
      shadowOpacity: 0.5,
    ),
    SlotState.confirmed => const SlotLook(
      color: Color(0xFF2A1D10),
      opacity: 0.25,
      shadowOpacity: 0.4,
      ringColor: AppColors.correct,
    ),
  };
}

/// An alternative to compare: a flat grey placeholder with a question mark.
class GreyQuestionSlotStyle extends SlotStyle {
  const GreyQuestionSlotStyle();

  @override
  SlotLook look(SlotState state) => switch (state) {
    SlotState.empty => const SlotLook(
      color: Color(0xFF8A8F94),
      opacity: 0.85,
      glyph: true,
    ),
    SlotState.hovering => const SlotLook(
      color: Color(0xFFB4B8BC),
      opacity: 0.9,
      scale: 1.12,
      ringColor: AppColors.gold,
    ),
    SlotState.filled => const SlotLook(color: Color(0xFF8A8F94), opacity: 0.3),
    SlotState.confirmed => const SlotLook(
      color: Color(0xFF8A8F94),
      opacity: 0.3,
      ringColor: AppColors.correct,
    ),
  };
}

/// The one decision that sets how every ordering slot looks.
const SlotStyle orderingSlotStyle = SoftDepressionSlotStyle();

/// A platform's drop slot: an oval sized to the platform's flat top,
/// painted from a [SlotLook]. Built in code rather than as art because it
/// has states, animates as an instrument passes over, and has to land on the
/// tree's platforms at whatever size the screen gives.
class OrderingSlot extends StatelessWidget {
  final SlotState state;
  final Size size;
  final SlotStyle style;

  const OrderingSlot({
    super.key,
    required this.state,
    required this.size,
    this.style = orderingSlotStyle,
  });

  @override
  Widget build(BuildContext context) {
    final look = style.look(state);
    return SizedBox.fromSize(
      size: size,
      child: AnimatedScale(
        scale: look.scale,
        duration: AppAnimations.fast,
        curve: Curves.easeOutBack,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _OvalPainter(look))),
            if (look.glyph)
              Text(
                '?',
                style: TextStyle(
                  fontSize: size.height * 0.75,
                  fontWeight: FontWeight.w800,
                  color: look.glyphColor,
                  height: 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OvalPainter extends CustomPainter {
  final SlotLook look;
  _OvalPainter(this.look);

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Offset.zero & size;
    if (look.shadowOpacity > 0) {
      canvas.drawOval(
        oval.translate(0, size.height * 0.18).inflate(size.height * 0.08),
        Paint()
          ..color = Colors.black.withValues(alpha: look.shadowOpacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.35),
      );
    }
    canvas.drawOval(
      oval,
      Paint()
        ..shader = RadialGradient(
          colors: [
            look.color.withValues(alpha: look.opacity),
            look.color.withValues(alpha: look.opacity * 0.55),
          ],
        ).createShader(oval),
    );
    if (look.ringColor != null) {
      canvas.drawOval(
        oval.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = look.ringColor!.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_OvalPainter old) => old.look != look;
}

/// The green tick on a correctly placed instrument — it stays put, where a
/// voice line would evaporate. The only mark this screen ever makes: nothing
/// marks a wrong placement, in any colour or form.
class PlacementTick extends StatelessWidget {
  final double size;

  const PlacementTick({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Correct',
      child:
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.correct,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: size * 0.75,
              ),
            ),
          ).animate().scale(
            begin: const Offset(0.3, 0.3),
            end: const Offset(1, 1),
            duration: AppAnimations.medium,
            curve: Curves.elasticOut,
          ),
    );
  }
}

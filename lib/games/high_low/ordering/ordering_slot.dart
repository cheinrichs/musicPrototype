import 'dart:math' as math;

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
  /// The translucent wash inside the outline (0 opacity = none).
  final Color fill;
  final double fillOpacity;

  /// The outline, or null for none.
  final Color? outline;
  final double outlineWidth;

  /// Whether the outline is dashed — "something belongs here" — or solid.
  final bool dashed;

  /// Whether the note glyph shows.
  final bool glyph;
  final double scale;

  const SlotLook({
    required this.fill,
    required this.fillOpacity,
    this.outline,
    this.outlineWidth = 2,
    this.dashed = true,
    this.glyph = false,
    this.scale = 1.0,
  });

  /// Draws nothing at all.
  bool get invisible => fillOpacity == 0 && outline == null && !glyph;

  @override
  bool operator ==(Object other) =>
      other is SlotLook &&
      other.fill == fill &&
      other.fillOpacity == fillOpacity &&
      other.outline == outline &&
      other.outlineWidth == outlineWidth &&
      other.dashed == dashed &&
      other.glyph == glyph &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(
    fill,
    fillOpacity,
    outline,
    outlineWidth,
    dashed,
    glyph,
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

/// A dashed outline roughly the shape of what goes in it, with a note glyph
/// inside (Trello card 215, from the concept board's ordering panel).
///
/// **A drop slot is an instruction to the player, so it reads as a layer on
/// top of the painting, not as part of it.** The slot it replaced — a soft
/// dark dip in the wood with a pale "?" — tried to be scenery, and the eye
/// filed it as wood grain: cream on tan, no edge, a label rather than a
/// container. Things that are part of the fiction get painted into the world
/// (a journey stone, card 206); things that tell the child what to do sit
/// over it.
///
/// - A **dashed outline** is the universal "something belongs here": a
///   container missing its occupant.
/// - It stands on the platform at about **an instrument's size**, so it says
///   what fits before anything is dragged.
/// - A **note**, not a "?": what kind of thing goes here, without words.
/// - **Cool colours** — a pale blue line over a navy wash. Nothing else in
///   these scenes is cool, so it separates from the wood and the leaves, and
///   it stays outside the Loud or Quiet dial's cream → gold → orange ramp, so
///   it is never read as a step on the loudness scale.
/// - **Visible before a drag starts**, and **stronger while one passes
///   over**: a slot only shown mid-drag teaches nothing to a child who has not
///   worked out that dragging is possible.
/// - **Filled or confirmed, it draws nothing**: the instrument standing there
///   (and its tick) says it. No state ever marks a wrong placement.
class DashedSlotStyle extends SlotStyle {
  const DashedSlotStyle();

  static const Color line = Color(0xFFDDEBF7);
  static const Color wash = AppColors.night;
  static const Color hoverWash = AppColors.skyDeep;

  @override
  SlotLook look(SlotState state) => switch (state) {
    SlotState.empty => const SlotLook(
      fill: wash,
      fillOpacity: 0.32,
      outline: line,
      outlineWidth: 2.5,
      glyph: true,
    ),
    SlotState.hovering => const SlotLook(
      fill: hoverWash,
      fillOpacity: 0.5,
      outline: Colors.white,
      outlineWidth: 3.5,
      dashed: false,
      glyph: true,
      scale: 1.08,
    ),
    SlotState.filled ||
    SlotState.confirmed => const SlotLook(fill: wash, fillOpacity: 0),
  };
}

/// The one decision that sets how every drop slot looks — on the tree, on
/// the ordering screen and on the Loud or Quiet dial.
const SlotStyle orderingSlotStyle = DashedSlotStyle();

/// A platform's drop slot, painted from a [SlotLook] inside the drop
/// target's own box: the outline stands on the platform's face (four fifths
/// of the way down the box, where every layout puts it) and rises about an
/// instrument's height. Built in code rather than as art because it has
/// states, animates as an instrument passes over, and has to land on the
/// platforms at whatever size the screen gives.
class OrderingSlot extends StatelessWidget {
  final SlotState state;

  /// The drop target's box, with the platform face at [faceFraction] of its
  /// height.
  final Size size;
  final SlotStyle style;

  const OrderingSlot({
    super.key,
    required this.state,
    required this.size,
    this.style = orderingSlotStyle,
  });

  /// Where the platform's face is, down the drop target's box — the same
  /// 0.8 every layout's `slotRect` puts it at.
  static const double faceFraction = 0.8;

  /// The outline's rectangle inside a drop target of [size]: as tall as most
  /// of the box above the face, a little narrower than tall like an upright
  /// instrument, standing just past the face so it sits on the wood rather
  /// than hovering over it.
  static Rect outlineRect(Size size) {
    final bottom = size.height * (faceFraction + 0.05);
    final h = size.height * 0.8;
    final w = math.min(size.width, h * 0.85);
    return Rect.fromLTWH((size.width - w) / 2, bottom - h, w, h);
  }

  @override
  Widget build(BuildContext context) {
    final look = style.look(state);
    final box = outlineRect(size);
    return SizedBox.fromSize(
      size: size,
      child: look.invisible
          ? null
          : Stack(
              children: [
                Positioned.fromRect(
                  rect: box,
                  child: AnimatedScale(
                    scale: look.scale,
                    duration: AppAnimations.fast,
                    curve: Curves.easeOutBack,
                    child: CustomPaint(
                      painter: _DashedSlotPainter(look),
                      child: look.glyph
                          ? Center(
                              child: Icon(
                                Icons.music_note_rounded,
                                key: const ValueKey('slot-glyph'),
                                size: box.height * 0.45,
                                color: (look.outline ?? Colors.white)
                                    .withValues(alpha: 0.95),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DashedSlotPainter extends CustomPainter {
  final SlotLook look;
  _DashedSlotPainter(this.look);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.shortestSide * 0.18);
    final shape = RRect.fromRectAndRadius(Offset.zero & size, radius);
    if (look.fillOpacity > 0) {
      canvas.drawRRect(
        shape,
        Paint()..color = look.fill.withValues(alpha: look.fillOpacity),
      );
    }
    final outline = look.outline;
    if (outline == null) return;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = look.outlineWidth
      ..strokeCap = StrokeCap.round
      ..color = outline;
    final edge = Path()..addRRect(shape.deflate(look.outlineWidth / 2));
    if (!look.dashed) {
      canvas.drawPath(edge, pen);
      return;
    }
    final dash = look.outlineWidth * 3;
    final gap = look.outlineWidth * 2.2;
    for (final metric in edge.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), pen);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedSlotPainter old) => old.look != look;
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

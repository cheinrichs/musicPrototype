import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Where a dragged instrument lands, judged by the INSTRUMENT, not the finger
/// (Trello card 221).
///
/// Flutter's [DragTarget] accepts a drop only when the pointer itself is
/// inside the target. The instruments are tall and a small child grabs them
/// anywhere — often low down — so an instrument could sit squarely on its
/// slot while the finger was a grip's height below it, and the drop sprang
/// back. Card 212 rests on the apparatus telling the truth; a slot refusing a
/// right answer told a child who was right that they were wrong, with no
/// voice to say otherwise, and recorded it that way for promotion too.
///
/// So on release a drop snaps to the NEAREST target within [radiusFor] of
/// the dragged sprite's own centre. The highlight while dragging goes through
/// exactly the same [resolve] with the same radius: if a slot lights up, it
/// accepts. Lighting up and then refusing is a yes followed by a no.
///
/// Nearest-target can't be ambiguous between instrument and slot: a resting
/// instrument's centre is at least 119 pt from the nearest slot (the dial, on
/// an SE), and the radius stays well short of that (see each layout's test),
/// so a pick-up and put-down without travelling never counts.
class DropSnap {
  /// The accept radius, as a fraction of the dragged sprite's size: more than
  /// half, so any drop where the instrument visibly covers the slot's edge
  /// counts, with slack for a three-year-old's release.
  static const double radiusOfSprite = 0.6;

  static double radiusFor(double spriteSize) => spriteSize * radiusOfSprite;

  /// How far [p] is from [r]: zero inside it, else to its nearest edge.
  static double distanceToRect(Offset p, Rect r) {
    final dx = math.max(math.max(r.left - p.dx, 0.0), p.dx - r.right);
    final dy = math.max(math.max(r.top - p.dy, 0.0), p.dy - r.bottom);
    return math.sqrt(dx * dx + dy * dy);
  }

  /// The target in [targets] nearest [centre], and how far it is — null when
  /// there are no targets.
  static ({int index, double distance})? nearest(
    Offset centre,
    Map<int, Rect> targets,
  ) {
    ({int index, double distance})? best;
    for (final e in targets.entries) {
      final d = distanceToRect(centre, e.value);
      if (best == null || d < best.distance) {
        best = (index: e.key, distance: d);
      }
    }
    return best;
  }

  /// The target a sprite centred on [centre] lands on, or null if the
  /// nearest is further than [radius]. Used both for the highlight and for
  /// the release, so the two can never disagree.
  static int? resolve(Offset centre, Map<int, Rect> targets, double radius) {
    final hit = nearest(centre, targets);
    return hit != null && hit.distance <= radius ? hit.index : null;
  }
}

/// One drag's grip: where on the sprite the finger took hold, so the
/// sprite's centre can be found from the pointer during the drag. Pass
/// [anchor] as the [Draggable.dragAnchorStrategy] — it keeps Flutter's
/// default (the sprite stays where it was grabbed) and records the grip.
class SpriteGrip {
  Offset grip = Offset.zero;

  Offset anchor(Draggable<Object> draggable, BuildContext context, Offset p) {
    grip = childDragAnchorStrategy(draggable, context, p);
    return grip;
  }

  /// The sprite's top-left for a pointer at [pointer].
  Offset topLeftFor(Offset pointer) => pointer - grip;
}

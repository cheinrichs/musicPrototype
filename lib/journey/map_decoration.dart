import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/art_registry.dart';
import '../ui/components/house_wobble.dart';

/// How a decoration reacts when poked. Two frames per decoration (rest and
/// hit), so the life comes from TRANSFORM, not the art.
///
/// The split (Cooper, 2026-11; STANDING_RULES.md): OBJECTS GET PHYSICAL
/// REACTIONS, CREATURES GET BEHAVIOURAL ONES. Objects may be mirrored;
/// creatures never (a flip reads as the animal turning round).
enum DecorationMotion {
  /// Object whose hit frame is strongly tilted: mirrored to make a third
  /// state, then upright → lean → lean the other way → upright.
  tiltWobble,

  /// Object whose hit frame is squashed: squash down, spring back.
  squash,

  /// Object with no tilt in either frame: rotation in code, a big damped
  /// wobble.
  rotateWobble,

  /// Creature: leaps up and lands.
  leap,

  /// Creature: a little hop.
  hop,

  /// Creature: withdraws (hit) for a beat, then comes back out.
  withdraw,

  /// Creature: flaps — rest and hit alternating — rising a little.
  flap,

  /// Creature: darts aside and back.
  dart,
}

/// DATA: each decoration's motion. A decoration added later picks one by
/// what it is: an object, a physical motion; a creature, a behaviour.
const Map<String, DecorationMotion> decorationMotions = {
  // Objects.
  'acorn': DecorationMotion.tiltWobble,
  'bluebells': DecorationMotion.tiltWobble,
  'daisy': DecorationMotion.tiltWobble,
  'mushroom': DecorationMotion.squash,
  // Cooper: "wobble back and forth more" — its two frames are nearly the
  // same silhouette, so the motion carries the reaction.
  'pine_cone': DecorationMotion.rotateWobble,
  // Creatures.
  'frog': DecorationMotion.leap,
  'chipmunk': DecorationMotion.hop,
  'bluebird': DecorationMotion.hop,
  'ladybird': DecorationMotion.hop,
  'snail': DecorationMotion.withdraw,
  'butterfly': DecorationMotion.flap,
  'dragonfly': DecorationMotion.dart,
};

/// The sound a decoration makes when poked, by id — NON-PITCHED, always:
/// rustles, squeaks, plops, flutters. Creatures make noises, instruments
/// make notes (STANDING_RULES.md). None are recorded yet: an id with no
/// clip is silent, never a wait or an error.
String decorationSoundId(String name) => 'sfx.decoration.$name';

/// A decoration on the Journey map: drawn at rest, reacting when tapped and
/// always returning to rest — the hit state is a reaction, never latched.
///
/// INTERRUPTIBLE, NOT QUEUED: a tap mid-reaction restarts it from where it
/// is. At most [maxReacting] react at once across the map; a new one stops
/// the oldest.
class MapDecoration extends StatefulWidget {
  /// The decoration's name: `mushroom`, `frog`… (its art is
  /// `decoration.<name>.rest` / `.hit`).
  final String name;
  final double size;

  /// Called on a tap, with the sound id to play (if one exists).
  final void Function(String soundId)? onPoke;

  const MapDecoration({
    super.key,
    required this.name,
    required this.size,
    this.onPoke,
  });

  static const int maxReacting = 4;

  /// Decorations reacting now, oldest first.
  static final List<_MapDecorationState> _reacting = [];

  @visibleForTesting
  static int get reactingCount => _reacting.length;

  /// The name from a decoration's rest art id.
  static String nameOf(String artId) => artId.split('.')[1];

  @override
  State<MapDecoration> createState() => _MapDecorationState();
}

class _MapDecorationState extends State<MapDecoration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _durationFor(_motion),
  )..addStatusListener(_onStatus);

  DecorationMotion get _motion =>
      decorationMotions[widget.name] ?? DecorationMotion.squash;

  static Duration _durationFor(DecorationMotion m) => switch (m) {
    DecorationMotion.tiltWobble => const Duration(milliseconds: 760),
    DecorationMotion.rotateWobble => const Duration(milliseconds: 900),
    DecorationMotion.withdraw => const Duration(milliseconds: 1100),
    DecorationMotion.leap => const Duration(milliseconds: 750),
    _ => const Duration(milliseconds: 650),
  };

  void _onStatus(AnimationStatus s) {
    // Only a finished reaction ends it: restarting from 0 passes through
    // "dismissed" on its way, and must not count.
    if (s == AnimationStatus.completed) {
      MapDecoration._reacting.remove(this);
      _c.value = 0;
    }
  }

  void _poke() {
    // Restart from wherever it is — never a second reaction behind this one.
    MapDecoration._reacting.remove(this);
    while (MapDecoration._reacting.length >= MapDecoration.maxReacting) {
      MapDecoration._reacting.removeAt(0)._rest();
    }
    MapDecoration._reacting.add(this);
    _c.forward(from: 0);
    widget.onPoke?.call(decorationSoundId(widget.name));
  }

  void _rest() {
    _c.stop();
    _c.value = 0;
  }

  @override
  void dispose() {
    MapDecoration._reacting.remove(this);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _poke,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => _frame(_c.value),
        ),
      ),
    );
  }

  String get _restArt => 'decoration.${widget.name}.rest';
  String get _hit => 'decoration.${widget.name}.hit';

  /// The decoration [t] (0 to 1) into its reaction. At 0 and 1, at rest.
  Widget _frame(double t) {
    final s = widget.size;
    if (t <= 0 || t >= 1) return ArtImage(_restArt);
    final w = HouseWobble.at(t);
    switch (_motion) {
      case DecorationMotion.tiltWobble:
        // Lean, lean the other way, lean, upright — each beat shorter: a
        // damped oscillation from two frames and a mirror.
        final (id, mirrored) = t < 0.28
            ? (_hit, false)
            : t < 0.52
            ? (_hit, true)
            : t < 0.7
            ? (_hit, false)
            : (_restArt, false);
        return _base(
          ArtImage(id, mirrored: mirrored),
          angle: 0.06 * w,
          scaleY: 1 - 0.05 * w.abs(),
        );
      case DecorationMotion.squash:
        final squashed = t < 0.3;
        return _base(
          ArtImage(squashed ? _hit : _restArt),
          scaleY: squashed ? 0.9 : 1 + 0.12 * w,
          scaleX: squashed ? 1.08 : 1 - 0.06 * w,
        );
      case DecorationMotion.rotateWobble:
        return _base(ArtImage(t < 0.35 ? _hit : _restArt), angle: 0.42 * w);
      case DecorationMotion.leap:
        final up = t < 0.65 ? math.sin(math.pi * t / 0.65) : 0.0;
        return _base(
          ArtImage(t < 0.65 ? _hit : _restArt),
          dy: -s * 0.55 * up,
          scaleY: t < 0.65 ? 1 : 1 - 0.1 * HouseWobble.at((t - 0.65) / 0.35),
        );
      case DecorationMotion.hop:
        final up = t < 0.5 ? math.sin(math.pi * t / 0.5) : 0.0;
        return _base(
          ArtImage(t < 0.7 ? _hit : _restArt),
          dy: -s * 0.14 * up,
          scaleY: 1 + 0.08 * w,
        );
      case DecorationMotion.withdraw:
        // Into its shell at once, a beat there, then back out with a small
        // squash.
        final inside = t < 0.7;
        return _base(
          ArtImage(inside ? _hit : _restArt),
          scaleY: inside ? 1 - 0.06 * (1 - t / 0.7) : 1 + 0.08 * w,
        );
      case DecorationMotion.flap:
        final beat = (t * 6).floor();
        return _base(
          ArtImage(beat.isEven ? _hit : _restArt),
          dy: -s * 0.18 * math.sin(math.pi * t),
        );
      case DecorationMotion.dart:
        final out = math.sin(math.pi * t);
        return _base(
          ArtImage(t < 0.8 ? _hit : _restArt),
          dx: s * 0.3 * out,
          dy: -s * 0.08 * out,
        );
    }
  }

  /// Transforms about the base, so things tip and squash from the ground.
  Widget _base(
    Widget child, {
    double angle = 0,
    double scaleX = 1,
    double scaleY = 1,
    double dx = 0,
    double dy = 0,
  }) => Transform.translate(
    offset: Offset(dx, dy),
    child: Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.identity()
        ..rotateZ(angle)
        ..scaleByDouble(scaleX, scaleY, 1, 1),
      child: child,
    ),
  );
}

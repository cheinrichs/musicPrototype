import 'package:flutter/widgets.dart';

/// Carries its [child] from [from] to [to] along the arc a hand would take —
/// lifted, then slid level onto its spot, not a straight line — shrinking or
/// growing from [fromScale] to [toScale] on the way.
///
/// **One primitive for every instrument flight** (Trello card 173, and the
/// drag-demonstration card after it): the gesture must look identical
/// wherever a child meets it, so it is built once here.
///
/// Positions are the child's *feet* (bottom centre) in the enclosing
/// [Stack]'s coordinates, and the scale is about the feet too, so whatever
/// lands stands on its new spot rather than hovering by half its height.
/// Must be a direct child of a [Stack]: it builds a [Positioned].
///
/// Flies once, when it first appears with [flying] true or when [flying]
/// turns true; set it false and the child is back at [from].
class ArcFlight extends StatefulWidget {
  final Offset from;
  final Offset to;
  final Size size;
  final double fromScale;
  final double toScale;
  final bool flying;
  final Duration duration;
  final Widget child;

  const ArcFlight({
    super.key,
    required this.from,
    required this.to,
    required this.size,
    this.fromScale = 1,
    this.toScale = 1,
    required this.flying,
    required this.duration,
    required this.child,
  });

  /// How far along the way across the arc does its rising, as a fraction of
  /// the horizontal distance: the curve lifts early and then levels off,
  /// arriving at [to] moving sideways — sliding onto a shelf rather than
  /// dropping onto it from above.
  ///
  /// Why sideways: with two instruments Clef sits on the top platform
  /// directly above the middle one (Trello card 188), so anything that came
  /// down onto the middle platform from above passed through him. Arriving
  /// level with the platform never rises above it. An earlier version that
  /// lifted over the top and set down swept through Clef on every phone.
  static const double riseShare = 0.35;

  /// The point [t] (0..1) of the way along the arc from [from] to [to]: a
  /// quadratic curve whose control point sits at [to]'s height, a
  /// [riseShare] of the way across — so it rises first, then levels, and
  /// never goes above the higher of its two ends.
  static Offset pointOnArc(Offset from, Offset to, double t) {
    final control = Offset(from.dx + (to.dx - from.dx) * riseShare, to.dy);
    final u = 1 - t;
    return from * (u * u) + control * (2 * u * t) + to * (t * t);
  }

  /// How much of the flight the size change takes: done in the first part,
  /// so it arrives already at its landed size and doesn't swell into what
  /// sits above the platform on the way in.
  static const Curve scaleCurve = Interval(0, 0.6, curve: Curves.easeOut);

  @override
  State<ArcFlight> createState() => _ArcFlightState();
}

class _ArcFlightState extends State<ArcFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.flying) _controller.forward();
  }

  @override
  void didUpdateWidget(ArcFlight old) {
    super.didUpdateWidget(old);
    _controller.duration = widget.duration;
    if (widget.flying && !old.flying) {
      _controller.forward(from: 0);
    } else if (!widget.flying && old.flying) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final t = _t.value;
        final feet = ArcFlight.pointOnArc(widget.from, widget.to, t);
        final s = ArcFlight.scaleCurve.transform(_controller.value);
        final scale =
            widget.fromScale + (widget.toScale - widget.fromScale) * s;
        return Positioned(
          left: feet.dx - widget.size.width / 2,
          top: feet.dy - widget.size.height,
          width: widget.size.width,
          height: widget.size.height,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
    );
  }
}

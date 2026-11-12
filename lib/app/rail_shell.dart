import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../journey/journey_art.dart';
import '../journey/journey_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/playground_screen.dart';

/// The rail's four destinations, top to bottom — and their column in the
/// icon sheet.
enum RailDestination { journey, games, crafts, playground }

/// The rail's geometry, shared so the Journey can aim a reward at an icon
/// and keep its map clear of the panel.
class RailLayout {
  final Size size;
  final EdgeInsets padding;
  const RailLayout(this.size, this.padding);

  /// One icon cell (circle and its label) is 456×431 in the sheet.
  static const double cellAspect = 431 / 456;
  static const double _gap = 6;

  /// As wide as fits four down the screen, at most 13% of its width (the
  /// composite's rail fills the height).
  double get itemWidth {
    final room = size.height - padding.top - padding.bottom - 16 - 3 * _gap;
    return math.min(size.width * 0.13, room / 4 / cellAspect);
  }

  double get itemHeight => itemWidth * cellAspect;

  /// The panel runs to the screen's edge, under the notch's inset.
  double get panelWidth => itemWidth + 20 + padding.right;

  Offset centreOf(RailDestination d) {
    final x = size.width - padding.right - 10 - itemWidth / 2;
    final total = 4 * itemHeight + 3 * _gap;
    final top =
        padding.top + (size.height - padding.top - padding.bottom - total) / 2;
    return Offset(x, top + itemHeight / 2 + d.index * (itemHeight + _gap));
  }

  /// Where a reward lands: on the icon's circle (the upper part of the
  /// cell, above the label).
  Offset landingOf(RailDestination d) =>
      centreOf(d) - Offset(0, itemHeight * 0.12);
}

/// A reward on its way somewhere, along a lifted arc with a golden trail.
class RewardFlight {
  final Widget child;
  final Offset from;
  final Offset to;
  final Duration duration;
  final double size;
  final double fromScale;
  final double toScale;
  final double lift;
  final bool trail;
  final VoidCallback? onLanded;
  RewardFlight({
    required this.child,
    required this.from,
    required this.to,
    required this.duration,
    required this.size,
    required this.fromScale,
    required this.toScale,
    required this.lift,
    this.trail = false,
    this.onLanded,
  });
}

/// What a screen inside the shell can ask of it: hide the rail while a game
/// plays, fly rewards above it, make an icon receive one.
class RailController extends ChangeNotifier {
  RailDestination _selected;
  bool _immersive = false;
  final List<RewardFlight> _flights = [];
  final Map<RailDestination, int> _pulses = {};

  RailController([this._selected = RailDestination.journey]);

  RailDestination get selected => _selected;
  bool get immersive => _immersive;
  List<RewardFlight> get flights => List.unmodifiable(_flights);
  int pulsesOf(RailDestination d) => _pulses[d] ?? 0;

  void select(RailDestination d) {
    if (d == _selected) return;
    _selected = d;
    notifyListeners();
  }

  set immersive(bool v) {
    if (v == _immersive) return;
    _immersive = v;
    notifyListeners();
  }

  void fly(RewardFlight f) {
    _flights.add(f);
    notifyListeners();
  }

  void land(RewardFlight f) {
    _flights.remove(f);
    notifyListeners();
  }

  void clearFlights() {
    _flights.clear();
    notifyListeners();
  }

  /// The icon bounces as a reward arrives.
  void pulse(RailDestination d) {
    _pulses[d] = pulsesOf(d) + 1;
    notifyListeners();
  }
}

/// The child's top level: the rail of four destinations down the right —
/// Journey, Games, Crafts, Playground — with Journey selected on arrival.
///
/// The panel is a solid dark forest green taken from the scene's own
/// palette, as in Cooper's composite. Destinations are built when first
/// visited and kept alive after.
class RailShell extends StatefulWidget {
  final RailDestination initial;
  const RailShell({super.key, this.initial = RailDestination.journey});

  @override
  State<RailShell> createState() => _RailShellState();
}

class _RailShellState extends State<RailShell> {
  late final RailController _rail = RailController(widget.initial);
  final Set<RailDestination> _visited = {};

  static const panelGreen = Color(0xFF1E3A22);

  @override
  void dispose() {
    _rail.dispose();
    super.dispose();
  }

  Widget _destination(RailDestination d, RailLayout l) {
    // Journey lays its map out around the panel itself; the others keep
    // clear of it.
    if (d == RailDestination.journey) return const JourneyScreen();
    return Padding(
      padding: EdgeInsets.only(right: l.panelWidth),
      child: switch (d) {
        RailDestination.games => const HomeScreen(),
        RailDestination.playground => const PlaygroundScreen(),
        _ => const _CraftsPlaceholder(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = RailLayout(
      MediaQuery.sizeOf(context),
      MediaQuery.paddingOf(context),
    );
    return ChangeNotifierProvider.value(
      value: _rail,
      child: Consumer<RailController>(
        builder: (context, rail, _) {
          _visited.add(rail.selected);
          return Scaffold(
            backgroundColor: panelGreen,
            body: Stack(
              fit: StackFit.expand,
              children: [
                IndexedStack(
                  index: rail.selected.index,
                  children: [
                    for (final d in RailDestination.values)
                      _visited.contains(d)
                          ? _destination(d, l)
                          : const SizedBox.shrink(),
                  ],
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  top: 0,
                  bottom: 0,
                  width: l.panelWidth,
                  right: rail.immersive ? -l.panelWidth : 0,
                  child: _RailPanel(layout: l, rail: rail),
                ),
                for (final f in rail.flights)
                  RewardFlightView(key: ObjectKey(f), flight: f),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RailPanel extends StatelessWidget {
  final RailLayout layout;
  final RailController rail;
  const _RailPanel({required this.layout, required this.rail});

  @override
  Widget build(BuildContext context) {
    final l = layout;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _RailShellState.panelGreen,
        border: Border(left: BorderSide(color: Color(0xFF2E5233), width: 2)),
      ),
      child: Stack(
        children: [
          for (final d in RailDestination.values)
            Positioned(
              // Centres are in screen coordinates; the panel's left edge is
              // at size.width - panelWidth.
              left:
                  l.centreOf(d).dx -
                  (l.size.width - l.panelWidth) -
                  l.itemWidth / 2 -
                  6,
              top: l.centreOf(d).dy - l.itemHeight / 2 - 4,
              width: l.itemWidth + 12,
              height: l.itemHeight + 8,
              child: GestureDetector(
                key: ValueKey('rail-${d.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => rail.select(d),
                child: _RailItem(
                  destination: d,
                  selected: rail.selected == d,
                  pulses: rail.pulsesOf(d),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final RailDestination destination;
  final bool selected;
  final int pulses;
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.pulses,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The selected destination sits on a cream plate (the composite's
        // Journey). Drawn, not the rounded-square icon art.
        AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF4E6BF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD9B66A), width: 2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          // Bounces each time a reward lands on it.
          child: TweenAnimationBuilder<double>(
            key: ValueKey(pulses),
            tween: Tween(begin: pulses == 0 ? 1 : 1.18, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
            builder: (context, s, child) =>
                Transform.scale(scale: s, child: child),
            child: RailIcon(destination: destination.index),
          ),
        ),
      ],
    );
  }
}

/// Crafts has nowhere to go yet.
class _CraftsPlaceholder extends StatelessWidget {
  const _CraftsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFBDBDBD),
      alignment: Alignment.center,
      child: const Text(
        'Crafts (placeholder)',
        style: TextStyle(fontSize: 22, color: Colors.white),
      ),
    );
  }
}

/// Draws a [RewardFlight]: the reward along a lifted quadratic arc, and
/// (when asked) the golden trail it leaves, as in the composite.
class RewardFlightView extends StatelessWidget {
  final RewardFlight flight;
  const RewardFlightView({super.key, required this.flight});

  static Offset at(RewardFlight f, double t) {
    final control = Offset.lerp(f.from, f.to, 0.5)! - Offset(0, f.lift);
    return f.from * ((1 - t) * (1 - t)) +
        control * (2 * (1 - t) * t) +
        f.to * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    final f = flight;
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: f.duration,
        curve: Curves.easeInOutCubic,
        onEnd: f.onLanded,
        builder: (context, t, child) {
          final p = at(f, t);
          final s = f.fromScale + (f.toScale - f.fromScale) * t;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (f.trail) CustomPaint(painter: _TrailPainter(f, t)),
              Positioned(
                left: p.dx - f.size / 2,
                top: p.dy - f.size / 2,
                width: f.size,
                height: f.size,
                child: Transform.scale(scale: s, child: child),
              ),
            ],
          );
        },
        child: f.child,
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  final RewardFlight flight;
  final double t;
  _TrailPainter(this.flight, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    // The trail follows the last stretch of the arc behind the reward.
    final start = math.max(0.0, t - 0.45);
    final path = Path();
    const steps = 24;
    for (var i = 0; i <= steps; i++) {
      final p = RewardFlightView.at(flight, start + (t - start) * i / steps);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0x66FFD54F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFE9A0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.t != t;
}

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../app/art_registry.dart';

/// How a character moves between stones on the Journey (Trello 227).
///
/// ⚠️ EACH SHEET PLAYS EXACTLY AS EXPORTED, ON ITS OWN BASELINES — no code
/// lift on either character (Cooper, 2026-11-20). The two sheets differ
/// because the characters move differently BY DESIGN:
///
/// - PIPER WALKS. Her three frames share one foot line (y = 712); her feet
///   stay on the ground and she only travels across.
/// - CLEF HOPS. She is a floating clef. Her frame 2 is drawn 81 px up (feet
///   at y = 634 against 715): that IS the hop, so it is in the art.
///
/// Each frame is drawn from its whole third of the sheet, top to bottom
/// (thirds are clear on these sheets: SLICE_POINTS.json), so where Cooper
/// put the figure in its frame is where it is drawn — the sheet's own
/// registration, untouched.
@immutable
class Gait {
  final String asset;
  final Size sheet;

  /// Where the standing feet are on the sheet, in px from the top: what
  /// lands on the character's ground line.
  final double footY;

  /// The standing frame's body height, in sheet px (near-opaque pixels).
  final double bodyHeight;

  /// The frames one cycle plays, in order (indices into the three).
  final List<int> cycle;

  /// How long one cycle takes.
  final Duration cycleLength;

  /// True when one cycle is one HOP: the cycles fit the trip a whole
  /// number of times and each carries its own share of the distance, so
  /// the frames and the travel are in phase. False for a WALK: the frames
  /// cycle under a steady glide.
  final bool hops;

  const Gait({
    required this.asset,
    required this.sheet,
    required this.footY,
    required this.bodyHeight,
    required this.cycle,
    required this.cycleLength,
    required this.hops,
  });

  /// Piper's walk: standing, knees bent, striding, knees bent.
  static const piperWalk = Gait(
    asset: 'assets/images/characters/piper/piper_H_move_x3.png',
    sheet: Size(2172, 724),
    footY: 712,
    bodyHeight: 705,
    cycle: [0, 1, 2, 1],
    cycleLength: Duration(milliseconds: 520),
    hops: false,
  );

  /// Clef's hop: take-off, airborne (frame 2, the lift drawn in), landing.
  static const clefHop = Gait(
    asset: 'assets/images/characters/clef/clef_H_move_x3.png',
    sheet: Size(2172, 724),
    footY: 715,
    bodyHeight: 672,
    cycle: [0, 1, 2],
    cycleLength: Duration(milliseconds: 600),
    hops: true,
  );

  double get frameWidth => sheet.width / 3;

  ArtRef frame(int i) => ArtRef(
    asset,
    image: sheet,
    region: Rect.fromLTWH(i * frameWidth, 0, frameWidth, sheet.height),
  );
}

/// One traveller on the map — a companion or the avatar pin. At rest it
/// shows [rest] in [rect]. When [rect] changes it travels there over
/// [duration]: a [gait] plays its frames on the way (in phase with the
/// travel for a hop), and a gait-less traveller (the pin) rises on a
/// small [arc] instead. A hop eases into its landing frame; then every
/// traveller is back in its resting pose for a beat before anything else
/// moves, so it settles rather than stopping dead.
class Traveller extends StatefulWidget {
  /// Where it rests: its feet are this box's bottom centre.
  final Rect rect;
  final Widget rest;
  final Gait? gait;

  /// The travelling figure's body height, in screen px, for [gait].
  final double bodyHeight;

  /// For a gait-less traveller: the arc's peak, as a share of its height.
  final double arc;
  final Duration duration;

  const Traveller({
    super.key,
    required this.rect,
    required this.rest,
    this.gait,
    this.bodyHeight = 0,
    this.arc = 0,
    required this.duration,
  });

  /// The beat of rest on arrival, before the trip counts as over.
  static const settle = Duration(milliseconds: 160);

  @override
  State<Traveller> createState() => _TravellerState();
}

class _TravellerState extends State<Traveller>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this)
    ..addListener(() => setState(() {}));
  // Set in initState, NOT lazily: a lazy initialiser first read inside
  // didUpdateWidget would see the NEW rect and the trip would never start.
  late Rect _from;
  late Rect _to;
  int _cycles = 1;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.rect;
  }

  @override
  void didUpdateWidget(Traveller old) {
    super.didUpdateWidget(old);
    if (widget.rect == _to) return;
    _from = _rectAt(_t.isAnimating ? _t.value : 1);
    _to = widget.rect;
    final g = widget.gait;
    final travel = widget.duration;
    _cycles = g == null
        ? 1
        : math.max(
            1,
            (travel.inMilliseconds / g.cycleLength.inMilliseconds).round(),
          );
    _t.duration = travel + Traveller.settle;
    _t.forward(from: 0);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  /// Share of the trip that is travel; the rest is the settle.
  double get _travelShare =>
      widget.duration.inMicroseconds /
      (widget.duration + Traveller.settle).inMicroseconds;

  /// Progress along the trip, 0-1, at controller value [v].
  double _along(double v) {
    final p = (v / _travelShare).clamp(0.0, 1.0);
    final g = widget.gait;
    if (g == null || !g.hops) return Curves.easeInOut.transform(p);
    // A hop moves its share of the distance while it is in the air, so the
    // travel and the frames stay in phase: one hop, one step forward.
    final n = _cycles;
    final hop = math.min((p * n).floor(), n - 1);
    final inHop = p * n - hop;
    return (hop + Curves.easeInOut.transform(inHop)) / n;
  }

  Rect _rectAt(double v) => Rect.lerp(_from, _to, _along(v))!;

  /// The frame showing at controller value [v], or null at rest.
  int? _frameAt(double v) {
    final g = widget.gait;
    if (g == null || !_t.isAnimating) return null;
    final p = v / _travelShare;
    // The settle: their resting pose. Piper's sheet has no standing frame
    // (all three are steps), and Clef lands on her own landing frame first.
    if (p >= 1) return null;
    final c = p * _cycles;
    final inCycle = c - c.floor();
    return g.cycle[(inCycle * g.cycle.length).floor() % g.cycle.length];
  }

  @override
  Widget build(BuildContext context) {
    final v = _t.value;
    var r = _t.isAnimating ? _rectAt(v) : widget.rect;
    if (widget.gait == null && _t.isAnimating && widget.arc > 0) {
      final p = (v / _travelShare).clamp(0.0, 1.0);
      r = r.shift(Offset(0, -widget.arc * r.height * 4 * p * (1 - p)));
    }
    final frame = _frameAt(v);
    if (frame == null) return Positioned.fromRect(rect: r, child: widget.rest);
    final g = widget.gait!;
    final k = widget.bodyHeight / g.bodyHeight;
    final feet = r.bottomCenter;
    return Positioned(
      left: feet.dx - g.frameWidth / 2 * k,
      top: feet.dy - g.footY * k,
      width: g.frameWidth * k,
      height: g.sheet.height * k,
      child: ImageRegion(art: g.frame(frame)),
    );
  }
}

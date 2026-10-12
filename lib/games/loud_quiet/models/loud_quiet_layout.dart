import 'dart:math' as math;

import 'package:flutter/painting.dart';
import '../../high_low/models/high_low_instrument.dart';
import '../../high_low/widgets/character_art.dart';

/// Where everything in the Loud or Quiet scene sits (Trello card 162), as
/// pure geometry so it can be tested at real phone sizes.
///
/// The same grammar as High vs Low: Piper on the ground at the left, the
/// instruments on stumps through the middle, and the apparatus on the right —
/// here the **dial** (`DialFace.png`, with `DialNeedle.png` on its hub)
/// instead of the tree. Clef owns LOUD and Piper QUIET, the same poles as
/// high and low.
///
/// **Built directly, not on a shared template** (card 162: extract from two
/// real examples, not one). Deliberately duplicated from `SceneLayout`, to be
/// compared when the template is extracted: the edge margin and gaps, Piper's
/// placement (left inset, feet below the frame, widest-pose width), the
/// stumps' ground line and band, the instrument box and touch floor.
///
/// **The dial can't be the approved 92% of the screen height on any phone**
/// alongside Piper and two instruments at the touch floor — it is 1.5 times
/// as wide as it is tall, so at 92% it takes over half the screen's width,
/// and its quiet-end slot reaches out to the left of its platform, which has
/// to stay a finger's slip from the nearest instrument. The order things
/// give way: the touch floor and that slip gap never; then the dial is as
/// large as fits (up to 92%) with Piper at her pre-card-192 half height; then
/// any room left goes to Piper (up to three-quarters). Measured: 56% of the
/// height on an SE, 71% on an iPhone 14, 68% on an iPhone 17, 76% on a Pro
/// Max, with Piper at half height on all of them. For Cooper to judge.
class LoudQuietLayout {
  // ---- the dial art, measured off DialFace.png (1536 x 1024) ----

  /// Natural proportions of `DialFace.png`.
  static const faceAspect = 1536 / 1024;

  /// The hub's centre hole, where the needle turns, as fractions of the
  /// face. **Measured off the art on a fine grid (2026-10-12): 51.1% across,
  /// 70.6% down.** The props README and card 180 give 52.0% / 72.7%, which
  /// lands about 14 px right and 21 px below the hole in the 1536 x 1024
  /// image — enough to sit the needle's boss visibly off the hub. Using the
  /// hole; one constant to change if the composite says otherwise.
  static const hub = Offset(0.511, 0.706);

  /// The three platforms on top of the dial, left (quiet end) to right (loud
  /// end), the middle of each flat face as fractions of the face — measured
  /// off the art on a grid (2026-10-12).
  static const platformCentres = [
    Offset(0.281, 0.327),
    Offset(0.512, 0.200),
    Offset(0.762, 0.322),
  ];

  /// Width of each platform's top face, as a fraction of the face's width.
  static const platformWidths = [0.147, 0.160, 0.146];

  /// The quiet end's platform: the near side, nearest the instruments.
  static const int quietPlatform = 0;

  /// Where Clef sits: the middle platform, which two instruments never use —
  /// "this one is taken", as on the tree (card 188).
  static const int clefPlatform = 1;

  /// The loud end's platform: the far side. ⚠️ The Decide lines say "the far
  /// side" for loud and "the near side" for quiet (card 182), which is true
  /// only while the loud end is the one further from the instruments. Never
  /// mirror the dial.
  static const int loudPlatform = 2;

  /// The right-hand edge of the loud platform's face, as a fraction of the
  /// face's width: it must stay on screen, inside the safe area.
  static const _loudPlatformRight = 0.835;

  /// Left of this (as a fraction of the face's width) the face is roots and
  /// leaves; the quiet zone of the arc starts just after. The instruments
  /// may stand in front of that much of the dial, no further.
  static const _faceFreeLeft = 0.20;

  /// The needle's swing either side of straight up, in degrees: the quiet and
  /// loud zones' centres are about 55-58° from vertical as seen from the hub,
  /// and card 180 found 60° too wide (the tip dropped past the orange band).
  /// To set by eye against the art on a device.
  static const double sweepDegrees = 55;

  /// The needle at rest — the dial's zero, below the quietest (card 208):
  /// nearly flat at the bottom of the quiet end of the arc, so the quietest
  /// sound is the shortest movement and the loudest the longest. Measured
  /// on the renders, the face's zone boundaries sit about ±30° from
  /// vertical, so −85° is under the quiet zone, a wide round's quiet sound
  /// (−65°) lands mid-quiet, a narrow one's (−5°) mid-scale, loud (+55°) in
  /// the loud zone. The art points straight up at 0°, so this is a
  /// start-angle offset; the pivot is unchanged. To set by eye on a device.
  static const double restDegrees = -85;

  /// The needle's angle for a dial position: 0 rest, 1 the loud end
  /// ([sweepDegrees]).
  static double needleDegrees(double position) =>
      restDegrees + position * (sweepDegrees - restDegrees);

  // ---- the needle art, DialNeedle.png (1024 x 1536) ----

  static const needleAspect = 1024 / 1536;

  /// The needle's pivot, as fractions of its image: NOT its centre (README:
  /// rotating about the centre wobbles). 49.7% across, 81.3% down — the
  /// boss's hole, confirmed on the art.
  static const needlePivot = Offset(0.497, 0.813);

  /// The needle's tip, as a fraction of its image's height (first opaque
  /// row).
  static const _needleTipY = 79 / 1536;

  /// Pivot-to-tip as a fraction of the face's rendered width: about 21%
  /// (card 180 — at double that it overshoots the arc and lies across the
  /// zone it points at).
  static const _needleReach = 0.21;

  final Size screen;
  final EdgeInsets insets;

  const LoudQuietLayout(this.screen, {this.insets = EdgeInsets.zero});

  /// The smallest box a small child's finger can be expected to hit, as on
  /// High vs Low: the smallest instrument (bells, at half size) never falls
  /// below it.
  static const double minTouchTarget = 64;

  /// A finger slipping during a tap must never reach a drop slot (card
  /// L00pxs7q's guard on the tree, applied here from the start).
  static const double _slip = 48;

  double get _margin => screen.width * 0.02;
  double get _gap => _margin / 2;

  static final double _smallestScale = HighLowInstrument.values
      .map((i) => i.displaySizeScale)
      .reduce(math.min);

  /// The band two instruments need at the floor.
  static double get _needForInstruments => 2 * minTouchTarget / _smallestScale;

  // ---- the dial ----

  double get dialHeight => _dialHeightFor(screen.height * 0.5);

  /// The tallest dial, up to 92% of the height, that leaves room for two
  /// instruments at the floor beside a Piper of [piperHeight].
  double _dialHeightFor(double piperHeight) {
    final ideal = screen.height * 0.92;
    if (_roomFor(ideal, piperHeight) >= 0) return ideal;
    var lo = 0.0, hi = ideal;
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (_roomFor(mid, piperHeight) >= 0) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Spare width in the instruments' band for a dial [h] tall and a Piper
  /// [piperHeight] tall, once two instruments at the floor are placed.
  double _roomFor(double h, double piperHeight) =>
      _bandRightFor(h) - _bandLeftFor(piperHeight) - _needForInstruments;

  double get dialWidth => dialHeight * faceAspect;

  /// Bottom on the screen's bottom; pushed right as far as keeps the loud
  /// platform inside the safe area, cropping the rest off the right.
  Rect get dialRect => _dialRectFor(dialHeight);

  Rect _dialRectFor(double h) {
    final w = h * faceAspect;
    final left = screen.width - insets.right - _margin - _loudPlatformRight * w;
    return Rect.fromLTWH(left, screen.height - h, w, h);
  }

  Offset _onFace(Offset f) => Offset(
    dialRect.left + f.dx * dialWidth,
    dialRect.top + f.dy * dialHeight,
  );

  /// Where the needle turns, on screen.
  Offset get hubPoint => _onFace(hub);

  /// The middle of platform [index]'s face (0 = quiet end, 2 = loud end).
  Offset platform(int index) => _onFace(platformCentres[index]);

  /// Where the caption's meadow ends: the dial's left edge.
  double get meadowRight => dialRect.left;

  // ---- the needle ----

  /// The needle's drawn size: its pivot-to-tip is [_needleReach] of the
  /// face's width.
  Size get needleSize {
    final h = _needleReach * dialWidth / (needlePivot.dy - _needleTipY);
    return Size(h * needleAspect, h);
  }

  /// Where to place the needle image so its pivot sits on [hubPoint].
  Rect get needleRect {
    final s = needleSize;
    return Rect.fromLTWH(
      hubPoint.dx - needlePivot.dx * s.width,
      hubPoint.dy - needlePivot.dy * s.height,
      s.width,
      s.height,
    );
  }

  /// The needle's tip at [degrees] from straight up (positive = toward the
  /// loud end).
  Offset needleTip(double degrees) {
    final a = degrees * math.pi / 180;
    final r = _needleReach * dialWidth;
    return hubPoint + Offset(math.sin(a), -math.cos(a)) * r;
  }

  // ---- the characters ----

  /// Clef's size, on his platform.
  double get characterHeight => screen.height * 0.24;

  Offset get clefPerch => platform(clefPlatform);

  /// Piper: as big as the room the dial leaves, up to three-quarters of the
  /// height, never less than half.
  double get piperHeight {
    final room =
        _bandRightFor(dialHeight) -
        insets.left -
        _margin -
        _gap -
        _needForInstruments;
    final widestPerHeight = _widestPose(CharacterArt.piper, 1);
    return math.max(
      screen.height * 0.5,
      math.min(screen.height * 0.75, room / widestPerHeight),
    );
  }

  double get piperFeetY => screen.height + piperHeight * 0.05;

  double get piperLeftInset {
    final frame = _spriteWidth(CharacterArt.piper, piperHeight);
    final widest = _widestPose(CharacterArt.piper, piperHeight);
    return insets.left + _margin + (widest - frame) / 2;
  }

  double get piperRight =>
      insets.left + _margin + _widestPose(CharacterArt.piper, piperHeight);

  Rect piperBounds({double pulse = 0}) {
    final frame = _spriteWidth(CharacterArt.piper, piperHeight);
    final centre = piperLeftInset + frame / 2;
    final w = _widestPose(CharacterArt.piper, piperHeight) * (1 + pulse);
    final h = piperHeight * (1 + pulse);
    return Rect.fromLTWH(centre - w / 2, piperFeetY - h, w, h);
  }

  Rect clefBounds({double pulse = 0}) {
    final w = _widestPose(CharacterArt.clef, characterHeight) * (1 + pulse);
    final h = characterHeight * (1 + pulse);
    return Rect.fromLTWH(clefPerch.dx - w / 2, clefPerch.dy - h, w, h);
  }

  static double _spriteWidth(CharacterArt art, double height) =>
      art.frameSize.width * height / art.frameSize.height;

  static double _widestPose(CharacterArt art, double height) {
    final widest = [
      art.frameSize.width,
      art.celebrationSize.width,
      art.thinkingSize.width,
    ].reduce(math.max);
    return widest * height / art.frameSize.height;
  }

  // ---- the drop slots ----

  /// The platform a round's slot sits on: the loud end for a loud round, the
  /// quiet end for a quiet one.
  int slotPlatformFor({required bool loud}) =>
      loud ? loudPlatform : quietPlatform;

  /// Height of an instrument standing on a platform — about what one placed
  /// on High vs Low's tree measures on screen (0.15 of the screen's height),
  /// since only one ever lands here and there is nothing to stack against.
  double get placedSize => dialHeight * 0.22;

  Size get slotSize =>
      Size(platformWidths.reduce(math.min) * dialWidth, dialHeight * 0.06);

  /// The drop target over platform [index], generous as on the tree.
  Rect slotRect(int index) => _slotRectFor(dialHeight, index);

  Rect _slotRectFor(double h, int index) {
    final face = _dialRectFor(h);
    final w = h * faceAspect;
    final c = Offset(
      face.left + platformCentres[index].dx * w,
      face.top + platformCentres[index].dy * h,
    );
    final sw = platformWidths.reduce(math.min) * w * 1.35;
    final sh = h * 0.15;
    return Rect.fromLTWH(c.dx - sw / 2, c.dy - sh * 0.8, sw, sh);
  }

  // ---- the instruments ----

  /// Distance from the bottom of the screen up to every stump's surface: the
  /// same ground line as High vs Low.
  double get groundY => screen.height * 0.225;

  double _bandLeftFor(double piperHeight) =>
      insets.left +
      _margin +
      _widestPose(CharacterArt.piper, piperHeight) +
      _gap;

  /// The band ends where the dial's arc begins, and a finger's slip before
  /// the quiet end's slot.
  double _bandRightFor(double h) {
    final face = _dialRectFor(h);
    final beforeArc = face.left + _faceFreeLeft * face.width;
    final beforeSlot = _slotRectFor(h, quietPlatform).left - _slip;
    return math.min(beforeArc, beforeSlot) - _gap;
  }

  double get _bandLeft => piperRight + _gap;
  double get _bandRight => _bandRightFor(dialHeight);

  /// Instrument box size: 0.38 of the height, as on High vs Low, capped so
  /// two fit the band without overlapping.
  double get instrumentSize =>
      math.min(screen.height * 0.38, (_bandRight - _bandLeft) / 2);

  double get _pitch {
    final fit = _bandRight - _bandLeft - instrumentSize;
    final airy = instrumentSize * 1.12;
    return fit < airy ? fit : airy;
  }

  /// Horizontal centre of instrument [index]'s stump, the pair centred in
  /// the band.
  double stumpAnchorX(int index) {
    final groupWidth = instrumentSize + _pitch;
    final groupLeft = (_bandLeft + _bandRight - groupWidth) / 2;
    return groupLeft + instrumentSize / 2 + index * _pitch;
  }

  /// Instrument [index]'s box (feet on the ground line).
  Rect instrumentBox(int index) => Rect.fromCenter(
    center: Offset(
      stumpAnchorX(index),
      screen.height - groundY - instrumentSize / 2,
    ),
    width: instrumentSize,
    height: instrumentSize,
  );

  /// Where Observe's earned arrow sits: between the last instrument and the
  /// dial's arc.
  static const double arrowSize = 72;
  Offset get arrowCentre => Offset(
    (instrumentBox(1).right + dialRect.left + _faceFreeLeft * dialWidth) / 2,
    screen.height - groundY - instrumentSize * 0.4,
  );
}

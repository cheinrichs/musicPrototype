import 'dart:math' as math;

import 'package:flutter/painting.dart';
import '../widgets/character_art.dart';

/// Where everything in the High/Low scene sits, as pure geometry so the rules
/// that keep going wrong on a real device can be tested at real screen sizes
/// (including a notched phone's side insets).
///
/// **The composition (Trello card 187, decided with Cooper 2026-10-04/05):**
/// Piper on the ground at the left edge, the instruments through the middle,
/// and the tree with Clef on the right:
///
/// - the **tree** (`PitchTree_v2.png`) stands at **full screen height, pushed
///   right so a quarter of its width hangs off the right edge**. Smaller does
///   not work, and that was tested at 55%, 65%, 80% and full height: the
///   platforms are about a tenth of the image's width, so at any size where
///   the canopy stays clear of the meadow they are too small to aim an
///   instrument at. What the crop removes is only trunk and a hollow;
/// - **Clef sits on the branch reaching left** — the bare stretch of it, not
///   on a platform, so all three platforms are free to be slots;
/// - **Piper stands at the left edge, on the ground, at foreground scale**
///   (she used to stand right of the tree; the crop removed that ground);
/// - the **instruments stand on stumps between them**, set back in space —
///   higher up the screen and smaller — on the same floor as the tree's base.
///
/// The high/low reading survives the move: Clef is up the tree, Piper is on
/// the ground.
///
/// **The drop target is a slot on the tree, not a character** (2026-09-27).
/// Dragging to a slot near the top of the tree means *high* because it is
/// physically up there — the action becomes the concept. With Clef off the
/// platforms, the high slot is the top platform and the low slot the bottom
/// one: the widest contrast three platforms allow. See
/// `HighLowScreen._buildTreeSlot`.
///
/// **The tree's platforms are receptacles only where something can be
/// placed.** An empty slot on a screen where nothing can be placed is a false
/// affordance a small child will spend real time failing at, so this class
/// only knows where the platforms are; the screen decides when to draw one.
///
/// The ordering screen still uses the previous tree — see
/// `OrderingTreeScene`.
class SceneLayout {
  // ---- the tree art, measured off PitchTree_v2.png (1536 x 1024) ----

  /// Natural proportions of `PitchTree_v2.png`.
  static const treeAspect = 1536 / 1024;

  /// How much of the tree's width hangs off the right edge of the screen.
  static const treeOffscreenFraction = 0.25;

  /// The middle of each platform's flat top face, top to bottom, as fractions
  /// of the tree's width and height — measured off the art on a grid
  /// (2026-10-06), where a foot belongs. The props README's "44%, 60% and
  /// 76%" are the same platforms, rounded.
  static const platformCentres = [
    Offset(0.531, 0.444),
    Offset(0.554, 0.595),
    Offset(0.566, 0.739),
  ];

  /// Width of each platform's top face, as a fraction of the tree's width.
  static const platformWidths = [0.119, 0.115, 0.111];

  /// Where Clef's feet go: the top of the bare stretch of the branch reaching
  /// left, which runs from about 0.27 to 0.38 of the tree's width with its top
  /// surface at 0.423 of its height. Nearer the trunk than the middle of that
  /// stretch, which leaves the instruments more room: on an SE the band
  /// between Piper and Clef is what sets their size.
  static const perch = Offset(0.355, 0.423);

  /// The left edge of the platform column, as a fraction of the tree's width
  /// (the top platform's face starts here). Nothing on the ground may reach
  /// right of this, or it covers a slot.
  static const platformColumnLeft = 0.472;

  final Size screen;
  final EdgeInsets insets;

  /// How many instruments stand on stumps (2 or 3).
  final int noteCount;

  /// Instrument box size as a fraction of screen height, before the band
  /// between Piper and the tree caps it (see [instrumentSize]).
  ///
  /// Down from 0.50 (Trello card 187: the stumps move up AND get smaller, so
  /// they sit back in space — further away is both). How far down is set by
  /// the touch-target floor, not by looks: see [minTouchTarget].
  final double instrumentFraction;

  const SceneLayout(
    this.screen, {
    this.insets = EdgeInsets.zero,
    required this.noteCount,
    this.instrumentFraction = 0.38,
  }) : assert(noteCount == 2 || noteCount == 3);

  /// The smallest box a small child's finger can be expected to hit reliably,
  /// in logical pixels. The smallest instrument (the bells, drawn at half
  /// size) must never fall below it. This is the constraint on how far back
  /// the stumps can go.
  static const double minTouchTarget = 64;

  /// Space kept clear at each screen edge beyond the device's own inset.
  double get _margin => screen.width * 0.02;

  // ---- the tree ----

  double get treeHeight => screen.height;
  double get treeWidth => treeHeight * treeAspect;

  Rect get treeRect => Rect.fromLTWH(
    screen.width - (1 - treeOffscreenFraction) * treeWidth,
    0,
    treeWidth,
    treeHeight,
  );

  /// The middle of platform [index]'s top face (0 = top): where feet go.
  Offset platform(int index) => Offset(
    treeRect.left + platformCentres[index].dx * treeWidth,
    treeRect.top + platformCentres[index].dy * treeHeight,
  );

  /// Width of platform [index]'s top face, in screen pixels.
  double platformFaceWidth(int index) => platformWidths[index] * treeWidth;

  /// The screen x at which the platform column begins.
  double get platformColumnLeftX =>
      treeRect.left + platformColumnLeft * treeWidth;

  // ---- the characters ----

  /// Clef's feet: on the branch.
  Offset get clefPerch => Offset(
    treeRect.left + perch.dx * treeWidth,
    treeRect.top + perch.dy * treeHeight,
  );

  /// Clef's size, on his branch.
  double get characterHeight => screen.height * 0.24;

  /// Drawn width of a character sprite of [art] at [height].
  double spriteWidth(CharacterArt art, double height) =>
      art.frameSize.width * height / art.frameSize.height;

  /// Half Clef's drawn width, at his widest pose.
  double get _clefHalfWidth =>
      _widestPose(CharacterArt.clef, characterHeight) / 2;

  /// Piper's height, standing at the left edge — a clearly larger,
  /// "foreground" scale than [characterHeight], so she reads as closer to the
  /// viewer than anything on the tree.
  double get piperHeight => screen.height * 0.50;

  /// Where Piper's feet sit: past the bottom of the screen by a sliver of her
  /// own height, so her ankles at most are cropped (Cooper: "we should only
  /// cut off her feet at most").
  double get piperFeetY => screen.height + piperHeight * 0.05;

  /// Piper's `Positioned.left`: the device's own inset plus a margin, measured
  /// to her *widest* pose — her celebration and thinking art is wider than her
  /// mouth frames and drawn centred on them, so it reaches left of the
  /// sprite's own box.
  double get piperLeftInset {
    final frame = spriteWidth(CharacterArt.piper, piperHeight);
    final widest = _widestPose(CharacterArt.piper, piperHeight);
    return insets.left + _margin + (widest - frame) / 2;
  }

  /// The right edge of Piper at her widest pose. Her celebration and thinking
  /// art is wider than her mouth frames and is drawn centred on them, so it
  /// reaches past the sprite's own box on both sides.
  double get piperRight {
    final frame = spriteWidth(CharacterArt.piper, piperHeight);
    final widest = _widestPose(CharacterArt.piper, piperHeight);
    return piperLeftInset + frame / 2 + widest / 2;
  }

  /// The widest of [art]'s poses, drawn at [height] — they share one scale
  /// (see `CharacterSprite`), so this is the frame-height scale applied to
  /// the widest image.
  static double _widestPose(CharacterArt art, double height) {
    final scale = height / art.frameSize.height;
    final widest = [
      art.frameSize.width,
      art.celebrationSize.width,
      art.thinkingSize.width,
    ].reduce(math.max);
    return widest * scale;
  }

  // ---- the tree slot (the drop target — see the class doc) ----

  /// Which platform holds the slot for a high-pole round: the top one.
  static const int highSlotPlatform = 0;

  /// Which platform holds the slot for a low-pole round: the bottom one.
  static const int lowSlotPlatform = 2;

  /// The platform this round's slot sits on.
  int slotPlatformFor({required bool isPiperTarget}) =>
      isPiperTarget ? lowSlotPlatform : highSlotPlatform;

  /// A slot's footprint on its platform: the narrowest face, so one size fits
  /// every platform.
  Size get slotSize =>
      Size(platformWidths.reduce(math.min) * treeWidth, treeHeight * 0.06);

  /// Height of an instrument standing on a platform — just under the gap to
  /// the platform above, so placed instruments never sit on each other.
  double get placedSize =>
      (platformCentres[1].dy - platformCentres[0].dy) * treeHeight * 0.95;

  /// The drop target over platform [index]: wider than the face so a small
  /// child's imprecise aim still lands, and tall enough to take an
  /// instrument's whole drawn height (it sits mostly above the face).
  Rect slotRect(int index) {
    final c = platform(index);
    final w = slotSize.width * 1.35;
    final h = placedSize;
    return Rect.fromLTWH(c.dx - w / 2, c.dy - h * 0.8, w, h);
  }

  /// Everywhere Clef can be drawn: his widest pose, at the peak of the
  /// speaking pulse [pulse] (a scale delta), standing on [clefPerch].
  Rect clefBounds({double pulse = 0}) {
    final w = _widestPose(CharacterArt.clef, characterHeight) * (1 + pulse);
    final h = characterHeight * (1 + pulse);
    return Rect.fromLTWH(clefPerch.dx - w / 2, clefPerch.dy - h, w, h);
  }

  /// Everywhere Piper can be drawn, at her widest pose and the peak of the
  /// speaking pulse [pulse].
  Rect piperBounds({double pulse = 0}) {
    final frame = spriteWidth(CharacterArt.piper, piperHeight);
    final centre = piperLeftInset + frame / 2;
    final w = _widestPose(CharacterArt.piper, piperHeight) * (1 + pulse);
    final h = piperHeight * (1 + pulse);
    return Rect.fromLTWH(centre - w / 2, piperFeetY - h, w, h);
  }

  // ---- the caption ----

  /// Where the meadow ends on the right: the tree's own left edge (its
  /// canopy reaches all the way to the image's left edge). The caption is
  /// centred over the meadow, not the screen — the composition is no longer
  /// symmetric, and screen-centred text lands in the canopy.
  double get meadowRight => treeRect.left;

  // ---- the instruments ----

  /// Distance from the bottom of the screen up to every stump's surface.
  ///
  /// **One floor:** the stumps' ground line agrees with the tree's base — its
  /// bottom platform sits just above where its roots meet the grass. 0.775 of
  /// the height is where the root flare begins in the art, 0.036 below the
  /// bottom platform. Raised from 0.84 (Trello card 187: the stumps move up).
  /// The earlier attempt to raise them was reverted because the old tree's
  /// bottom platform could not move; this tree's base is where the stumps now
  /// stand.
  double get groundY => screen.height * 0.225;

  /// The space the instruments have: from just right of Piper to just left
  /// of whichever comes first — Clef, who sits on the branch above them, or
  /// the platform column, which they must never cover. The gaps are between
  /// objects, not against the bezel, so they are half the edge margin; on an
  /// SE that difference is what keeps the smallest instrument above
  /// [minTouchTarget].
  double get _gap => _margin / 2;
  double get _bandLeft => piperRight + _gap;
  double get _bandRight =>
      math.min(clefPerch.dx - _clefHalfWidth, platformColumnLeftX) - _gap;

  /// Instrument box size: [instrumentFraction] of the height, capped so the
  /// instruments fit the band without their boxes overlapping (which would
  /// make which one a touch picks up ambiguous).
  double get instrumentSize => math.min(
    screen.height * instrumentFraction,
    (_bandRight - _bandLeft) / noteCount,
  );

  /// Distance between neighbouring stump centres: a little air between the
  /// instruments where the band allows, never less than touching.
  double get _pitch {
    final fit = (_bandRight - _bandLeft - instrumentSize) / (noteCount - 1);
    final airy = instrumentSize * 1.12;
    return fit < airy ? fit : airy;
  }

  /// Horizontal centre of instrument [index]'s stump. The group is centred in
  /// the band. Depends only on the index and the count, never on what else
  /// has moved — the layout must not reflow.
  double stumpAnchorX(int index) {
    final groupWidth = instrumentSize + (noteCount - 1) * _pitch;
    final groupLeft = (_bandLeft + _bandRight - groupWidth) / 2;
    return groupLeft + instrumentSize / 2 + index * _pitch;
  }

  /// Where instrument [index] stands (feet, screen coordinates, y down).
  Offset stumpFeet(int index) =>
      Offset(stumpAnchorX(index), screen.height - groundY);

  /// The right-hand edge of the last instrument's box.
  double get instrumentsRight =>
      stumpAnchorX(noteCount - 1) + instrumentSize / 2;

  /// How far below the ground line a stump's art reaches: the stump is
  /// [stumpWidthOfInstrument] of the instrument's width, about half as tall as
  /// it is wide, and its top surface is [stumpSurfaceFraction] of the way
  /// down it (see `HighLowScreen._buildStump`).
  static const stumpWidthOfInstrument = 0.95;
  static const stumpAspect = 794 / 1512;

  /// Fraction of the stump art's height, from the top, down to the front rim
  /// of its flat top surface — read directly off StumpA.png/StumpB.png (both
  /// are cropped/composed the same way). Below this line is bark and grass;
  /// above it is the disc an instrument stands on.
  static const stumpSurfaceFraction = 0.37;
  double get _stumpDepth =>
      instrumentSize *
      stumpWidthOfInstrument *
      stumpAspect *
      (1 - stumpSurfaceFraction);

  /// Where Listen Again sits: below the stumps, centred under them (Cooper:
  /// "I like listen again below the stumps"), midway between the stumps'
  /// lowest point and the bottom of the safe area.
  Offset get listenAgainCenter {
    final stumpsBottom = screen.height - groundY + _stumpDepth;
    final floor = screen.height - insets.bottom;
    return Offset(
      (stumpAnchorX(0) + stumpAnchorX(noteCount - 1)) / 2,
      (stumpsBottom + floor) / 2,
    );
  }

  /// Where the A0 earned arrow sits: in the open air below the branch,
  /// between the last instrument and the platform column, level with the
  /// middle of the instruments.
  Offset get arrowCentre => Offset(
    (instrumentsRight + platformColumnLeftX) / 2,
    screen.height - groundY - instrumentSize * 0.4,
  );
}

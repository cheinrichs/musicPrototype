import 'package:flutter/painting.dart';
import '../widgets/character_art.dart';

/// The ordering screen's scene, on the four-platform `OrderingTree.png`:
/// instruments on stumps at the left, the tree at the right, Clef on its top
/// platform and the three below it as drop slots.
///
/// **This is the scene High/Low itself used until the layout pass of Trello
/// card 187** (2026-10-06), kept verbatim so the ordering screen does not move
/// while High/Low moves to `PitchTree_v2.png` — see `SceneLayout` for that
/// one. Whether ordering should follow onto the new tree is an open question
/// for Cooper, not a decision taken here.
///
/// Pure geometry, so the rules that keep going wrong on a real device can be
/// tested at real screen sizes (including a notched phone's side insets).
class OrderingTreeScene {
  /// Natural proportions of `OrderingTree.png` (1024 x 1536).
  static const treeAspect = 1024 / 1536;

  /// Vertical centre of each platform's top face, as a fraction of the
  /// tree's height, top to bottom — measured from the art (2026-09-26), not
  /// read off the concept card, whose 16/35/55/73% are the platforms' *top
  /// edges*; a foot belongs on the middle of the flat face. Spacing is even
  /// enough (0.187, 0.189, 0.177) that gaps read as equal intervals.
  static const platformCentreY = [0.182, 0.369, 0.558, 0.735];

  /// Horizontal centre of the platforms' faces, as a fraction of tree width
  /// (they vary between 0.513 and 0.534 in the art).
  static const platformCentreX = 0.52;

  /// Width of a platform's top face, as a fraction of tree width.
  static const platformWidth = 0.275;

  final Size screen;
  final EdgeInsets insets;

  /// How many instruments stand on stumps (2 or 3).
  final int noteCount;

  /// Instrument box size as a fraction of screen height. Two-instrument play
  /// screens use the large default: at A0/A1 the instruments *are* the whole
  /// activity, so they must not shrink to make room for the tree.
  final double instrumentFraction;

  const OrderingTreeScene(
    this.screen, {
    this.insets = EdgeInsets.zero,
    required this.noteCount,
    this.instrumentFraction = 0.50,
  }) : assert(noteCount == 2 || noteCount == 3);

  // ---- the tree ----

  double get treeHeight => screen.height * 0.92;
  double get treeWidth => treeHeight * treeAspect;

  /// Half the platforms' face width — how far a foot can be from the centre.
  double get _halfFace => platformWidth * treeWidth / 2;

  /// Space kept clear at each screen edge: the device's own inset plus a
  /// margin.
  double get _margin => screen.width * 0.02;

  /// The x through the middle of every platform: about four-fifths of the way
  /// across, pulled in if the right-hand platform face would touch the notch.
  double get _treeCentreX {
    final ideal = screen.width * 0.78;
    final furthest = screen.width - insets.right - _margin - _halfFace;
    return ideal < furthest ? ideal : furthest;
  }

  /// Where the top platform's feet sit, as a fraction of the height. Low
  /// enough that the top character's head clears the caption row; it puts the
  /// bottom platform's feet a little below the stumps' ground line (0.84),
  /// which reads fine because the tree is a separate object far to the right.
  static const topPlatformY = 0.355;

  Rect get treeRect {
    final top = screen.height * topPlatformY - platformCentreY[0] * treeHeight;
    final left = _treeCentreX - platformCentreX * treeWidth;
    return Rect.fromLTWH(left, top, treeWidth, treeHeight);
  }

  /// The middle of platform [index]'s top face (0 = top): where feet go.
  Offset platform(int index) => Offset(
    treeRect.left + platformCentreX * treeWidth,
    treeRect.top + platformCentreY[index] * treeHeight,
  );

  // ---- the characters ----

  /// Clef's feet: the top platform — high.
  Offset get clefPerch => platform(0);

  /// Clef's size, on his platform.
  double get characterHeight => screen.height * 0.24;

  /// Drawn width of a character sprite of [art] at [height].
  double spriteWidth(CharacterArt art, double height) =>
      art.frameSize.width * height / art.frameSize.height;

  /// Piper's height, standing beside the tree — a clearly larger,
  /// "foreground" scale, deliberately not [characterHeight]: the whole
  /// point is that she reads as closer to the viewer than anything on the
  /// tree.
  ///
  /// Trimmed slightly from an earlier 0.60 (2026-09-28, Cooper, on device:
  /// "Piper far too low... she also needs to be a bit further right so as
  /// to not block the tree") — a smaller height narrows her sprite's own
  /// footprint too (width scales with height at a fixed aspect ratio),
  /// which is what actually frees the tree from behind her; padding out
  /// [piperRightInset] alone couldn't do that without pushing her past the
  /// screen edge, since a right-edge anchor stays put while its own width
  /// still reaches equally far left. Still meaningfully larger than
  /// [characterHeight]: the foreground read survives the trim.
  double get piperHeight => screen.height * 0.50;

  /// Where Piper's feet sit. Anchored to the **bottom of the screen**, not
  /// to a tree platform (2026-09-28, replacing an earlier version pinned to
  /// the tree's third platform, which put her head so low that half her
  /// body fell off the bottom of the frame — Cooper: "we should only cut
  /// off her feet at most"). A small deliberate overflow past the true
  /// bottom edge (a fraction of her own height) is what actually delivers
  /// that: her ankles, not her knees, are what go offscreen. Check this
  /// visually on a real device/simulator, per Cooper's own instruction —
  /// this number is a starting guess like [HighLowInstrument.floatFraction]
  /// elsewhere in this scene, not a derivation.
  double get piperFeetY => screen.height + piperHeight * 0.05;

  /// Piper's `Positioned.right` inset: the device's own side inset plus a
  /// margin, the same convention used everywhere else in this scene — she
  /// stands beside the tree (which is itself biased right) without needing
  /// exact art-edge math.
  double get piperRightInset => insets.right + _margin;

  // ---- the tree slot (2026-09-27: the drop target — see the class doc) ----

  /// Which platform holds the slot for a high-pole round — the one right
  /// under Clef, so "the high one" lands close to whoever asked for it.
  static const int highSlotPlatform = 1;

  /// Which platform holds the slot for a low-pole round — the tree's
  /// bottom-most, both for the widest top/bottom contrast the three empty
  /// platforms allow and because it is nearest the ground, where Piper now
  /// stands.
  static const int lowSlotPlatform = 3;

  /// The platform this round's slot sits on.
  int slotPlatformFor({required bool isPiperTarget}) =>
      isPiperTarget ? lowSlotPlatform : highSlotPlatform;

  /// A slot's footprint on its platform — shared with [OrderingLayout],
  /// which places three of these instead of one.
  Size get slotSize => Size(platformWidth * treeWidth, treeHeight * 0.06);

  // ---- the instruments ----

  /// Distance from the bottom of the screen up to every stump's surface.
  double get groundY => screen.height * 0.16;

  /// Where Listen Again sits, below the stumps rather than under the
  /// caption (2026-09-28, Cooper: "I like listen again below the stumps —
  /// I'd love to try to scale everything so that moving the stumps up
  /// would fit"). **Tried moving the stumps up first** (raising [groundY])
  /// and backed it out: the tree's bottom platform is fixed scenery, and
  /// raising the stumps enough to matter broke the existing "one floor"
  /// relationship between the stumps' ground line and that platform (see
  /// the `scene_layout_test.dart` test of that name) — exactly the
  /// "standing on a distant hillside" conflicting depth cue Cooper's own
  /// instruction warned to check for. [groundY] already reserves a margin
  /// below the stumps' feet before touching it at all; this fits Listen
  /// Again into that existing margin instead; centred under the stump
  /// band, two-thirds of the way down it toward the true bottom edge
  /// (leaves room above for the button's own height without crowding the
  /// stumps' feet). Still needs the same visual check in the simulator —
  /// this reasoning is about why [groundY] itself didn't move, not proof
  /// this fits.
  Offset get listenAgainCenter => Offset(
    (stumpAnchorX(0) + stumpAnchorX(noteCount - 1)) / 2,
    screen.height - groundY * 0.35,
  );

  double get instrumentSize => screen.height * instrumentFraction;

  double get _bandLeft => insets.left + _margin;

  /// The band may reach a little into the tree's foliage, which overhangs its
  /// platforms, but never onto them.
  double get _bandRight => treeRect.left + 0.15 * treeWidth;

  /// Distance between neighbouring stump centres: packed to the left rather
  /// than spread across the whole band, which leaves a free column before the
  /// tree (for the A0 arrow) and keeps two instruments looking like two.
  double get _pitch {
    final fit = (_bandRight - _bandLeft) / noteCount;
    final packed = instrumentSize * 1.12;
    return fit < packed ? fit : packed;
  }

  /// Horizontal centre of instrument [index]'s stump. Depends only on the
  /// index and the count, never on what else has moved — the layout must not
  /// reflow.
  double stumpAnchorX(int index) =>
      _bandLeft + instrumentSize / 2 + index * _pitch;

  /// Where instrument [index] stands (feet, screen coordinates, y down).
  Offset stumpFeet(int index) =>
      Offset(stumpAnchorX(index), screen.height - groundY);

  /// The right-hand edge of the last instrument's box.
  double get instrumentsRight =>
      stumpAnchorX(noteCount - 1) + instrumentSize / 2;

  /// Height of an instrument standing on a platform — just under the gap to
  /// the platform above, so placed instruments never sit on each other.
  double get placedSize =>
      (platformCentreY[2] - platformCentreY[1]) * treeHeight * 0.95;

  /// Where the A0 earned arrow sits: the free column between the last
  /// instrument and the tree, level with the middle of the instruments.
  Offset get arrowCentre {
    final faceLeft = _treeCentreX - _halfFace;
    return Offset(
      (instrumentsRight + faceLeft) / 2,
      screen.height - groundY - instrumentSize * 0.4,
    );
  }
}

import 'package:flutter/painting.dart';

/// Where everything sits on the A4 ordering screen, as pure geometry so it
/// can be checked at real viewport sizes.
///
/// The tree's platform positions are **measured from `OrderingTree.png`**
/// (2026-09-26), not read off the card. The card's 16% / 35% / 55% / 73% are
/// the platforms' *top edges*; an instrument's feet belong on the middle of
/// each platform's flat top face, which measures at 0.182 / 0.369 / 0.558 /
/// 0.735 of the image height (spacing 0.187, 0.189, 0.177 — even enough that
/// the gaps read as equal intervals, which is what the art needs).
class OrderingLayout {
  /// Natural proportions of `OrderingTree.png` (1024 x 1536).
  static const treeAspect = 1024 / 1536;

  /// Vertical centre of each platform's top face, as a fraction of the
  /// tree's height, top to bottom. The first belongs to Clef; the three
  /// below are the drop slots.
  static const platformCentreY = [0.182, 0.369, 0.558, 0.735];

  /// Horizontal centre of the platforms' faces, as a fraction of tree width
  /// (they vary between 0.513 and 0.534 in the art).
  static const platformCentreX = 0.52;

  /// Width of a platform's top face, as a fraction of tree width.
  static const platformWidth = 0.275;

  /// Where each note's stump stands, as a fraction of screen width, by how
  /// many notes the round has. Index = the note's index, so an instrument's
  /// home never depends on what else is placed. Two on the left and one on
  /// the right for three notes; one each side for two.
  static const stumpAnchorX = {
    2: [0.16, 0.84],
    3: [0.09, 0.25, 0.86],
  };

  final Size screen;
  final int noteCount;

  const OrderingLayout(this.screen, {required this.noteCount})
    : assert(noteCount == 2 || noteCount == 3);

  // Sized so Clef on the top platform clears the header (which, with the
  // skip pill's two lines, is about 20% of the height — measured on a
  // render, not assumed) and the bottom platform clears the progress dots
  // (~14%); the canopy and roots run off the edges.
  double get treeHeight => screen.height * 0.92;
  double get treeWidth => treeHeight * treeAspect;

  Rect get treeRect {
    final top = screen.height * 0.335 - platformCentreY[0] * treeHeight;
    final left = screen.width / 2 - platformCentreX * treeWidth;
    return Rect.fromLTWH(left, top, treeWidth, treeHeight);
  }

  Offset _platform(int index) => Offset(
    treeRect.left + platformCentreX * treeWidth,
    treeRect.top + platformCentreY[index] * treeHeight,
  );

  /// The middle of drop slot [slot] (0 = top, just under Clef): where a
  /// placed instrument's feet go.
  Offset slotCentre(int slot) => _platform(slot + 1);

  /// Where Clef's feet go, on the top platform.
  Offset get clefFeet => _platform(0);

  Size get slotSize => Size(platformWidth * treeWidth, treeHeight * 0.06);

  /// Height of an instrument standing on a platform — just under the gap to
  /// the platform above, so placed instruments never sit on each other.
  double get placedSize =>
      (platformCentreY[2] - platformCentreY[1]) * treeHeight * 0.95;

  /// Clef marks the high end from the top platform — a marker, not a
  /// character to admire, so she's kept small enough for the whole ladder
  /// to fit between the header and the progress dots.
  double get clefHeight => placedSize * 0.75;

  /// Height of an instrument standing on its stump.
  double get stumpInstrumentSize => screen.height * 0.34;

  /// Distance from the bottom of the screen up to every stump's surface.
  double get groundY => screen.height * 0.16;

  /// Where note [note]'s instrument stands on its stump (feet, screen
  /// coordinates, y down).
  Offset stumpFeet(int note) => Offset(
    stumpAnchorX[noteCount]![note] * screen.width,
    screen.height - groundY,
  );
}

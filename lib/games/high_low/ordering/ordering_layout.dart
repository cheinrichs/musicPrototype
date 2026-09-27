import 'package:flutter/painting.dart';
import '../models/scene_layout.dart';

/// Where everything sits on the A4 ordering screen: the shared High/Low
/// scene ([SceneLayout] — instruments on stumps at the left, the tree at the
/// right with Clef on its top platform) plus the drop slots on the platforms
/// below her.
///
/// Slots exist only here. On the play screens the same tree is scenery and
/// seating for the characters, with no receptacles drawn — see
/// [SceneLayout]'s class doc.
class OrderingLayout extends SceneLayout {
  const OrderingLayout(super.screen, {super.insets, required super.noteCount})
    : super(instrumentFraction: 0.34);

  /// The middle of drop slot [slot] (0 = top, just under Clef): where a
  /// placed instrument's feet go.
  Offset slotCentre(int slot) => platform(slot + 1);

  /// Where Clef's feet go, on the top platform.
  Offset get clefFeet => clefPerch;

  Size get slotSize =>
      Size(SceneLayout.platformWidth * treeWidth, treeHeight * 0.06);

  /// Clef marks the high end from the top platform, the same size as on the
  /// play screens.
  double get clefHeight => characterHeight;

  /// Height of an instrument standing on its stump.
  double get stumpInstrumentSize => instrumentSize;
}

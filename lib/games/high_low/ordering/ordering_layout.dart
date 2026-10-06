import 'package:flutter/painting.dart';
import 'ordering_tree_scene.dart';

/// Where everything sits on the A4 ordering screen: its scene
/// ([OrderingTreeScene] — instruments on stumps at the left, the tree at the
/// right with Clef on its top platform) plus the drop slots on the platforms
/// below her.
///
/// All three slots stay visible here (nothing to hide — every platform but
/// Clef's is a receptacle at A4).
class OrderingLayout extends OrderingTreeScene {
  const OrderingLayout(super.screen, {super.insets, required super.noteCount})
    : super(instrumentFraction: 0.34);

  /// The middle of drop slot [slot] (0 = top, just under Clef): where a
  /// placed instrument's feet go.
  Offset slotCentre(int slot) => platform(slot + 1);

  /// Where Clef's feet go, on the top platform.
  Offset get clefFeet => clefPerch;

  /// Clef marks the high end from the top platform, the same size as on the
  /// play screens.
  double get clefHeight => characterHeight;

  /// Height of an instrument standing on its stump.
  double get stumpInstrumentSize => instrumentSize;
}

import 'package:flutter/painting.dart';
import '../models/scene_layout.dart';

/// Where everything sits on the A4 ordering screen: the same tree scene as
/// High vs Low ([SceneLayout] — one tree across the whole game, Trello card
/// 188), without Piper, plus a drop slot on every free platform.
///
/// With two instruments Clef sits on the top platform and the slots are the
/// two below him; with three he moves to the branch and all three platforms
/// are slots. Either way the order still reads down from Clef.
class OrderingLayout extends SceneLayout {
  const OrderingLayout(super.screen, {super.insets, required super.noteCount})
    : super(withPiper: false);

  /// The middle of drop slot [slot] (0 = the highest free platform): where a
  /// placed instrument's feet go.
  Offset slotCentre(int slot) => platform(freePlatforms[slot]);

  /// Where Clef's feet go.
  Offset get clefFeet => clefPerch;

  /// Clef is the same size as on the play screens.
  double get clefHeight => characterHeight;

  /// Height of an instrument standing on its stump.
  double get stumpInstrumentSize => instrumentSize;
}

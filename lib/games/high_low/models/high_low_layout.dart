import 'package:flutter/painting.dart';
import '../widgets/character_art.dart';

/// Where everything on the High/Low play screen sits, as pure geometry so
/// the rules that keep going wrong on a real device can be tested at real
/// screen sizes (including a notched phone's side insets).
///
/// Two rules drive it, both from Cooper on device:
///
/// **Prominence follows the task, not the scene.** The character the child
/// is asked to drag to is drawn larger than the one standing by, always.
/// The edge-foreground "depth" effect (a character at the edge reads as
/// nearer the viewer) is kept only as a secondary influence — it can shape
/// the waiting character's size, but it must never outrank the task, so
/// [waitingHeight] is derived from [targetHeight] and is always smaller.
///
/// **Nothing runs off the screen.** Edge characters are inset by the device's
/// side insets and a margin, leaving room for the speaking pulse's growth.
class HighLowLayout {
  final Size screen;
  final EdgeInsets insets;

  /// Whether a character is centred as the task's target (A1/A2). At A0 the
  /// characters only narrate, so there is no task character and both are the
  /// same size.
  final bool hasTarget;

  const HighLowLayout(
    this.screen, {
    this.insets = EdgeInsets.zero,
    required this.hasTarget,
  });

  /// The drop target, centred: the prominent one.
  double get targetHeight => screen.height * 0.46;

  /// How much smaller the character standing by is than the target. Below
  /// 1 by design — see the class doc.
  static const waitingRatio = 0.68;

  /// The standing-by size when there is a target.
  double get waitingHeightWithTarget => targetHeight * waitingRatio;

  /// The size of both edge characters at A0, where nobody is the target.
  double get waitingHeightNoTarget => targetHeight * waitingRatio;

  double get waitingHeight =>
      hasTarget ? waitingHeightWithTarget : waitingHeightNoTarget;

  /// One shared ground line, as a distance up from the bottom of the screen:
  /// the stumps' surface, the instruments' feet, and both characters' feet.
  double get groundY => screen.height * 0.16;

  double get characterLift => groundY;

  /// Height of the bottom row of controls (Listen Again, progress, Skip).
  /// The ground line sits above it so characters never cover a control.
  double get controlRowHeight => screen.height * 0.15;

  /// Size of an instrument (before its own per-instrument scale).
  double get instrumentSize => screen.height * 0.50;

  /// Horizontal centres of the two instruments' stumps. Data, not
  /// hard-coded in the screen: the three-instrument formation will supply
  /// its own (see docs/product/HIGH_LOW_TIERS.md — its layout is still an
  /// open question, because the target character and the centre-back
  /// pedestal both want the middle).
  double instrumentAnchorX(int side) =>
      screen.width * (side == 0 ? 0.30 : 0.70);

  /// Distance from the bottom of the screen to the top of an instrument
  /// standing on the ground line.
  double instrumentTop(int side) => groundY + instrumentSize;

  /// How far above its stump an instrument floats (bells hang from their
  /// ring, so they hover slightly proud of the surface instead of sinking
  /// into it).
  double instrumentFeetLift({
    required double size,
    required double floatFraction,
  }) => size * floatFraction;

  // ---- edge characters ----

  /// Space kept clear at each screen edge: the device's own inset plus a
  /// margin (a character flush to the edge is cut by rounded corners, and
  /// the speaking pulse grows it a few percent).
  double get _margin => screen.width * 0.02;

  double get leftEdgeX => insets.left + _margin;

  /// The x of the right-hand character's right edge.
  double get rightEdgeX => screen.width - insets.right - _margin;

  /// Drawn width of a character sprite of [art] at [height].
  double spriteWidth(CharacterArt art, double height) =>
      art.frameSize.width * height / art.frameSize.height;
}

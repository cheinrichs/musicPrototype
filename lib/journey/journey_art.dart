import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/art_registry.dart';

import 'journey_state.dart';

/// The Journey's art (cards 206, 217, 204), copied byte-for-byte from the
/// handoff — never re-matted or re-saved.
abstract final class JourneyArt {
  static const _dir = 'assets/images/journey';
  static const stonesLocked = '$_dir/stones_locked_x3.png';
  static const stonesCurrent = '$_dir/stones_current_x3.png';
  static const stonesDone = '$_dir/stones_done_x3.png';
  static const pins = '$_dir/avatars_pins_16.png';
  static const chestPlain = '$_dir/chest_closed_plain.png';
  static const chestGlow = '$_dir/chest_closed_glow.png';
  static const chestOpen = '$_dir/chest_open_burst.png';
  static const giftPlain = '$_dir/gift_closed_plain.png';
  static const giftGlow = '$_dir/gift_closed_glow.png';
  static const giftOpen = '$_dir/gift_open_burst.png';
  static const railIcons = '$_dir/rail_icons_2treatments.png';

  /// The pin sheet, 1306×1205. Its sixteen avatars are NOT on an even 4×4
  /// grid of the sheet: the art has margins (≈117 px at the sides, 35 at
  /// the top) and uneven gutters, so even cells caught a sliver of a
  /// neighbour on one side and clipped their own avatar on the other.
  static const pinSheet = Size(1306, 1205);

  /// Each avatar's visible bounds in the sheet (alpha > 8 — the sheet has
  /// faint matte noise below that everywhere), in reading order, measured
  /// 2026-11-13. test/journey/avatar_pin_slices_test.dart re-measures them
  /// from the file, so a re-exported sheet that moves them fails the build.
  static const pinBounds = [
    Rect.fromLTRB(124, 35, 342, 309),
    Rect.fromLTRB(414, 46, 633, 308),
    Rect.fromLTRB(676, 46, 895, 308),
    Rect.fromLTRB(962, 45, 1180, 308),
    Rect.fromLTRB(121, 324, 347, 592),
    Rect.fromLTRB(410, 324, 635, 592),
    Rect.fromLTRB(675, 325, 900, 592),
    Rect.fromLTRB(959, 324, 1187, 591),
    Rect.fromLTRB(118, 609, 344, 872),
    Rect.fromLTRB(405, 609, 634, 871),
    Rect.fromLTRB(674, 609, 902, 872),
    Rect.fromLTRB(961, 608, 1188, 871),
    Rect.fromLTRB(117, 882, 347, 1147),
    Rect.fromLTRB(408, 883, 635, 1148),
    Rect.fromLTRB(671, 882, 901, 1148),
    Rect.fromLTRB(959, 882, 1187, 1148),
  ];

  /// One slice size for all sixteen, so every pin draws at the same scale:
  /// a little larger than the largest avatar, and small enough to stay
  /// clear of every neighbour (the tightest gutter is 11 px, between rows
  /// 3 and 4).
  static const pinCell = Size(240, 276);

  /// Of a slice's height, how far down the pin's tip is: each slice sits
  /// [_pinFoot] px below its avatar's tip.
  static const _pinFoot = 2.0;
  static const pinTip = (276 - _pinFoot) / 276;

  /// Avatar [index]'s slice: [pinCell], centred on the avatar, its tip
  /// [_pinFoot] px above the slice's foot.
  static Rect pinSlice(int index) {
    final b = pinBounds[index % pinBounds.length];
    return Rect.fromLTWH(
      b.center.dx - pinCell.width / 2,
      b.bottom + _pinFoot - pinCell.height,
      pinCell.width,
      pinCell.height,
    );
  }
}

enum StoneState { locked, current, done }

/// One cell of a sprite sheet laid out as an even grid.
class SpriteCell extends StatelessWidget {
  final String asset;
  final int columns;
  final int rows;
  final int column;
  final int row;

  const SpriteCell({
    super.key,
    required this.asset,
    required this.columns,
    required this.rows,
    required this.column,
    required this.row,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth * columns;
        final h = c.maxHeight * rows;
        return ClipRect(
          child: OverflowBox(
            minWidth: w,
            maxWidth: w,
            minHeight: h,
            maxHeight: h,
            alignment: Alignment(
              columns == 1 ? 0 : -1 + 2 * column / (columns - 1),
              rows == 1 ? 0 : -1 + 2 * row / (rows - 1),
            ),
            child: Image.asset(asset, fit: BoxFit.fill),
          ),
        );
      },
    );
  }
}

/// A stepping stone (card 206): three hand-drawn variants per state.
class StoneArt extends StatelessWidget {
  final StoneState state;
  final int variant;
  final double size;
  const StoneArt({
    super.key,
    required this.state,
    required this.variant,
    required this.size,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: SpriteCell(
      asset: switch (state) {
        StoneState.locked => JourneyArt.stonesLocked,
        StoneState.current => JourneyArt.stonesCurrent,
        StoneState.done => JourneyArt.stonesDone,
      },
      columns: 3,
      rows: 1,
      column: variant % 3,
      row: 0,
    ),
  );
}

/// The child's avatar pin, from the sixteen.
class AvatarPin extends StatelessWidget {
  final int index;
  const AvatarPin({super.key, required this.index});

  @override
  Widget build(BuildContext context) => ImageRegion(
    art: ArtRef(
      JourneyArt.pins,
      image: JourneyArt.pinSheet,
      region: JourneyArt.pinSlice(index),
    ),
  );
}

/// No avatar picker yet: a profile keeps the same one of the sixteen.
int avatarIndexFor(String? profileId) {
  if (profileId == null) return 0;
  var h = 0;
  for (final c in profileId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h % 16;
}

/// A reward as it flies and arrives: the thing itself (its type's art for
/// this reward, by id), in the diamond frame unless the art is already a
/// diamond token. Rewards are diamonds — never a rail shape.
class RewardItem extends StatelessWidget {
  final Reward reward;
  final double size;
  const RewardItem({super.key, required this.reward, required this.size});

  @override
  Widget build(BuildContext context) {
    final type = reward.type;
    final art = ArtImage(reward.artId);
    return SizedBox.square(
      dimension: size,
      child: type.framed ? RewardDiamond(child: art) : art,
    );
  }
}

/// The reward frame: a cream diamond with a gold edge, drawn, with the
/// referenced art standing in it.
class RewardDiamond extends StatelessWidget {
  final Widget child;
  const RewardDiamond({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Transform.rotate(
        angle: math.pi / 4,
        child: FractionallySizedBox(
          widthFactor: 0.7,
          heightFactor: 0.7,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF6E7BF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0A92E), width: 3),
              boxShadow: const [
                BoxShadow(blurRadius: 6, color: Color(0x55000000)),
              ],
            ),
          ),
        ),
      ),
      FractionallySizedBox(widthFactor: 0.56, heightFactor: 0.56, child: child),
    ],
  );
}

/// One of the rail's four icons, label included, from
/// rail_icons_2treatments. The two rows are a STATE PAIR: the rounded square
/// (bottom row) is the page the child is on, the circle (top row) every
/// other destination.
class RailIcon extends StatelessWidget {
  /// 0 Journey, 1 Games, 2 Crafts, 3 Playground.
  final int destination;
  final bool selected;
  const RailIcon({super.key, required this.destination, this.selected = false});

  @override
  Widget build(BuildContext context) => SpriteCell(
    asset: JourneyArt.railIcons,
    columns: 4,
    rows: 2,
    column: destination,
    row: selected ? 1 : 0,
  );
}

/// The opened chest (chest_open_burst), drawn so its body stands where the
/// closed chest's did: its body is about 8% wider and sits lower in its
/// square (foot at 79% against 76%), so it is scaled by 0.92 about the
/// point that maps one foot onto the other.
class OpenChestArt extends StatelessWidget {
  const OpenChestArt({super.key});

  /// Scaling by k about y = a takes the open foot (0.79) to the closed one
  /// (0.76): a = (0.76 - 0.92 * 0.79) / (1 - 0.92) ≈ 0.415 of the height.
  static const double scale = 0.92;
  static const Alignment anchor = Alignment(0, 2 * 0.415 - 1);

  /// Where the opening is, as a fraction of the square's height — where
  /// the presents come out.
  static const double mouth = 0.42;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: scale,
    alignment: anchor,
    child: Image.asset(JourneyArt.chestOpen, fit: BoxFit.contain),
  );
}

/// PLACEHOLDER speech: no "That was brilliant!" recording yet.
class SpeechBubble extends StatelessWidget {
  final String text;
  const SpeechBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4A3A6A),
      ),
    ),
  );
}

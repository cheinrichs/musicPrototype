import 'package:flutter/material.dart';

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

  /// The pin sheet is a 4×4 grid of 1306×1205.
  static const pinCell = Size(1306 / 4, 1205 / 4);
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
  Widget build(BuildContext context) => SpriteCell(
    asset: JourneyArt.pins,
    columns: 4,
    rows: 4,
    column: index % 4,
    row: (index ~/ 4) % 4,
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

/// A reward as it flies and arrives: its type's diamond token (see the
/// catalogue in reward_catalogue.dart), or a plain diamond for a type with
/// no art yet.
class RewardItem extends StatelessWidget {
  final Reward reward;
  final double size;
  const RewardItem({super.key, required this.reward, required this.size});

  @override
  Widget build(BuildContext context) {
    final token = reward.type.token;
    return SizedBox.square(
      dimension: size,
      child: token == null
          ? const _PlainDiamond()
          : ImageRegion(
              asset: token.asset,
              image: token.image,
              region: token.region,
            ),
    );
  }
}

/// A region of an image, scaled to fill the box (the box should share the
/// region's aspect).
class ImageRegion extends StatelessWidget {
  final String asset;
  final Size image;
  final Rect region;
  const ImageRegion({
    super.key,
    required this.asset,
    required this.image,
    required this.region,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final sx = c.maxWidth / region.width;
      final sy = c.maxHeight / region.height;
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: image.width * sx,
          maxWidth: image.width * sx,
          minHeight: image.height * sy,
          maxHeight: image.height * sy,
          child: Transform.translate(
            offset: Offset(-region.left * sx, -region.top * sy),
            child: Image.asset(asset, fit: BoxFit.fill),
          ),
        ),
      );
    },
  );
}

/// A reward type with no art yet: a plain cream diamond.
class _PlainDiamond extends StatelessWidget {
  const _PlainDiamond();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.785398,
    child: FractionallySizedBox(
      widthFactor: 0.68,
      heightFactor: 0.68,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF6E7BF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0A92E), width: 3),
        ),
      ),
    ),
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

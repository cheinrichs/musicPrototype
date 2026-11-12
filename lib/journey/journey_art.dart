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
  static const giftPlain = '$_dir/gift_closed_plain.png';
  static const giftGlow = '$_dir/gift_closed_glow.png';
  static const giftOpen = '$_dir/gift_open_burst.png';

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

/// PLACEHOLDER reward item: a grey card with its category's icon.
class RewardPlaceholder extends StatelessWidget {
  final RewardCategory category;
  final double size;
  const RewardPlaceholder({
    super.key,
    required this.category,
    required this.size,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFBDBDBD),
      borderRadius: BorderRadius.circular(size * 0.18),
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
    ),
    child: Icon(category.icon, size: size * 0.55, color: Colors.white),
  );
}

/// PLACEHOLDER rail destination: a translucent disc on the scene (card 204:
/// no solid dark panel), popping in when the category first appears.
class RailIconPlaceholder extends StatelessWidget {
  final RewardCategory category;
  final int count;
  const RailIconPlaceholder({
    super.key,
    required this.category,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: LayoutBuilder(
        builder: (context, c) {
          final s = c.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.55),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Icon(
                  category.icon,
                  size: s * 0.55,
                  color: const Color(0xFF8A8A8A),
                ),
              ),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: Container(
                      key: ValueKey(count),
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFB300),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// PLACEHOLDER: the open chest does not exist yet. A grey base with its lid
/// tipped back, sized to stand where the chest art does.
class OpenChestPlaceholder extends StatelessWidget {
  final double size;
  const OpenChestPlaceholder({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    const grey = Color(0xFF9E9E9E);
    final border = Border.all(color: Colors.white, width: 3);
    return Stack(
      children: [
        // The base: the chest body's footprint in the closed art.
        Positioned(
          left: size * 0.17,
          right: size * 0.17,
          top: size * 0.46,
          height: size * 0.3,
          child: Container(
            decoration: BoxDecoration(
              color: grey,
              border: border,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              'open chest',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.07,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // The lid, tipped back.
        Positioned(
          left: size * 0.2,
          right: size * 0.2,
          top: size * 0.24,
          height: size * 0.17,
          child: Transform.rotate(
            angle: -0.35,
            alignment: Alignment.bottomLeft,
            child: Container(
              decoration: BoxDecoration(
                color: grey,
                border: border,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
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

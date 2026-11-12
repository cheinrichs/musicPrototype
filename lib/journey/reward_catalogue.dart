import 'package:flutter/foundation.dart';

import '../app/rail_destination.dart';

/// One kind of reward: where it lives, and the things it can be.
///
/// **A reward is depicted by the thing itself, not by a symbol for its
/// category** (Cooper, 2026-11). So a token is a FRAME plus a REFERENCED
/// ART ID (see `Art` in lib/app/art_registry.dart), not per-reward art: an
/// instrument reward is the instrument's own art in a diamond, the same art
/// the games and the Playground use.
///
/// Rewards are DIAMONDS — never the rail's circles or rounded squares, so a
/// reward never reads as a navigation item. The token says what was
/// earned; the destination only says where it lives (songs and instruments
/// share Playground, where songs are played on the instruments).
@immutable
class RewardType {
  final String id;

  /// The rail destination it flies to; null flies onto the map.
  final RailDestination? destination;

  /// The things a reward of this type can be, as art ids, handed out in
  /// order.
  final List<String> items;

  /// Whether the item is drawn inside the diamond frame. False where the
  /// referenced art is already a diamond token.
  final bool framed;

  const RewardType(
    this.id, {
    required this.destination,
    required this.items,
    this.framed = true,
  });

  bool get onMap => destination == null;

  /// The art for the [index]th reward of this type.
  String artFor(int index) => items[index % items.length];
}

// --- The catalogue -----------------------------------------------------------
//
// DATA: adding a reward type is a row here; adding a thing it can be is an
// art id in its list. Game unlocks are RETIRED (Cooper, 2026-11): a game
// joins the library once the child has met it in the Journey, never as a
// reward.

const List<RewardType> rewardTypes = [
  // Placeholder art for both (Cooper: will change) — already diamonds.
  RewardType(
    'song',
    destination: RailDestination.playground,
    items: ['token.song'],
    framed: false,
  ),
  RewardType(
    'craft',
    destination: RailDestination.crafts,
    items: ['token.craft'],
    framed: false,
  ),
  RewardType(
    'instrument',
    destination: RailDestination.playground,
    items: [
      'instrument.piano',
      'instrument.guitar',
      'instrument.trumpet',
      'instrument.violin',
      'instrument.drum',
      'instrument.flute',
      'instrument.bell',
    ],
  ),
  // Decorations fly onto the map, as themselves, and live there as
  // tappable things. Objects and creatures alternate.
  RewardType(
    'decoration',
    destination: null,
    items: [
      'decoration.bluebird.rest',
      'decoration.mushroom.rest',
      'decoration.frog.rest',
      'decoration.acorn.rest',
      'decoration.butterfly.rest',
      'decoration.daisy.rest',
      'decoration.chipmunk.rest',
      'decoration.pine_cone.rest',
      'decoration.ladybird.rest',
      'decoration.bluebells.rest',
      'decoration.snail.rest',
      'decoration.dragonfly.rest',
    ],
  ),
];

/// The rail rewards, in the order a child is given them — a placeholder
/// schedule until the reward catalogue (card 204's open question) exists.
const List<String> railRewardRotation = ['song', 'instrument', 'craft'];

/// What a milestone adds to the map.
const String milestoneDecoration = 'decoration';

RewardType rewardTypeOf(String id) => rewardTypes.firstWhere(
  (t) => t.id == id,
  orElse: () => throw ArgumentError('No reward type "$id"'),
);

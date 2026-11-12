import 'package:flutter/widgets.dart';

import '../app/rail_destination.dart';

/// Where a reward token's art is: a region of an image. A whole file is a
/// region covering all of it, so a sheet of tokens and one-file-per-token
/// both fit.
@immutable
class TokenArt {
  final String asset;

  /// The image's pixel size.
  final Size image;

  /// The token's region in it, in pixels.
  final Rect region;

  const TokenArt(this.asset, {required this.image, required this.region});
}

/// One kind of reward: what it is, where it lives, what it looks like.
///
/// Rewards are DIAMONDS — never the rail's circles or rounded squares, so a
/// reward never reads as a navigation item. The token itself says what was
/// earned; the destination only says where it lives (songs and instruments
/// share Playground, where songs are played on the instruments).
@immutable
class RewardType {
  final String id;

  /// The rail destination it flies to; null flies onto the map.
  final RailDestination? destination;

  /// Null: no art yet (drawn as a plain diamond).
  final TokenArt? token;

  const RewardType(this.id, {required this.destination, this.token});

  bool get onMap => destination == null;
}

// --- The catalogue -----------------------------------------------------------
//
// DATA: adding a reward type is a row here; replacing its art is changing
// its `token`. Nothing else in the app names a reward image.
//
// reward_tokens_placeholder_x4.png is Cooper's PLACEHOLDER art (it will
// change): four 543×724 cells, each a 543-square diamond centred in it.

const _sheet = 'assets/images/journey/reward_tokens_placeholder_x4.png';
const _sheetSize = Size(2172, 724);
TokenArt _cell(int i) => TokenArt(
  _sheet,
  image: _sheetSize,
  region: Rect.fromLTWH(i * 543.0, 90.5, 543, 543),
);

final List<RewardType> rewardTypes = [
  RewardType(
    'game_unlock',
    destination: RailDestination.games,
    token: _cell(0),
  ),
  RewardType('craft', destination: RailDestination.crafts, token: _cell(1)),
  RewardType('song', destination: RailDestination.playground, token: _cell(2)),
  RewardType(
    'instrument',
    destination: RailDestination.playground,
    token: _cell(3),
  ),
  // No art yet; WHERE on the map it lands is open, awaiting Cooper.
  const RewardType('decoration', destination: null),
];

/// The rail rewards, in the order a child is given them — a placeholder
/// schedule until the reward catalogue (card 204's open question) exists.
const List<String> railRewardRotation = [
  'song',
  'instrument',
  'game_unlock',
  'craft',
];

/// What a milestone adds to the map.
const String milestoneDecoration = 'decoration';

RewardType rewardTypeOf(String id) => rewardTypes.firstWhere(
  (t) => t.id == id,
  orElse: () => throw ArgumentError('No reward type "$id"'),
);

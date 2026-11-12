import 'package:flutter/foundation.dart';

import '../models/agency_stage.dart';
import 'reward_catalogue.dart';

/// One earned reward: its type (see the catalogue in reward_catalogue.dart),
/// the stone it was earned on, and which one of its type it is.
@immutable
class Reward {
  final String typeId;
  final int stone;
  final int index;
  const Reward(this.typeId, this.stone, [this.index = 0]);

  RewardType get type => rewardTypeOf(typeId);
}

/// One game's share of a stone: which game, how many rounds.
@immutable
class StonePart {
  final String gameId;
  final int rounds;
  const StonePart(this.gameId, this.rounds);

  @override
  String toString() => '$gameId×$rounds';
}

/// The Journey: which stone the child is on, what they have earned, and how
/// far into the current stone they got (an X resumes, card 198 decisions).
///
/// **In memory only** for this rough build — the flows are what is being
/// judged; it resets when the app restarts. Kept per profile, so switching
/// child doesn't share a path.
class JourneyState extends ChangeNotifier {
  /// Every fifth stone is a milestone (card 204, "easily adjusted").
  static const int milestoneEvery = 5;

  /// The games a stone draws from — the two built ones. Never the same
  /// game twice in a row.
  static const List<String> games = ['high_low', 'loud_quiet'];

  final Map<String, _Progress> _byProfile = {};
  String _profile = '';

  _Progress get _p => _byProfile.putIfAbsent(_profile, _Progress.new);

  /// Switches to [profileId]'s journey (empty id: no profile).
  void useProfile(String? profileId) {
    final id = profileId ?? '';
    if (id == _profile) return;
    _profile = id;
    notifyListeners();
  }

  /// The stone the child is on (0-based). Every stone before it is done.
  int get current => _p.current;

  /// When each finished stone was finished — recorded, not gated on.
  List<DateTime> get completedAt => List.unmodifiable(_p.completedAt);

  List<Reward> get rewards => List.unmodifiable(_p.rewards);

  static bool isMilestone(int stone) => (stone + 1) % milestoneEvery == 0;

  /// The one chest on the map: behind the next milestone at or after the
  /// child's stone — always ahead, never behind (card 204).
  int get chestStone => nextMilestoneFrom(current);

  static int nextMilestoneFrom(int stone) {
    var s = stone;
    while (!isMilestone(s)) {
      s++;
    }
    return s;
  }

  int countOf(String typeId) =>
      _p.rewards.where((r) => r.typeId == typeId).length;

  /// The decorations on the map.
  List<Reward> get decorations =>
      _p.rewards.where((r) => r.type.onMap).toList();

  /// What finishing the current stone earns: one rail reward for a regular
  /// stone; two rail rewards and a decoration for a milestone, following
  /// [railRewardRotation].
  List<Reward> rewardsForCurrent() {
    final railSoFar = _p.rewards.where((r) => !r.type.onMap).length;
    final earned = <Reward>[];
    void next(String id) => earned.add(
      Reward(
        id,
        current,
        countOf(id) + earned.where((e) => e.typeId == id).length,
      ),
    );

    next(railRewardRotation[railSoFar % railRewardRotation.length]);
    if (isMilestone(current)) {
      next(railRewardRotation[(railSoFar + 1) % railRewardRotation.length]);
      next(milestoneDecoration);
    }
    return earned;
  }

  /// How many rounds a stone is, by the child's agency (3/4/5).
  static int stoneLength(AgencyStage agency) => switch (agency) {
    AgencyStage.observe => 3,
    AgencyStage.explore => 4,
    AgencyStage.decide => 5,
  };

  /// The current stone's games: its length split into runs of at most two
  /// rounds, alternating games, starting from a different game each stone.
  /// Made once per stone and kept, so leaving and coming back resumes.
  List<StonePart> planFor(AgencyStage agency) =>
      _p.plan ??= plan(current, stoneLength(agency));

  static List<StonePart> plan(int stone, int length) {
    final parts = <StonePart>[];
    var left = length;
    var g = stone % games.length;
    while (left > 0) {
      final n = left >= 2 ? 2 : 1;
      parts.add(StonePart(games[g], n));
      left -= n;
      g = (g + 1) % games.length;
    }
    return parts;
  }

  /// How many of the current stone's parts are finished.
  int get partsDone => _p.partsDone;

  void finishPart() {
    _p.partsDone++;
    notifyListeners();
  }

  /// The current stone is done: record when, bank [earned], move on.
  void completeStone(List<Reward> earned, {DateTime? at}) {
    _p
      ..completedAt.add(at ?? DateTime.now())
      ..rewards.addAll(earned)
      ..current += 1
      ..plan = null
      ..partsDone = 0;
    notifyListeners();
  }

  /// Dev only: back to the first stone with nothing earned.
  void reset() {
    _byProfile.remove(_profile);
    notifyListeners();
  }
}

class _Progress {
  int current = 0;
  final List<DateTime> completedAt = [];
  final List<Reward> rewards = [];
  List<StonePart>? plan;
  int partsDone = 0;
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;

import '../models/agency_stage.dart';

/// Where an earned reward goes. Every category but [decoration] is one of
/// the rail's destinations (the rail is top-level navigation: Journey,
/// Games, Crafts, Playground — Cooper's composite, superseding card 204's
/// shelves). Songs have no shelf of their own: they land in Playground.
/// Decorations fly onto the map, on ground already walked.
///
/// The icons are for the PLACEHOLDER reward items until the reward
/// catalogue exists.
enum RewardCategory {
  playground('Playground', Icons.music_note_rounded),
  games('Games', Icons.extension_rounded),
  crafts('Crafts', Icons.content_cut_rounded),
  decoration('Map', Icons.local_florist_rounded);

  final String label;
  final IconData icon;
  const RewardCategory(this.label, this.icon);

  bool get onMap => this == decoration;

  /// The rail categories, in the order they are handed out.
  static const rail = [playground, games, crafts];
}

/// One earned reward. [stone] is the stone it was earned on — where a
/// decoration lands on the map.
@immutable
class Reward {
  final RewardCategory category;
  final int stone;
  const Reward(this.category, this.stone);
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

  int countIn(RewardCategory c) =>
      _p.rewards.where((r) => r.category == c).length;

  /// The decorations on the map.
  List<Reward> get decorations =>
      _p.rewards.where((r) => r.category.onMap).toList();

  /// What finishing the current stone earns: one rail reward for a regular
  /// stone; two rail rewards and a decoration for a milestone. The rail
  /// categories are handed out in turn, so each new one is an event.
  /// PLACEHOLDER catalogue — the real one is card 204's open question.
  List<Reward> rewardsForCurrent() {
    final railSoFar = _p.rewards.where((r) => !r.category.onMap).length;
    Reward railAt(int k) => Reward(
      RewardCategory.rail[(railSoFar + k) % RewardCategory.rail.length],
      current,
    );
    if (!isMilestone(current)) return [railAt(0)];
    return [railAt(0), railAt(1), Reward(RewardCategory.decoration, current)];
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

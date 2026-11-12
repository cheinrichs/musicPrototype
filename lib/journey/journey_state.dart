import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;

import '../app/rail_destination.dart';
import '../models/agency_stage.dart';

/// What a reward IS — and from that, where it lives.
///
/// The rail is top-level navigation (Journey, Games, Crafts, Playground).
/// Songs and new instruments both live in Playground, so the destination no
/// longer tells a child what they earned: the flying object must (see
/// `RewardItem`). Decorations fly onto the map; WHERE on the map is open,
/// awaiting Cooper.
///
/// The icons are for the reward items still drawn as PLACEHOLDERS.
enum RewardKind {
  song(RailDestination.playground, Icons.music_note_rounded),
  instrument(RailDestination.playground, Icons.piano_rounded),
  game(RailDestination.games, Icons.extension_rounded),
  craft(RailDestination.crafts, Icons.content_cut_rounded),
  decoration(null, Icons.local_florist_rounded);

  /// Null: onto the map.
  final RailDestination? destination;
  final IconData icon;
  const RewardKind(this.destination, this.icon);

  bool get onMap => destination == null;

  /// The rail rewards, in the order they are handed out (a PLACEHOLDER
  /// catalogue).
  static const rail = [song, instrument, game, craft];
}

/// One earned reward. [stone] is the stone it was earned on; [index] picks
/// which one of its kind (which instrument, say).
@immutable
class Reward {
  final RewardKind kind;
  final int stone;
  final int index;
  const Reward(this.kind, this.stone, [this.index = 0]);
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

  int countOf(RewardKind k) => _p.rewards.where((r) => r.kind == k).length;

  /// The decorations on the map.
  List<Reward> get decorations =>
      _p.rewards.where((r) => r.kind.onMap).toList();

  /// What finishing the current stone earns: one rail reward for a regular
  /// stone; two rail rewards and a decoration for a milestone, handed out
  /// in turn. PLACEHOLDER catalogue — the real one is card 204's open
  /// question.
  List<Reward> rewardsForCurrent() {
    final railSoFar = _p.rewards.where((r) => !r.kind.onMap).length;
    final earned = <Reward>[];
    Reward next(RewardKind k) {
      final r = Reward(
        k,
        current,
        countOf(k) + earned.where((e) => e.kind == k).length,
      );
      earned.add(r);
      return r;
    }

    next(RewardKind.rail[railSoFar % RewardKind.rail.length]);
    if (isMilestone(current)) {
      next(RewardKind.rail[(railSoFar + 1) % RewardKind.rail.length]);
      next(RewardKind.decoration);
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

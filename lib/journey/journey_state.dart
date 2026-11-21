import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// The art for this reward: the thing itself, by id.
  String get artId => type.artFor(index);
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
/// **Saved on the device, per profile** (2026-11-21), so a child's path,
/// rewards and an unclaimed chest survive the app closing — losing them
/// would punish leaving. It was in memory only until then, and reset
/// whenever iOS closed the app. [load] reads it at startup; every change
/// writes it back ([_save]).
class JourneyState extends ChangeNotifier {
  /// A chest sits ON every sixth stone (Cooper, 2026-11-21: "the treasure
  /// chest should sit on the stone, and it should be every 6th stone").
  static const int milestoneEvery = 6;

  /// The games a stone draws from — the two built ones. Never the same
  /// game twice in a row.
  static const List<String> games = ['high_low', 'loud_quiet'];

  final Map<String, _Progress> _byProfile = {};
  String _profile = '';

  static const String _storageKey = 'journey_v1';

  /// Reads every profile's journey. A profile touched before this finished
  /// (only possible in the first instant after launch) keeps what it has
  /// unless it is still untouched.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      json.forEach((id, value) {
        final existing = _byProfile[id];
        if (existing == null || existing.isUntouched) {
          _byProfile[id] = _Progress.fromJson(value as Map<String, dynamic>);
        }
      });
      notifyListeners();
    } catch (e) {
      debugPrint('Journey: could not load saved progress ($e)');
    }
  }

  /// Writes every profile's journey. Best effort: a failed write is logged,
  /// never thrown into a celebration. Writes are CHAINED, so they land in
  /// the order they were made: two quick saves racing could otherwise leave
  /// the older snapshot as the last one written.
  void _save() {
    final data = jsonEncode({
      for (final e in _byProfile.entries) e.key: e.value.toJson(),
    });
    _writing = _writing.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, data);
      } catch (e) {
        debugPrint('Journey: could not save progress ($e)');
      }
    });
  }

  Future<void> _writing = Future.value();

  /// Resolves once every save made so far has been written.
  @visibleForTesting
  Future<void> get saved => _writing;

  @override
  void notifyListeners() {
    _save();
    super.notifyListeners();
  }

  _Progress get _p => _byProfile.putIfAbsent(_profile, _Progress.new);

  /// Switches to [profileId]'s journey (empty id: no profile). The picker
  /// does this as a child is chosen. [notify] false is for a screen's
  /// initState, which reads the new journey as it first builds and must not
  /// notify mid-build (a framework assertion).
  void useProfile(String? profileId, {bool notify = true}) {
    final id = profileId ?? '';
    if (id == _profile) return;
    _profile = id;
    if (notify) notifyListeners();
  }

  /// The stone the child is on (0-based). Every stone before it is done.
  int get current => _p.current;

  /// When each finished stone was finished — recorded, not gated on.
  List<DateTime> get completedAt => List.unmodifiable(_p.completedAt);

  List<Reward> get rewards => List.unmodifiable(_p.rewards);

  /// Whether a chest sits on [stone]: every sixth (indices 5, 11, 17…).
  static bool isChestStone(int stone) => (stone + 1) % milestoneEvery == 0;

  /// Whether finishing [stone] claims a chest: the stone BEFORE a chest
  /// stone (Cooper, 2026-11-21: "When the child completes the 5th stone
  /// the treasure chest hops up … the kid taps it, the rewards fly to their
  /// place, and then the characters all progress onto the 6th stone").
  static bool isMilestone(int stone) => isChestStone(stone + 1);

  /// The one chest on the map: on the next chest stone AHEAD of the child —
  /// never the one they stand on, whose chest they claimed to get there
  /// (card 204: always ahead, never behind).
  int get chestStone => nextChestFrom(current + 1);

  /// The first chest stone at or after [stone].
  static int nextChestFrom(int stone) {
    var s = stone;
    while (!isChestStone(s)) {
      s++;
    }
    return s;
  }

  /// The current stone is played and its chest is waiting to be tapped:
  /// SAVED, so a child who leaves before tapping comes back to the same
  /// chest, still theirs (never lost for leaving). Cleared when it is
  /// claimed ([completeStone]).
  bool get chestPending => _p.chestPending;

  /// The current (milestone) stone's games are all played; its chest now
  /// waits for the tap.
  void awaitChest() {
    assert(isMilestone(current));
    _p.chestPending = true;
    notifyListeners();
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
  List<StonePart> planFor(AgencyStage agency) {
    final existing = _p.plan;
    if (existing != null) return existing;
    final made = _p.plan = plan(current, stoneLength(agency));
    _save();
    return made;
  }

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

  /// The games the child has met in the Journey — what lets a game into
  /// their Games library (see `GameLibrary`). Recording a meeting never
  /// changes which games a stone can draw: [games] is fixed.
  Set<String> get gamesMet => Set.unmodifiable(_p.gamesMet);

  void meet(String gameId) {
    if (_p.gamesMet.add(gameId)) notifyListeners();
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
      ..partsDone = 0
      ..chestPending = false;
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
  final Set<String> gamesMet = {};
  bool chestPending = false;

  _Progress();

  bool get isUntouched =>
      current == 0 && rewards.isEmpty && partsDone == 0 && gamesMet.isEmpty;

  Map<String, dynamic> toJson() => {
    'current': current,
    'completedAt': [for (final d in completedAt) d.toIso8601String()],
    'rewards': [
      for (final r in rewards)
        {'type': r.typeId, 'stone': r.stone, 'i': r.index},
    ],
    'plan': plan == null
        ? null
        : [
            for (final p in plan!) {'game': p.gameId, 'rounds': p.rounds},
          ],
    'partsDone': partsDone,
    'gamesMet': gamesMet.toList(),
    'chestPending': chestPending,
  };

  factory _Progress.fromJson(Map<String, dynamic> j) {
    final p = _Progress()
      ..current = j['current'] as int? ?? 0
      ..partsDone = j['partsDone'] as int? ?? 0
      ..chestPending = j['chestPending'] as bool? ?? false;
    p.completedAt.addAll([
      for (final d in (j['completedAt'] as List? ?? const []))
        DateTime.parse(d as String),
    ]);
    p.rewards.addAll([
      for (final r in (j['rewards'] as List? ?? const []))
        Reward(
          (r as Map)['type'] as String,
          r['stone'] as int,
          r['i'] as int? ?? 0,
        ),
    ]);
    final plan = j['plan'] as List?;
    p.plan = plan == null
        ? null
        : [
            for (final s in plan)
              StonePart((s as Map)['game'] as String, s['rounds'] as int),
          ];
    p.gamesMet.addAll([
      for (final g in (j['gamesMet'] as List? ?? const [])) g as String,
    ]);
    return p;
  }
}

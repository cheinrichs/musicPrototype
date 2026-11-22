import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agency_stage.dart';
import 'high_low/models/round_instrumentation.dart';

/// One round's worth of TIER evidence (Cooper, 2026-11-22: "mirroring the
/// agency rules for tier advancement", with tier's own numbers).
///
/// - [right] / [wrong]: the round's FIRST ANSWER (the first tap at Explore,
///   the first drop at Decide), given after both sounds had finished.
/// - [skipped]: the adult skipped it. NEUTRAL, as for agency (card 213): it
///   takes a slot in the window but never counts as right — neutral, not
///   free.
enum TierSlot {
  right('r'),
  wrong('w'),
  skipped('s');

  const TierSlot(this.code);
  final String code;

  static TierSlot? byCode(String c) {
    for (final s in values) {
      if (s.code == c) return s;
    }
    return null;
  }
}

/// Which rounds are tier evidence, and what each says.
abstract final class TierEvidence {
  /// The PROMOTION window: the last this-many slots in a game (skips
  /// included, as neutral slots), at the child's current level there.
  static const int window = 10;

  /// How many slots are kept: enough for the DEMOTION window, which is the
  /// last 10 ANSWERED rounds (skips excluded), with room for skips.
  static const int kept = 20;

  /// What [round], played at [agency], says about the child's hearing, or
  /// null when it says nothing:
  /// - **Observe**: no answer exists — never evidence.
  /// - **left the set** mid-round: not evidence.
  /// - **skipped**: a neutral slot.
  /// - **no first answer**, or one given **before the sounds had finished**
  ///   (the invalid-round rule, card 171): not evidence, right or wrong.
  /// Intro rounds would be excluded here too; none exist in the code today.
  static TierSlot? slotFor(RoundInstrumentation round, AgencyStage agency) {
    if (round.leftSet) return null;
    if (round.skipped) return TierSlot.skipped;
    if (agency == AgencyStage.observe) return null;
    final correct = round.firstResponseCorrect;
    if (correct == null) return null;
    final heard =
        round.notesHeardBeforeFirstResponse ?? round.waitedForPlaythrough;
    if (!heard) return null;
    return correct ? TierSlot.right : TierSlot.wrong;
  }
}

/// One child's evidence in one game, at one level.
class GameTierRecord {
  /// The level these slots were earned at. Evidence at another level is
  /// not evidence for this one: a level change clears the slots.
  int level;
  final List<TierSlot> slots;

  GameTierRecord({required this.level, List<TierSlot>? slots})
    : slots = slots ?? [];

  /// The promotion window: the last [TierEvidence.window] slots.
  List<TierSlot> get recent => slots.length <= TierEvidence.window
      ? slots
      : slots.sublist(slots.length - TierEvidence.window);

  /// Right answers in the promotion window.
  int get rights => recent.where((s) => s == TierSlot.right).length;

  /// The last [count] ANSWERED rounds (skips left out), oldest first.
  List<TierSlot> lastAnswered(int count) {
    final answered = [
      for (final s in slots)
        if (s != TierSlot.skipped) s,
    ];
    return answered.length <= count
        ? answered
        : answered.sublist(answered.length - count);
  }

  /// "6 right of 10" — how far along the window is, for an adult.
  String get summary =>
      '$rights right of ${recent.length}'
      '${recent.length < TierEvidence.window ? ' (window ${TierEvidence.window})' : ''}';

  void add(TierSlot slot) {
    slots.add(slot);
    while (slots.length > TierEvidence.kept) {
      slots.removeAt(0);
    }
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'slots': slots.map((s) => s.code).join(),
  };

  factory GameTierRecord.fromJson(Map<String, dynamic> j) => GameTierRecord(
    level: j['level'] as int? ?? 0,
    slots: [
      for (final c in (j['slots'] as String? ?? '').split(''))
        ?TierSlot.byCode(c),
    ],
  );
}

/// One child's tier evidence, every game, plus what the agency lockout and
/// the record of decisions need.
class ChildTierRecord {
  final Map<String, GameTierRecord> games;

  /// Sets finished since the set in which this child's agency last
  /// changed (0 = it changed in the set just finished). Large until it
  /// first changes.
  int setsSinceAgencyChange;

  /// The latest decisions and their reasons, newest last — so "why is
  /// this child not moving" is answered from data.
  final List<String> log;

  ChildTierRecord({
    Map<String, GameTierRecord>? games,
    this.setsSinceAgencyChange = 1 << 20,
    List<String>? log,
  }) : games = games ?? {},
       log = log ?? [];

  static const int logLength = 30;

  void note(String line) {
    log.add(line);
    while (log.length > logLength) {
      log.removeAt(0);
    }
  }

  Map<String, dynamic> toJson() => {
    'games': {for (final e in games.entries) e.key: e.value.toJson()},
    'setsSinceAgencyChange': setsSinceAgencyChange,
    'log': log,
  };

  factory ChildTierRecord.fromJson(Map<String, dynamic> j) => ChildTierRecord(
    games: {
      for (final e in ((j['games'] as Map?) ?? const {}).entries)
        e.key as String: GameTierRecord.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        ),
    },
    setsSinceAgencyChange: j['setsSinceAgencyChange'] as int? ?? 1 << 20,
    log: [for (final l in (j['log'] as List? ?? const [])) l as String],
  );
}

/// Every child's tier evidence, saved on the device (one key, by profile
/// id). Recording only: what decides a level change is TierAdvancement.
class TierProgressState extends ChangeNotifier {
  static const String _storageKey = 'tier_evidence_v1';

  final Map<String, ChildTierRecord> _byProfile = {};

  ChildTierRecord recordOf(String profileId) =>
      _byProfile.putIfAbsent(profileId, ChildTierRecord.new);

  /// [profileId]'s evidence in [gameId], if any — read only.
  GameTierRecord? gameRecord(String profileId, String gameId) =>
      _byProfile[profileId]?.games[gameId];

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      json.forEach((id, value) {
        _byProfile.putIfAbsent(
          id,
          () => ChildTierRecord.fromJson(Map<String, dynamic>.from(value)),
        );
      });
      notifyListeners();
    } catch (e) {
      debugPrint('Tier evidence: could not load ($e)');
    }
  }

  /// Adds one game's rounds from a finished set to [profileId]'s evidence.
  /// Only rounds played AT the child's level count ([playedLevel] equals
  /// [childLevel]); a record kept at another level starts again.
  void recordRounds({
    required String profileId,
    required String gameId,
    required int childLevel,
    required int? playedLevel,
    required AgencyStage agency,
    required List<RoundInstrumentation> rounds,
  }) {
    final record = recordOf(profileId);
    final game = record.games.putIfAbsent(
      gameId,
      () => GameTierRecord(level: childLevel),
    );
    if (game.level != childLevel) {
      game
        ..level = childLevel
        ..slots.clear();
    }
    if (playedLevel != childLevel) return;
    for (final r in rounds) {
      final slot = TierEvidence.slotFor(r, agency);
      if (slot != null) game.add(slot);
    }
    _changed();
  }

  /// A set finished: [agencyChanged] says whether it moved the child's
  /// agency, for the lockout.
  void finishSet(String profileId, {required bool agencyChanged}) {
    final record = recordOf(profileId);
    record.setsSinceAgencyChange = agencyChanged
        ? 0
        : record.setsSinceAgencyChange + 1;
    _changed();
  }

  /// Adds a line to [profileId]'s decision log.
  void note(String profileId, String line) {
    recordOf(profileId).note(line);
    _changed();
  }

  /// [profileId] has moved to [level] in [gameId]: the window starts again,
  /// since evidence at one level is not evidence for another.
  void startLevel(String profileId, String gameId, int level) {
    recordOf(profileId).games[gameId] = GameTierRecord(level: level);
    _changed();
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  Future<void> _writing = Future.value();

  /// Resolves once every save so far has been written.
  @visibleForTesting
  Future<void> get saved => _writing;

  void _save() {
    final data = jsonEncode({
      for (final e in _byProfile.entries) e.key: e.value.toJson(),
    });
    _writing = _writing.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, data);
      } catch (e) {
        debugPrint('Tier evidence: could not save ($e)');
      }
    });
  }
}

/// What one tier evaluation recommends.
enum TierChange { promote, demote, hold }

class TierEvaluation {
  final TierChange change;
  final String reason;
  const TierEvaluation(this.change, this.reason);
}

/// Decides whether a child's level in one game moves — the SAME mechanism
/// as agency (`AgencyAdvancement`: count qualifying rounds against a share,
/// in any order, skips neutral), with tier's own, stricter numbers, because
/// the costs are not symmetric: promoting agency too early only changes how
/// the child acts; promoting tier too early puts them in sounds they cannot
/// tell apart, and nothing tells them why (Cooper, 2026-11-22).
///
/// | | agency | tier |
/// |---|---|---|
/// | evidence | one set (3–5 rounds) | the last [TierEvidence.window] rounds of this game at this level, across sets |
/// | promote at | 60% of the set (3 of 5) | [promotionRights] of [TierEvidence.window] right |
/// | a guessing child passes one check | ~50% | ~5.5% (8 of 10 on a two-way choice) |
///
/// ⚠️ EVALUATED ONCE PER SET, AT THE SET'S END — NEVER AFTER EVERY ROUND.
/// The 5.5% is the chance a guessing child passes ONE check. Re-checking a
/// rolling window after every round gives them a fresh chance each round,
/// and over a few dozen rounds a guesser passes almost surely. Checking at
/// set boundaries keeps the checks few and the figure honest. Do not
/// "improve" this to continuous evaluation.
///
/// - **Lockout** (the zigzag rule, "one new demand per step"): no tier
///   PROMOTION in a set in which agency changed, nor in the [lockoutSets]
///   set after it. Agency goes first; the evidence keeps building, so the
///   tier rises at the first set allowed.
/// - **Demotion** has no lockout: it only ever eases, and a child stranded
///   above their hearing cannot say so.
abstract final class TierAdvancement {
  /// Right answers needed in a full window to promote (Cooper: "8/10").
  static const int promotionRights = 8;

  /// DEMOTION (Cooper, 2026-11-22: "let's change to the 40% at 10 rounds"):
  /// over the last [demotionAnswered] ANSWERED rounds at this level, demote
  /// when the share right is at or below chance minus
  /// [demotionMarginBelowChance] — "clearly below chance". Chance comes from
  /// the level's number of choices ([chance]): 50% with two, so the bar is
  /// 40% (4 of 10); a third with three, so about 23% (2 of 10). The rule is
  /// written once; three-note levels need no rewrite.
  ///
  /// ⚠️ DO NOT LOOSEN THIS BACK. The check runs again at EVERY set, so its
  /// per-check odds compound. The old rule (at or below half of 8)
  /// demoted a child of true 65% ability 29% of the time per check and a
  /// 75% child 11% — over enough sets it would have demoted almost every
  /// child, whatever their ability. This rule: a 65% child 9.5%, a 75%
  /// child 2%. A child genuinely at chance is still demoted 38% of the time
  /// per check, so because the check repeats, a real struggler is caught
  /// within two or three sets. A looser bar buys nothing and guarantees
  /// false demotions over time.
  static const int demotionAnswered = 10;
  static const double demotionMarginBelowChance = 0.10;

  /// The chance of a guess being right with [choices] options.
  static double chance(int choices) => 1 / choices;

  /// The most right answers out of [demotionAnswered] that still demote.
  static int demotionMaxRights(int choices) =>
      ((chance(choices) - demotionMarginBelowChance) * demotionAnswered + 1e-9)
          .floor();

  /// Sets after an agency change in which a tier promotion waits.
  static const int lockoutSets = 1;

  static TierEvaluation evaluate({
    required GameTierRecord record,
    required int level,
    required int ceiling,
    required int setsSinceAgencyChange,
    required String label,
    int choices = 2,
  }) {
    final rights = record.rights;
    final n = record.recent.length;

    final lastAnswered = record.lastAnswered(demotionAnswered);
    final answeredRights = lastAnswered
        .where((s) => s == TierSlot.right)
        .length;
    final maxRights = demotionMaxRights(choices);
    if (level > 0 &&
        lastAnswered.length >= demotionAnswered &&
        answeredRights <= maxRights) {
      return TierEvaluation(
        TierChange.demote,
        '$answeredRights right of the last $demotionAnswered answered at '
        '$label — clearly below chance ($maxRights or fewer of '
        '$demotionAnswered with $choices choices)',
      );
    }
    if (n < TierEvidence.window || rights < promotionRights) {
      return TierEvaluation(
        TierChange.hold,
        '$rights right of $n at $label '
        '($promotionRights of ${TierEvidence.window} needed)',
      );
    }
    if (level >= ceiling) {
      return TierEvaluation(
        TierChange.hold,
        '$rights right of $n at $label, at the ceiling',
      );
    }
    if (setsSinceAgencyChange <= lockoutSets) {
      return TierEvaluation(
        TierChange.hold,
        '$rights right of $n at $label, earned — waiting: agency changed '
        '${setsSinceAgencyChange == 0 ? 'this set' : 'last set'}',
      );
    }
    return TierEvaluation(TierChange.promote, '$rights right of $n at $label');
  }
}

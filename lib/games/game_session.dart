import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../app/state/dev_settings_state.dart';
import '../app/state/profile_state.dart';
import '../app/state/progress_state.dart';
import '../models/agency_stage.dart';
import '../models/concept_tier.dart';
import '../models/round_set_length.dart';
import 'high_low/models/round_instrumentation.dart';
import 'high_low/services/agency_advancement.dart';

/// How a set of a game is started — the one interface every game takes, so
/// anything that launches games (the games screen today, a Journey stone
/// next) asks for the same three things the same way.
///
/// - [agency] is the child's, and global — one value per child, never per
///   game (decided for the Journey, cards 198/199).
/// - [tier] is the concept tier to play at; null leaves it to the game.
/// - [rounds] is how many rounds the set runs. A stone will ask for exact
///   counts (one Observe round, one Explore round); the games screen asks
///   for the per-agency length (card 196).
/// - [onFinished], when given, is where the set's [SetReport] goes INSTEAD of
///   the game recording it and leaving. A stone hosts games this way: it
///   needs the rounds back, to judge promotion over the whole stone (without
///   its intro rounds) and to choose what comes next.
/// What the progress bar counts — said where the game is entered, never
/// inferred (Cooper on device: inside a stone each game started its own
/// count, and the bar fought the stone).
///
/// - [ProgressSource.ownSet]: entered from the library. The bar counts the
///   game's own round set (card 196's 3/4/5 by agency).
/// - [ProgressSource.stone]: entered from a Journey stone. The bar counts
///   the STONE: [total] is the stone's round count, [doneBefore] the rounds
///   its earlier games already played, and a round of any game moves it
///   exactly one step. Per-game set counting does not apply inside a stone.
@immutable
class ProgressSource {
  final int? total;
  final int doneBefore;

  const ProgressSource.ownSet() : total = null, doneBefore = 0;

  const ProgressSource.stone({
    required int this.total,
    required this.doneBefore,
  }) : assert(doneBefore <= total);

  bool get isStone => total != null;

  /// The bar's fill, 0 to 1, given how far the game is through its own
  /// rounds: [ownFraction] (its own set's fill) and [roundsDone] of
  /// [rounds].
  double fill({
    required double ownFraction,
    required int roundsDone,
    required int rounds,
  }) {
    final t = total;
    if (t == null) return ownFraction;
    if (t == 0) return 1;
    return ((doneBefore + roundsDone.clamp(0, rounds)) / t).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      other is ProgressSource &&
      other.total == total &&
      other.doneBefore == doneBefore;

  @override
  int get hashCode => Object.hash(total, doneBefore);
}

@immutable
class GameEntry {
  final AgencyStage agency;
  final ConceptTier? tier;
  final int rounds;

  /// What the progress bar counts — required, so every way into a game
  /// says which.
  final ProgressSource progress;
  final void Function(SetReport report)? onFinished;

  /// Where the X goes when something hosts this set, instead of home: a
  /// stone takes the child back to the map, keeping their place so the
  /// stone resumes rather than restarts.
  final VoidCallback? onLeave;

  const GameEntry({
    required this.agency,
    this.tier,
    required this.rounds,
    required this.progress,
    this.onFinished,
    this.onLeave,
  });

  /// Whether something hosts this set and takes its report.
  bool get hosted => onFinished != null;

  /// The active child's own set: their agency (Observe with no profile — the
  /// least demanding level), at the live per-agency round count.
  factory GameEntry.forActiveChild(BuildContext context) {
    final agency =
        _read<ProfileState>(context)?.activeProfile?.agencyOverride ??
        AgencyStage.observe;
    final lengths =
        _read<DevSettingsState>(context)?.roundSetLength ??
        RoundSetLength.standard;
    return GameEntry(
      agency: agency,
      rounds: lengths.lengthFor(agency),
      progress: const ProgressSource.ownSet(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameEntry &&
      other.agency == agency &&
      other.tier == tier &&
      other.rounds == rounds &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(agency, tier, rounds, progress);

  @override
  String toString() => 'GameEntry($agency, $tier, $rounds rounds)';
}

/// What a game reports when its set ends: enough for whatever launched it to
/// count it, move the child's agency, and (for a stone) know how many of its
/// rounds the child actually played.
@immutable
class SetReport {
  /// The game's progress key ('high_low', 'loud_quiet').
  final String gameType;
  final AgencyStage agency;

  /// Every round of the set, skipped ones included.
  final List<RoundInstrumentation> rounds;
  final int correctCount;

  const SetReport({
    required this.gameType,
    required this.agency,
    required this.rounds,
    required this.correctCount,
  });

  /// Rounds the adult's Skip ended.
  int get skipped => rounds.where((r) => r.skipped).length;

  /// Rounds the child finished.
  int get completed => rounds.length - skipped;
}

/// What happens when any game's set ends, the same in every game.
abstract final class GameSession {
  /// Counts the session and runs agency advancement against it, writing a
  /// change back to the active profile. Returns the evaluation, or null with
  /// no active profile (dev-gate sessions and most widget tests) — a session
  /// with no child behind it has nowhere to persist a capability change.
  ///
  /// Agency is the child's, not the game's, so every game updates the same
  /// profile value; a Journey moving a child between games depends on that.
  /// The reason for a change is only [debugPrint]ed until the tracking log
  /// exists to receive it.
  static AgencyEvaluation? recordFinishedSet(
    BuildContext context,
    SetReport report,
  ) {
    _read<ProgressState>(context)?.completeSession(
      gameType: report.gameType,
      correctCount: report.correctCount,
      totalCount: report.rounds.length,
    );

    final profiles = _read<ProfileState>(context);
    final profile = profiles?.activeProfile;
    if (profiles == null || profile == null) return null;
    final current = profile.agencyOverride ?? AgencyStage.observe;
    final evaluation = AgencyAdvancement.evaluate(
      current: current,
      instrumentation: report.rounds,
    );
    final next = switch (evaluation.change) {
      AgencyChange.advance => current.next,
      AgencyChange.demote => current.previous,
      AgencyChange.hold => null,
    };
    if (next != null) {
      debugPrint(
        'Agency ${evaluation.change.name} (${report.gameType}): '
        '${profile.name} ${current.label} -> ${next.label} '
        '(${evaluation.reason})',
      );
      profiles.setAgencyOverride(profile, next);
    }
    return evaluation;
  }
}

/// The app always provides these; tests without them get null.
T? _read<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

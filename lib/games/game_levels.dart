/// Pure Dart: each game's own difficulty ladder, as a LEVEL — a 0-based
/// index into that game's ladder (Cooper's rule: agency is global, concept
/// tier is PER GAME).
///
/// - High vs Low: [ConceptTier] T1–T8, level 0–7.
/// - Loud or Quiet: its [DynamicLadder] steps, level 0–5.
///
/// A child's levels live on their profile (`Profile.levels`); a game they
/// have not been moved in is level 0. Nothing is inferred from history:
/// every child starts at level 0 and climbs (Cooper, 2026-11-22).
library;

import '../models/agency_stage.dart';
import '../models/concept_tier.dart';
import 'loud_quiet/models/dynamic_ladder.dart';

abstract final class GameLevels {
  static const String highLow = 'high_low';
  static const String loudQuiet = 'loud_quiet';

  /// The highest level play may move a child to in [gameId].
  ///
  /// ⚠️ HIGH VS LOW CAPS AT T4 (level 3) until the three-note "which is
  /// highest" layout exists: T5–T8 generate, but the main screen shows a
  /// "not built" placeholder for them (Cooper, 2026-11-22). Raising the cap
  /// is this one number once that layout lands.
  static int ceilingOf(String gameId) => switch (gameId) {
    highLow => 3,
    loudQuiet => 5,
    _ => 0,
  };

  /// The highest level a child at [agency] can actually PLAY in [gameId],
  /// within [ceilingOf]. Promotion stops here: a level above it would be
  /// played lower, so no round would ever count again and the child could
  /// neither climb nor come back down (High vs Low: Observe plays T1 only,
  /// Explore two notes only; Loud or Quiet: three instruments need Decide).
  static int playableCeiling(String gameId, AgencyStage agency) {
    final ceiling = ceilingOf(gameId);
    final reachable = switch (gameId) {
      highLow => ConceptTier.highestReachableAt(agency).index,
      loudQuiet => DynamicLadder.standard.clampedTo(ceiling, agency),
      _ => 0,
    };
    return reachable < ceiling ? reachable : ceiling;
  }

  /// [level] brought onto [gameId]'s playable ladder.
  static int clamp(String gameId, int level) =>
      level.clamp(0, ceilingOf(gameId));

  /// How a level reads to an adult: "T2" for High vs Low, "step 3" for
  /// Loud or Quiet.
  static String label(String gameId, int level) => switch (gameId) {
    highLow => 'T${level + 1}',
    _ => 'step ${level + 1}',
  };
}

import '../models/agency_stage.dart';
import '../models/concept_tier.dart';
import '../games/loud_quiet/models/dynamic_ladder.dart';
import 'csv_table.dart';
import 'curriculum_data.g.dart';

/// The curriculum, read from the repo's data files (Trello card 219: the
/// spreadsheet is retired; changes now go through CI).
///
/// **Vocabulary (card 219).** A SKILL NODE groups games ("Pitch Awareness").
/// A GAME is one way of teaching one thing ("Higher vs Lower"). A ROUND is
/// one playthrough. A STONE is rounds drawn from several games — not a node.
///
/// **Tier is per game.** Each game owns its own ladder, of its own length:
/// High vs Low has eight tiers, the sheet's games four. A tier number means
/// nothing outside its game.

/// The sheet's five agency levels mapped onto the app's three (card 219: the
/// app wins). Timed (A3) and Precision (A4) were dropped from the app — timing
/// became telemetry — so both read as Decide, the highest level there is.
AgencyStage agencyFromSheet(String code) {
  final level = code.trim().toUpperCase();
  if (level.startsWith('A0')) return AgencyStage.observe;
  if (level.startsWith('A1')) return AgencyStage.explore;
  if (level.startsWith('A2') ||
      level.startsWith('A3') ||
      level.startsWith('A4')) {
    return AgencyStage.decide;
  }
  throw FormatException('Unknown agency level "$code"');
}

/// A game that exists in the app, and the name the curriculum knows it by.
class CurriculumGame {
  /// The app's id — the same key progress and set reports use.
  final String id;

  /// The game's name in the curriculum (card 219's vocabulary).
  final String name;
  final String skillNode;

  /// This game's own tier ladder, lowest first, and the agency each tier
  /// first becomes reachable at. Authored here, not imported: the app's
  /// ladder wins over the sheet's four tiers.
  final List<AgencyStage> tierMinAgency;

  const CurriculumGame({
    required this.id,
    required this.name,
    required this.skillNode,
    required this.tierMinAgency,
  });

  int get tierCount => tierMinAgency.length;
}

/// The lowest agency at which each [ConceptTier] is reachable — High vs
/// Low's rule.
final List<AgencyStage> _conceptTierLadder = [
  for (final tier in ConceptTier.values)
    AgencyStage.values.firstWhere(tier.isReachableAt),
];

/// Loud or Quiet's own ladder (card 220): its three dynamic-distance steps,
/// none gated by agency — the game plays any step at any agency.
final List<AgencyStage> _dynamicLadder = [
  for (final _ in DynamicLadder.standard.steps) AgencyStage.observe,
];

/// The games the app has built and rebuilt with the agency levels. The seven
/// older games stay out until they are (Cooper, 2026-10-18).
final List<CurriculumGame> builtGames = [
  CurriculumGame(
    id: 'high_low',
    name: 'Higher vs Lower',
    skillNode: 'Pitch Awareness',
    tierMinAgency: _conceptTierLadder,
  ),
  CurriculumGame(
    id: 'loud_quiet',
    name: 'Loud vs Soft',
    skillNode: 'Sound Awareness',
    tierMinAgency: _dynamicLadder,
  ),
];

/// One row of the requirements table: at [tier] of [game], who can play it.
class GameRequirement {
  final String skillNode;
  final String game;
  final int tier;
  final AgencyStage minAgency;
  final AgencyStage maxAgency;

  /// The prerequisite the spreadsheet authored, kept for reference only. It
  /// does NOT gate anything — see [Eligibility.prerequisites].
  final String sheetPrerequisite;

  const GameRequirement({
    required this.skillNode,
    required this.game,
    required this.tier,
    required this.minAgency,
    required this.maxAgency,
    this.sheetPrerequisite = '',
  });

  /// The token prerequisites are written in: `Higher vs Lower_T1`.
  String get token => tierToken(game, tier);
}

String tierToken(String game, int tier) => '${game}_T$tier';

/// The requirements table the app runs on: the authored sheet, GENERATED
/// into Dart at build time (tool/generate_curriculum.dart — never a CSV
/// parsed on a device), with the built games' rows written from their own
/// ladders.
final List<GameRequirement> requirements = withBuiltGames(
  sheetRequirements,
  builtGames,
);

/// [sheet] with the rows for [games] replaced by rows written from each
/// game's own ladder — the sheet's tier numbers do not describe the app's
/// ladders.
List<GameRequirement> withBuiltGames(
  List<GameRequirement> sheet,
  List<CurriculumGame> games,
) {
  final built = {for (final g in games) g.name};
  return [
    for (final r in sheet)
      if (!built.contains(r.game)) r,
    for (final g in games)
      for (var i = 0; i < g.tierCount; i++)
        GameRequirement(
          skillNode: g.skillNode,
          game: g.name,
          tier: i + 1,
          minAgency: g.tierMinAgency[i],
          maxAgency: AgencyStage.decide,
        ),
  ];
}

/// Reads the Skill Progression table (columns Node, Skill, Tier, MinAgency,
/// MaxAgency, Prerequisite), remapping agency — at BUILD time, by the
/// generator; and, given [games], replaces their rows as [withBuiltGames].
List<GameRequirement> parseSkillProgression(
  String csv, {
  List<CurriculumGame> games = const [],
}) => withBuiltGames([
  for (final row in parseCsvTable(csv))
    GameRequirement(
      skillNode: row['Node']!,
      game: row['Skill']!,
      tier: int.parse(row['Tier']!),
      minAgency: agencyFromSheet(row['MinAgency']!),
      maxAgency: agencyFromSheet(row['MaxAgency']!),
      sheetPrerequisite: row['Prerequisite'] ?? '',
    ),
], games);

/// Card 201's eligibility filter: which built games a child can be given a
/// round of right now, on three axes — agency, the child's tier in that game,
/// and prerequisites.
///
/// **Works with no prerequisites at all** (card 219). Cooper won't know real
/// prerequisites until the games have been played; if the filter needed them
/// they would be guessed to make it run. [prerequisites] starts empty, and an
/// empty set means "nothing required".
class Eligibility {
  final List<GameRequirement> requirements;

  /// What must be completed before a game-tier is eligible, keyed by
  /// [GameRequirement.token]. Empty by default.
  final Map<String, Set<String>> prerequisites;

  const Eligibility(this.requirements, {this.prerequisites = const {}});

  /// The built games a child at [agency] can be given, each at their own
  /// tier for it ([tierOf], 1-based, defaulting to 1), having completed the
  /// game-tiers in [completed].
  List<CurriculumGame> pool({
    required List<CurriculumGame> games,
    required AgencyStage agency,
    int Function(CurriculumGame game)? tierOf,
    Set<String> completed = const {},
  }) => [
    for (final game in games)
      if (isEligible(
        game.name,
        tierOf?.call(game) ?? 1,
        agency: agency,
        completed: completed,
      ))
        game,
  ];

  bool isEligible(
    String game,
    int tier, {
    required AgencyStage agency,
    Set<String> completed = const {},
  }) {
    final row = requirements
        .where((r) => r.game == game && r.tier == tier)
        .firstOrNull;
    if (row == null) return false;
    if (agency.index < row.minAgency.index) return false;
    if (agency.index > row.maxAgency.index) return false;
    final needs = prerequisites[row.token] ?? const <String>{};
    return completed.containsAll(needs);
  }
}

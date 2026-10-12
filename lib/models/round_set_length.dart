import 'agency_stage.dart';

/// How many rounds make one set of a game — one ACTIVITY — at each agency
/// stage (Trello card 196): Observe 3, Explore 4, Decide 5. It varies by
/// agency ONLY — never by tier, age band or game — so every game reads its
/// round count from here rather than holding its own literal.
///
/// Shortest at Observe not for attention span but because Observe is the
/// most repetitive stage: the child causes nothing, so every round is the
/// same experience with different notes. What is being rationed is
/// sameness, not effort.
///
/// ⚠️ 3/4/5 is a guess from two children in one morning (card 196). The
/// live value is [DevSettingsState.roundSetLength], changeable on the dev
/// screen; a public build only ever has [standard]. Revise against the
/// tracking log.
class RoundSetLength {
  final int observe;
  final int explore;
  final int decide;

  const RoundSetLength({
    required this.observe,
    required this.explore,
    required this.decide,
  });

  /// Card 196's starting values.
  static const standard = RoundSetLength(observe: 3, explore: 4, decide: 5);

  /// The choices the dev screen offers for one stage.
  static const int min = 1;
  static const int max = 8;

  int lengthFor(AgencyStage stage) => switch (stage) {
    AgencyStage.observe => observe,
    AgencyStage.explore => explore,
    AgencyStage.decide => decide,
  };

  /// A copy with [stage]'s length set to [rounds], clamped to [min]–[max].
  RoundSetLength withLength(AgencyStage stage, int rounds) {
    final n = rounds.clamp(min, max);
    return RoundSetLength(
      observe: stage == AgencyStage.observe ? n : observe,
      explore: stage == AgencyStage.explore ? n : explore,
      decide: stage == AgencyStage.decide ? n : decide,
    );
  }
}

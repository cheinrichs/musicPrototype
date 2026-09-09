/// Per-round behavioral signals recorded (not surfaced to the child) to
/// feed promotion logic later (Trello card 91). Local-only, in-memory for
/// the session — never sent anywhere.
class RoundInstrumentation {
  final int promptNumber;

  /// False if a tap cut the intro playthrough short before it finished.
  final bool waitedForPlaythrough;

  /// Whether the child's first tap/drag this round — made before any
  /// on-screen hint (Participate's sparkle) existed — landed on the
  /// correct side. Null when the stage has no target to be right or wrong
  /// about (Observe), or when no such tap happened.
  final bool? firstResponseCorrect;

  /// How many times "Listen Again" was pressed this round.
  final int listenAgainCount;

  /// Cumulative correct taps this round, Participate (A1) only (Trello
  /// card RqdPFKLf, "Completion criteria for A0 and A1, and the
  /// correct-tap sparkle") — counts every correct tap toward the
  /// five-in-a-row auto-advance; a wrong tap does *not* subtract from it
  /// (see [wrongTapCount] instead). Deliberately generous as a gate — the
  /// criterion is for progression, this field (with [wrongTapCount]) is
  /// for assessment. Zero at every other stage: Observe's completion
  /// criterion is coverage (tap each instrument), not a tap count, and
  /// Trigger's tapping stays pure exploration.
  final int correctTapCount;

  /// Wrong taps this round, Participate (A1) only — logged purely for
  /// assessment; the gate itself ([correctTapCount] reaching five) never
  /// looks at this. Zero at every other stage.
  final int wrongTapCount;

  const RoundInstrumentation({
    required this.promptNumber,
    required this.waitedForPlaythrough,
    required this.firstResponseCorrect,
    required this.listenAgainCount,
    this.correctTapCount = 0,
    this.wrongTapCount = 0,
  });
}

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

  const RoundInstrumentation({
    required this.promptNumber,
    required this.waitedForPlaythrough,
    required this.firstResponseCorrect,
    required this.listenAgainCount,
  });
}

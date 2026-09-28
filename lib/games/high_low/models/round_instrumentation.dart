/// Per-round behavioral signals recorded (not surfaced to the child) to
/// feed promotion logic later (Trello card 91). Local-only, in-memory for
/// the session — never sent anywhere.
class RoundInstrumentation {
  final int promptNumber;

  /// False if a tap cut the intro playthrough short before it finished —
  /// the narration, not necessarily the notes (see
  /// [notesHeardBeforeFirstResponse] for the narrower, evidentiary
  /// question). Interrupting narration is not itself a problem — see that
  /// field's doc comment.
  final bool waitedForPlaythrough;

  /// Whether the child's first tap/drag this round — made before any
  /// on-screen hint (Participate's sparkle) existed — landed on the
  /// correct side. Null when the stage has no target to be right or wrong
  /// about (Observe), or when no such tap happened.
  final bool? firstResponseCorrect;

  /// Whether both notes of the pair had already finished ringing out by
  /// the time of the round's first response (Trello card 171, "the
  /// invalid-round rule — measure against the notes, not the narration").
  /// Null until a response has happened, same as [firstResponseCorrect].
  ///
  /// **False here means the round is an invalid measurement, not a wrong
  /// answer** — there was no evidence available yet, whatever
  /// [firstResponseCorrect] says. It must not feed tier advancement
  /// (correct or wrong), though it still counts toward agency's own
  /// capability signal (a fast wrong drag still demonstrates the child can
  /// drag). A **false** on [waitedForPlaythrough] alongside a **true**
  /// here is the expected, healthy case: the child skipped the narration
  /// but still heard both notes — the pole is conveyed three ways (which
  /// character speaks, that character's voice pitch, and the slot's
  /// position on the tree), and the spoken sentence is the slowest of the
  /// three, so interrupting it is the designed redundancy working, not
  /// cheating.
  final bool? notesHeardBeforeFirstResponse;

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

  /// Wrong *responses* this round — wrong taps at Participate (A1; logged
  /// purely for assessment, the gate itself ([correctTapCount] reaching
  /// five) never looks at this) and, since Trello card 172 ("advancement
  /// and demotion"), wrong drags at Trigger (A2) too: "a drag that never
  /// reaches a target is motor difficulty — exactly what agency measures",
  /// one of Drag's own demotion signals (see `AgencyAdvancement`). Zero at
  /// Observe.
  final int wrongTapCount;

  const RoundInstrumentation({
    required this.promptNumber,
    required this.waitedForPlaythrough,
    required this.firstResponseCorrect,
    this.notesHeardBeforeFirstResponse,
    required this.listenAgainCount,
    this.correctTapCount = 0,
    this.wrongTapCount = 0,
  });
}

/// How the "which one is it, high or low?" target alternates across a
/// session's rounds. This is a sequencing *rule*, not something tracked
/// per round or per child — see [ConceptTier], which is the tracked,
/// tiered dimension (Trello card 95). Whether a round asks for the high
/// one or the low one is a property of where it sits in this sequence.
enum RoundOrder {
  /// All "find the high one" rounds first, then all "find the low one",
  /// then a final interleaved block — scaffolds recognition of each
  /// direction on its own before asking the child to switch between them.
  blocked,

  /// The target direction is randomized independently every round, from
  /// the very first one.
  mixed;

  String get label => switch (this) {
    RoundOrder.blocked => 'Blocked',
    RoundOrder.mixed => 'Mixed',
  };
}

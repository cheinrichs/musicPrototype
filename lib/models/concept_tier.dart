/// How musically demanding a round's *stimulus* is, independent of how
/// much the child is asked to do with it (that's [AgencyStage]). Per the
/// curriculum handoff (docs/product/LEARNING_ARCHITECTURE.md), a concept
/// tier is built from interval size and register — T1 is a wide interval,
/// T4 a small one (Trello card 95).
///
/// The curriculum handoff also lists timbre as a dimension here, but a
/// High/Low round is always two notes on the *same* instrument (Cooper:
/// "i don't think we'll be pitting different instruments against each
/// other ever and comparing pitch") — read timbre as varying *between*
/// rounds (cellos this round, trumpets the next; see
/// PromptGenerator.generatePrompt), not as a within-round axis any tier
/// controls.
///
/// Register isn't modeled as a fourth, independently-locked axis here: the
/// note pool already spans two octaves and is picked at random regardless
/// of tier, so register variety falls out of that for free. Revisit if the
/// curriculum ever needs register held constant or swept deliberately.
enum ConceptTier {
  t1,
  t2,
  t3,
  t4;

  /// Smallest semitone gap allowed between the two notes this tier can
  /// produce — larger gaps are easier to tell apart.
  int get minSemitones => switch (this) {
    ConceptTier.t1 => 7, // perfect 5th+
    ConceptTier.t2 => 4,
    ConceptTier.t3 => 4,
    ConceptTier.t4 => 2, // major 2nd+
  };

  /// Largest semitone gap this tier can produce.
  int get maxSemitones => switch (this) {
    ConceptTier.t1 => 12, // up to an octave
    ConceptTier.t2 => 7,
    ConceptTier.t3 => 7,
    ConceptTier.t4 => 4,
  };

  /// Short label for the dev toggle.
  String get label => switch (this) {
    ConceptTier.t1 => 'T1',
    ConceptTier.t2 => 'T2',
    ConceptTier.t3 => 'T3',
    ConceptTier.t4 => 'T4',
  };
}

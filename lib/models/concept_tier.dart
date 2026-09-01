/// How musically demanding a round's *stimulus* is, independent of how
/// much the child is asked to do with it (that's [AgencyStage]). Per the
/// curriculum handoff (docs/product/LEARNING_ARCHITECTURE.md), a concept
/// tier is built from interval size, register, and timbre — T1 is a wide
/// interval on one instrument, T4 is a small interval across two different
/// instruments (Trello card 95).
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

  /// Whether both notes this round should sound on the *same* instrument
  /// (timbre held constant) or on two different instruments (an added
  /// axis of difficulty: the child has to track pitch through a timbre
  /// change instead of comparing two notes of the same color).
  bool get sameInstrument => this == ConceptTier.t1 || this == ConceptTier.t2;

  /// Short label for the dev toggle.
  String get label => switch (this) {
    ConceptTier.t1 => 'T1',
    ConceptTier.t2 => 'T2',
    ConceptTier.t3 => 'T3',
    ConceptTier.t4 => 'T4',
  };
}

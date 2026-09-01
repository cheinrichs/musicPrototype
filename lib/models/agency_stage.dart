/// How much of an ear-training activity's interaction the child is asked to
/// carry, independent of *what* musical content it covers (see
/// docs/product/LEARNING_ARCHITECTURE.md's Skill + Concept Tier + Agency +
/// Age Presentation model). Generic across activities — an activity reads
/// its own [AgencyStage] and renders accordingly; this enum doesn't know
/// anything about High/Low or any other specific game (Trello card 92).
///
/// Only the first three tiers of the curriculum's full A0-A4 agency ladder
/// are modeled here — the ones actually built so far (Trello card 91, for
/// the 2-3 age band). Later work can extend this enum as higher tiers are
/// implemented.
enum AgencyStage {
  /// A0 — the activity plays itself; no response is required or possible.
  observe,

  /// A1 — the child can act (tap, echo, gesture), but nothing is scored:
  /// there is no question and no wrong answer.
  participate,

  /// A2 — the child must initiate or choose a response to advance, but a
  /// wrong attempt is always a gentle retry, never a failure state.
  trigger;

  /// Short curriculum code, as used in docs/curriculum/agency.csv.
  String get code => switch (this) {
    AgencyStage.observe => 'A0',
    AgencyStage.participate => 'A1',
    AgencyStage.trigger => 'A2',
  };

  /// Human-readable label, e.g. for the dev toggle.
  String get label => switch (this) {
    AgencyStage.observe => 'Observe',
    AgencyStage.participate => 'Participate',
    AgencyStage.trigger => 'Trigger',
  };
}

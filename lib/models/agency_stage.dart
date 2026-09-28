/// What a child is developmentally **capable of doing** in an interaction —
/// cannot interact yet, can tap, can drag — independent of *what* the
/// interaction is about (that's `ConceptTier`) and of *which game* is
/// running (Trello card 168, "Agency is capability, not difficulty").
///
/// **Agency belongs to the child, not to a game or a device.** Cooper:
/// "agency was really supposed to help us gauge what a child was
/// developmentally capable of. the youngest kids aren't going to be able to
/// drag. and they honestly might not even tap the screen at first." A child
/// who can drag, can drag anywhere — a game that only needs tapping simply
/// doesn't use the rest of what the child can do; nothing is invented to
/// fill a slot for it. This generic enum doesn't know anything about
/// High/Low or any other specific game — each activity reads it and renders
/// accordingly.
///
/// **This is one axis of two, not the whole picture** (Trello card 171).
/// The other is whether the child *attends* to the prompt before acting —
/// a child can have drag capability and still answer before listening. The
/// two usually move together, which is why they looked like one number for
/// a while; they come apart at exactly the case that prompted the split
/// (Cooper's own nearly-3-year-old). See `HighLowGameState`'s round-validity
/// logic for where that second axis is measured, not here — this enum is
/// motor capability only.
///
/// **Ordering is not an agency level** (settled 2026-09-27, superseded a
/// previous `order` value here). Cooper: "ordering is a skill. it probably
/// belongs at the end like 2 instrument ordering then 3 instrument
/// ordering." Arranging three sounds by a continuous property uses the same
/// drag a child already has — no new motor capability — so it doesn't
/// belong on this ladder at all. It's a separate skill, taught by whichever
/// games support it, using whatever agency the child already has.
///
/// **A3 ("Timed") never appears here.** It was never a capability — timing
/// is telemetry (how fast an answer lands relative to the evidence), not
/// something a child either can or can't do — so it was never modeled as a
/// stage of this enum, and removing it is confirming an absence rather than
/// deleting code.
///
/// **Advances on demonstrated capability, never on accuracy** — a child who
/// drags confidently to the wrong answer has still demonstrated they can
/// drag. `ConceptTier`'s own advancement is a different, accuracy-based
/// question; one mastery algorithm must not be applied to both. See
/// `docs/product/ADVANCEMENT_SIGNALS.md`.
enum AgencyStage {
  /// The activity plays itself; no response is required or possible. Also
  /// where waiting itself gets learned — see
  /// `docs/product/ADVANCEMENT_SIGNALS.md`.
  observe,

  /// The child can act (tap, echo, gesture), but nothing is scored: there
  /// is no question and no wrong answer.
  explore,

  /// The child must initiate or choose a response to advance, by dragging;
  /// a wrong attempt is always a gentle retry, never a failure state.
  drag;

  /// Short curriculum code, as used in docs/curriculum/agency.csv — that
  /// sheet's own naming (A0/A1/A2), unaffected by this enum's names.
  String get code => switch (this) {
    AgencyStage.observe => 'A0',
    AgencyStage.explore => 'A1',
    AgencyStage.drag => 'A2',
  };

  /// Human-readable label, e.g. for the dev toggle.
  String get label => switch (this) {
    AgencyStage.observe => 'Observe',
    AgencyStage.explore => 'Explore',
    AgencyStage.drag => 'Drag',
  };

  /// One capability step up, or null at the top of the ladder ([drag]) —
  /// used by `AgencyAdvancement` so a bounds check never needs repeating at
  /// every call site.
  AgencyStage? get next => index < AgencyStage.values.length - 1
      ? AgencyStage.values[index + 1]
      : null;

  /// One capability step down, or null at the bottom ([observe]).
  AgencyStage? get previous => index > 0 ? AgencyStage.values[index - 1] : null;
}

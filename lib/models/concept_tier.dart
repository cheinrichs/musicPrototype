/// How musically demanding a round's *stimulus* is, independent of how
/// much the child is asked to do with it (that's `AgencyStage`).
///
/// Eight tiers, a complete 2×2×2 across three independent properties —
/// [interval width][minSemitones]/[maxSemitones] (wide 7–12 / narrow
/// 4–7), [instrumentsVary] (one instrument / two paired instruments), and
/// [noteCount] (2 / 3) — per
/// `docs/product/HIGH_LOW_TIERS.md` (Trello card tKgdjYp9), which is the
/// authoritative spec for everything below; this doc comment is a summary,
/// not a substitute for it.
///
/// | Tier | Interval | Instruments | Notes | What's new |
/// |---|---|---|---|---|
/// | T1 | wide (7–12) | one | 2 | — |
/// | T2 | narrow (4–7) | one | 2 | narrower gap |
/// | T3 | wide | varying | 2 | timbre must be ignored |
/// | T4 | narrow | varying | 2 | narrower gap again |
/// | T5 | wide | one | 3 | third note — "which is highest" |
/// | T6 | narrow | one | 3 | narrower gap again |
/// | T7 | wide | varying | 3 | both demands combined |
/// | T8 | narrow | varying | 3 | narrower gap again |
///
/// **The governing rule: one new demand per step, and relax the others
/// when you add one.** Each new demand (varying instruments at T3,
/// three notes at T5) arrives on its own with the interval widened back
/// to 7–12, then hardens by narrowing the interval, then eventually
/// combines with the other demand at T7. Instrument contrast is
/// deliberately **off** again at T5–T6 even though T3–T4 already turned
/// it on — a ladder where features only accumulate can't obey the
/// governing rule, because there's nothing left to give back when a new
/// demand (three notes) arrives. Don't "fix" this into a monotonic
/// feature list.
///
/// **Nothing narrower than a major third (4 semitones) appears anywhere.**
/// The old four-tier `ConceptTier`'s narrowest band (2–4 semitones) is
/// gone entirely — near-semitone discrimination is an ear-acuity test,
/// not a high-versus-low one, and a frustrating skill to demand at five.
/// This also means [HighLowInstrument.hasRangeFor]/[HighLowInstrument.
/// canPairWith] checks against these tiers' [minSemitones] now exclude
/// tuba (a 3-semitone range) from every tier, same-instrument or
/// cross-instrument — it cleared the old T4's 2-semitone floor but
/// clears none of these eight. That's the existing range-eligibility
/// machinery doing its job, not a special case added for tuba.
///
/// [noteCount] 3 tiers ask a *different question* than 2 — "which one is
/// the highest" (selection among three) rather than "which one is higher
/// (of two)". This is deliberately not "give me the low one" for three
/// notes; the spec only ever asks for the highest. Ordering three notes
/// (arranging them, not just picking the highest) stays a separate,
/// later agency-axis capability (A4), not folded in here — see the spec
/// doc's "Why three notes is a tier, not an agency level".
///
/// Three-note tiers (T5–T8) are modeled and generated here, and
/// [PromptGenerator] produces genuinely valid three-note prompts for
/// them — but no screen renders a three-note round yet (there's no
/// design for where a third instrument sits without competing with the
/// centered target character's own carefully-tuned position). Selecting
/// T5–T8 in the dev gate shows a clear "not built yet" placeholder
/// instead of a broken or cramped layout — see `HighLowScreen`.
enum ConceptTier {
  t1(interval: _IntervalBand.wide, instrumentsVary: false, noteCount: 2),
  t2(interval: _IntervalBand.narrow, instrumentsVary: false, noteCount: 2),
  t3(interval: _IntervalBand.wide, instrumentsVary: true, noteCount: 2),
  t4(interval: _IntervalBand.narrow, instrumentsVary: true, noteCount: 2),
  t5(interval: _IntervalBand.wide, instrumentsVary: false, noteCount: 3),
  t6(interval: _IntervalBand.narrow, instrumentsVary: false, noteCount: 3),
  t7(interval: _IntervalBand.wide, instrumentsVary: true, noteCount: 3),
  t8(interval: _IntervalBand.narrow, instrumentsVary: true, noteCount: 3);

  const ConceptTier({
    required _IntervalBand interval,
    required this.instrumentsVary,
    required this.noteCount,
  }) : _interval = interval;

  final _IntervalBand _interval;

  /// Whether this tier's round uses two different (but pairable)
  /// instruments rather than one — the "instruments" axis of the 2×2×2
  /// ladder. See [HighLowInstrument.canPairWith] for the overlap rule
  /// [PromptGenerator] uses to pick a legal pair.
  final bool instrumentsVary;

  /// 2 or 3 — the "note count" axis of the 2×2×2 ladder. See the class
  /// doc for why 3 asks "which is highest" rather than "higher/lower".
  final int noteCount;

  /// Smallest semitone gap allowed between two (adjacent, for 3-note
  /// tiers) notes this tier can produce — larger gaps are easier to tell
  /// apart. 7 for wide tiers (a perfect 5th or more), 4 for narrow ones
  /// (a major 3rd or more) — see the class doc for why nothing narrower
  /// exists any more.
  int get minSemitones => switch (_interval) {
    _IntervalBand.wide => 7,
    _IntervalBand.narrow => 4,
  };

  /// Largest semitone gap this tier can produce — 12 (an octave) for wide
  /// tiers, 7 (a perfect 5th) for narrow ones.
  int get maxSemitones => switch (_interval) {
    _IntervalBand.wide => 12,
    _IntervalBand.narrow => 7,
  };

  /// Short label for the dev toggle.
  String get label => switch (this) {
    ConceptTier.t1 => 'T1',
    ConceptTier.t2 => 'T2',
    ConceptTier.t3 => 'T3',
    ConceptTier.t4 => 'T4',
    ConceptTier.t5 => 'T5',
    ConceptTier.t6 => 'T6',
    ConceptTier.t7 => 'T7',
    ConceptTier.t8 => 'T8',
  };
}

enum _IntervalBand { wide, narrow }

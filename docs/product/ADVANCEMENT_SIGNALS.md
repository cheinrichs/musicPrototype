# Advancement Signals — Ear Training App

This doc consolidates reasoning about how a child moves between agency levels and
concept tiers, and what evidence is used to justify that movement. It was scattered
across several Trello cards; this is the single place it lives now, so it doesn't get
lost or contradicted.

It complements `LEARNING_ARCHITECTURE.md`, which defines the axes (Skill, Concept
Tier, Agency Level, Age/UI Presentation). This doc is about **movement along those
axes** — not what the axes are.

> **UPDATED 2026-09-27 (Trello card 168, "Agency is capability, not
> difficulty").** Agency is now three named capability levels — Observe,
> Explore, Drag — not the curriculum's old A0–A4 ladder. A3 ("Timed") is
> confirmed gone; ordering is a separate skill, not an agency level. Below,
> read "A0/A1/A2" as "Observe/Explore/Drag" and "A4" as "the ordering
> skill." **The signals themselves are being substantially reworked** by
> two further queued cards — agency's second axis (does the child attend
> before acting, not just what they can physically do) and the
> capability-based advancement/demotion criteria between Observe, Explore
> and Drag — so treat the specific signals below as the reasoning that led
> here, not yet the current rules. Update this notice once those land.

---

## Purpose

How a child moves between agency levels and concept tiers, and what evidence is used
to justify that movement.

---

## Framing: a false positive costs almost nothing

If promotion just means a character starts asking a question, and a wrong answer gets
a gentle nudge with no penalty, promoting a child too early is harmless.

The threshold can be loose and generous.

**The engineering effort belongs in making early promotion feel like nothing
happened, not in building an accurate detector.**

---

## Signals, strongest first

### 1. Waiting before responding

Does the child let the stimulus play through before acting? Evidence of listening
rather than poking.

This is the Observe→Explore signal for High/Low.

> ⚠️ **Refined 2026-09-27 (Trello card 171) — measure against the notes, not the
> narration.** An earlier version of this signal invalidated any round answered
> before "the prompt" finished, full stop. Too broad: a prompt has a spoken
> narration *and* the instrument notes, and the pole is conveyed three ways —
> which character speaks, that character's voice pitch, and (once the tree-slot
> mechanic landed) the slot's position on the tree. The spoken sentence is the
> slowest of the three. A child who interrupts it but still hears both notes has
> read a faster channel, not skipped the evidence — that's the designed
> redundancy working. **Only mark a round invalid when the answer lands before
> both notes have finished playing** — see
> `HighLowGameState._bothNotesHeard`/`RoundInstrumentation.notesHeardBeforeFirstResponse`.
> Worth also watching for runs of implausibly fast answers as a pattern (random
> dragging until something sticks looks like a sequence of near-zero response
> times) — not yet built; there's no defined threshold or storage for it yet.

### 2. First-response accuracy

The *first* tap of a round, before any feedback has revealed the answer. A first tap
is a prediction, and predicting means they heard it. Later taps on the already-revealed
answer are just enjoyable.

> ⚠️ **These two are dependent, and that's the transferable insight.** First-tap
> accuracy is only *valid* if the child waited — someone who taps instantly heard
> nothing, so their first tap carries no information. **Lower-agency behaviour often
> validates higher-agency measurement rather than merely preceding it.** Expect this
> shape in other games.

### 3. Repeated "listen again" presses

Asking for the stimulus again is attention to the audio — unlike repeatedly tapping a
revealed answer, which is just fun.

Possibly the best readiness signal available at A0.

### 4. Skips

Voluntary, so uniquely informative about engagement and frustration — nothing else in
the app measures those. Consistent skipping of one game may mean agency too high, tier
too hard, or the game needs rework.

> ⚠️ **Skip confounds.** The move-on control is usable by both child and adult, so raw
> counts conflate "this child dislikes this game" with "we needed to leave for
> school." Separate them by:
> - time before skip (three seconds is a child bouncing off, four minutes is a parent
>   wrapping up)
> - which control was used (X close vs move-on arrow)
> - pattern across sessions (one skip is noise, the same game skipped across days is
>   signal)

### 5. Exposure counts

Weak as evidence of learning — they say nothing about comprehension. But fine as a
*pacing* rule for transitions that cost nothing to get wrong.

Used for A0→A1 in High/Low: complete one stage.

---

## Measurement traps

- **Randomise position.** If the correct answer favours a side, a child learns
  position and every accuracy metric looks healthy while teaching nothing.
- **Two-choice accuracy is weak.** Random responding clears 50%. Needs volume or a
  stronger signal.
- **Absence of response isn't attention.** A child who doesn't act may be listening or
  may be looking at the dog. Waiting *followed by engagement* is what counts.

---

## How the axes interact

- **Tier does not reset when agency rises**, and agency does not reset when tier
  rises. The axes are independent; the packet states a learner doesn't restart at A0
  for each new tier, and the converse must hold or they're coupled.
- **But don't raise two dimensions at once.** When agency goes up, hold tier steady
  for a while, or ease back one tier and climb again. The child keeps their progress
  without meeting two new things in one session.
- **Agency is closer to a property of the learner than of the skill.** A child
  comfortable being asked questions is comfortable in general, so this isn't decided
  independently 59 times.
- **Promotion should never remove anything.** Each stage contains the one below — free
  exploration survives into the level where a question is added.
- **Never advance tier and agency in the same round.** If both come due at once, the
  next round shows only the new agency, and the tier increase pauses for a stone.
  Agency takes priority because it changes what she is being asked to *do*; a tier
  change only changes how hard the same task is. This needs the per-round tracking
  log to enforce — something has to know what changed last and when.

### Which tiers are reachable at which agency level

Decided 2026-09-25.

**Tier does not advance at Observe.** At Observe the child produces no answer —
High/Low's Observe completion criterion is coverage (tap each instrument), not
correctness — so there is no evidence of discrimination to advance on. Advancing
tier there isn't advancement, it's a playlist silently getting harder with nobody
checking, and it's why the step from Observe to Explore was landing like a cliff.

At Observe, vary the *surface* instead of the difficulty: different instruments and
different notes, same interval band. That keeps a child who lives in Observe for a
while from getting the same two instruments forever, without pretending progress
happened.

The tier ladder starts where evidence does:

- **Observe holds at T1.** No answer, no evidence, no movement.
- **Explore gives a weak signal** — does she tap the target — with no failure state,
  so tier *may* creep, but it stops short of T5 (High/Low's three-note tier — see
  `HIGH_LOW_TIERS.md`). This bound exists on its own evidentiary merits, not to dodge
  a layout problem. (It used to also keep Explore's centred narrator and the
  three-note ordering screen's centre-back pedestal from wanting the screen's middle
  at once; that conflict is gone now that both characters live on the tree, and
  ordering left the agency ladder entirely.)
- **Drag gives a real answer** (a drop can be wrong), and tier moves properly.

This doesn't resolve the mastery algorithm or promotion thresholds themselves — see
Open Questions below — only the *bound* on how far tier can reach before agency has
caught up with it.

---

## Agency advancement and demotion — built (Trello card 172)

`AgencyAdvancement` (`lib/games/high_low/services/agency_advancement.dart`) evaluates
a just-finished session's `RoundInstrumentation` against the child's current agency
capability, and `HighLowScreen` writes any recommended change back to the active
profile once a session completes.

- **Observe → Explore**: enough recent rounds were completed (both instruments
  tapped, the earned arrow reached) without being skipped. Observe's own completion
  criterion already *is* this signal — nothing further to check per round. The
  parent-facing cue this needs ("a screen cannot tell an adult's finger from a
  child's... make the adult a deliberate collaborator") is Observe's own caption,
  reworded to say exactly that: "Encourage them to tap each instrument."
- **Explore → Drag**: enough recent rounds hit the correct (sparkling) instrument
  with few enough wrong taps. Deliberately never reads `firstResponseCorrect` as
  *positive* tier-like evidence here — agency moves on demonstrated capability, and
  the sparkle confound (a child may be following the sparkle, not the sound) means
  this can only ever produce an *agency* recommendation, never touch `ConceptTier`.
- **Drag demotion**: many failed drags in a row (motor difficulty), or several
  rounds answered before either note finished playing (no evidence existed — the
  same signal the invalid-round rule above already computes, reused here as a
  demotion pattern rather than invented separately).
- **"A few rounds"** (the cards' own phrase, no number given) is 3 consecutive
  qualifying rounds within the same session — a judgment call, documented in the
  code as such, not a value handed down by any card.

**Deliberately not built:**
- **Explore → Observe demotion.** The card says to be cautious: Observe removes the
  ability to interact, so making a bored, disengaged child *more* passive likely
  makes it worse; try variety (new instruments/notes at the same level) first. A
  stateless per-session evaluator has no way to know whether variety was already
  tried, so it holds rather than guessing. Revisit once there's a way to track that.
- **A persisted, profile-scoped tracking log that actually records *why*.** Every
  `AgencyEvaluation` carries a `reason` string (the cross-cutting rule from cards
  169/172), but nothing persists it yet — `HighLowScreen` only `debugPrint`s it.
  Building the real log is its own, separate undertaking.
- **Response-time-based demotion beyond the notes-heard proxy.** "Chance-level
  accuracy with near-zero response times" is approximated by "answered before either
  note finished" (a boolean already computed for the invalid-round rule), not by an
  actual measured response time — no per-response timestamp exists yet.

---

## Weaker options

Named so they're dismissed deliberately:

- **Time spent** measures nothing about comprehension.
- **Age** can be an input but the packet forbids inferring agency from age alone.
- A **parent toggle** is honest, cheap, and worth keeping as a backstop regardless of
  what else exists.

---

## Open questions

Do not invent answers to these:

- the mastery algorithm and tier promotion thresholds
- which agency levels apply to which skills
- whether mastery is visible to the child at all

---

## See also

- `LEARNING_ARCHITECTURE.md` — defines the axes this doc describes movement along
  (Skill, Concept Tier, Agency Level, Age/UI Presentation)
- `EAR_TRAINING_APP_PRODUCT_SPEC.md` — full rationale and learning philosophy

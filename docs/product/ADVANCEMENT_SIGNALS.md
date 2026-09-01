# Advancement Signals — Ear Training App

This doc consolidates reasoning about how a child moves between agency levels and
concept tiers, and what evidence is used to justify that movement. It was scattered
across several Trello cards; this is the single place it lives now, so it doesn't get
lost or contradicted.

It complements `LEARNING_ARCHITECTURE.md`, which defines the axes (Skill, Concept
Tier, Agency Level, Age/UI Presentation). This doc is about **movement along those
axes** — not what the axes are.

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

This is the A0→A1 signal for High/Low.

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

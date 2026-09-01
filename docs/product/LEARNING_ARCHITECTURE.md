# Learning Architecture — Ear Training App

_Originally the design/curriculum handoff packet's own `CLAUDE.md`. Filed here to avoid colliding with the repo root `CLAUDE.md` (shell-command and workflow conventions); the root `CLAUDE.md` points here for product/curriculum guardrails._

## Project North Star

Build a joyful musical journey where children first **feel and play with sound**, then gradually learn to **hear it, shape it, name it, and make music intentionally**.

The product is designed for children beginning around age 2 and extending into later childhood. It should feel like a playful journey game, not adult ear-training exercises with simpler questions.

---

## Core Learning Architecture

Never collapse learning difficulty into one value.

Every learning experience is composed from four parts:

`Skill + Concept Tier + Agency Level + Age/UI Presentation`

These are independent.

### Concept Tier
How musically difficult the stimulus itself is.

There are four tiers.

Examples of what may change:
- number of notes
- interval size/type
- tempo
- contour complexity
- rhythmic density
- phrase length
- timbral similarity
- harmonic complexity

Concept parameters describe **the musical material**, not how hard the child must work to respond.

### Agency Level

Agency describes what the child is required to do.

| Level | Meaning |
|---|---|
| A0 — Observe | Watch/listen; no response required |
| A1 — Participate | Loose imitation, gesture, vocalization, or tapping |
| A2 — Trigger | Intentionally choose or initiate a correct response |
| A3 — Timed | Respond within musical time |
| A4 — Precision | Accurate timing and/or pitch required |

A learner does **not** restart at A0 for every new concept tier.

Replay behavior belongs primarily to Agency/scaffolding:
- A0: auto/unlimited
- A1: unlimited manual
- A2: available
- A3: limited
- A4: minimal/none

### Age/UI Presentation

Age changes how the same learning concept is communicated.

**Tone doesn't ladder — only vocabulary does.** Word choice and sentence length vary by
band. Personality, warmth, and willingness to be silly do not: they're constant across every
band, project-wide, not a property of any one age. Piper and Clef keep talking at every band,
same personality throughout — the way Bandit talks to Bluey at six completely differently
than he talks to Bingo at four, while being unmistakably the same person, and never talking
down to either.

What reads as babyish isn't having talking animated characters around — it's being
over-explained to and over-praised. That's worth avoiding at *every* age, not just the
oldest, and it's why no band (including 8+) should read as "less gamified": doing so would
contradict this app's own north star (see above: "a playful journey game, not adult
ear-training exercises with simpler questions").

Humour doesn't arrive at 8+, it grows up. The app is already funny at 2–3 (Wait... BOO! is
built on comic timing and a character falling over) — slapstick and surprise at the youngest
band, cheek and wordplay at the oldest, same sense of humour throughout, just different
vocabulary for expressing it.

Two reference points, held across every band, not just the older ones: **Bluey's Bandit**
(primary) — verbal, warm, genuinely funny, never condescending, and lands on adults and
children simultaneously, which matters here because a parent is usually sitting alongside.
**Crash Bandicoot** (secondary, seasoning) — physical comedy, attitude, and genuinely
difficult games as their own form of respect for the player.

Current presentation bands — vocabulary and complexity only; tone is constant (see above):
- **2–3:** concrete, symbolic, minimal language, strong visual metaphors
- **4–5:** simple words, short instructions, icons + light labels
- **6–7:** introduce musical terminology, reduce visual crutches
- **8+:** formal terminology, less hand-holding

Age does **not** determine concept tier.

A six-year-old beginner can use Tier 1 musical material with six-year-old presentation.

UI may also vary by **Skill + Tier + AgeBand**.

---

## Curriculum Structure

Current hierarchy:

`Node → Skill → Tier`

Current nodes:

1. Sound Awareness
2. Pitch Awareness
3. Contour & Shape
4. Rhythm & Timing
5. Anticipation & Musical Punctuation
6. Tonal Contrast & Resolution
7. Sound Making & Sound Shaping
8. Timbre & Instrument Awareness
9. Guided Instrument Play
10. Harmony & Chord Feel
11. Pitch Naming & Functional Hearing

The Google Sheet **Ear Training Music App Skill Tree** is the current curriculum source of truth.

Important tabs:
- `Nodes`
- `Skills`
- `Skill Progression`
- `Difficulty Tiers`
- `Agency`
- `UI Presentation`
- `Visuals`

The generic UI rows and some progression data are still working scaffolds, not final requirements.

---

## Critical Curriculum Decisions

- The child progresses through a **stepping-stone journey path**.
- Skills use **spiral mastery**, not one-and-done completion.
- Previously learned skills should recur in future sessions.
- Nodes do not necessarily unlock in strict numeric order.
- Rhythm, pitch, sound making, and exploration can develop in parallel.
- Not every experience needs pass/fail scoring.
- Free play can exist outside the mastery path.
- MVP scope has **not** been finalized yet.

Do not silently decide product behavior where the spec is still open.

---

## Early-Childhood Design Principles

For young learners, these are valid forms of musical learning:

- observation
- delayed imitation
- movement
- anticipation
- call-and-response
- exaggerated visual metaphor
- cause/effect
- playful vocalization

Do not treat lack of exact synchronization as failure at low agency levels.

A child responding a few seconds after a musical model can still be practicing meaningful call-and-response.

Avoid harsh failure states for A0/A1.

---

## Sound Should Be Visible and Physical

Whenever possible, map musical structure to a corresponding visual or embodied event.

Examples:
- descending sound → waterfall / falling rainbow
- ascending sound → stairs / rising object
- strong accent → jump / fall / burst
- pause → freeze / wait
- release → arms open / object released
- stomp → environment reacts
- sustained wobble → visible head shake
- vowel shape → character mouth shape

Visuals should reinforce musical meaning, not merely decorate the screen.

---

## Key Game Distinctions

### Steady Beat Feel
The animation itself embodies pulse.

Examples:
- glowing firefly
- swaying character
- bouncing object

The child may simply watch, sway, or join loosely.

### Tap Along to Pulse
The child attempts to synchronize an action with beat targets.

This is a higher-agency interaction than Steady Beat Feel.

### Mode Contrast
May be presented as:
- bright/dark
- calm/spooky
- happy/sad
- eventually major/minor

Do not equate major exclusively with happy or minor exclusively with sad.

### Resolution Awareness
May be presented as:
- question/answer
- finished/waiting
- home/away
- later tension/release or resolved/unresolved

Mode Contrast and Resolution Awareness are separate skills.

---

## Signature Interaction Ideas

Preserve these concepts when designing activities:

- Higher vs Lower using large/small visual metaphors
- Ascending/Descending using stairs, slides, waterfalls, rockets, contour lines
- Same Note Match
- animal-sound matching / animal behind leaves
- call-and-response echo
- `1–2–3 … BOOM!`
- `Wait… BOO!` with slapstick reaction
- Shake the Sound
- lip trills and vocal warmups
- mouth/vowel-shape modeling
- instrument free-play sandbox
- guided colored-dot/shapes piano play
- sing-along chord/arpeggio exercises
- solfege melody play

A **game template is not the same thing as a skill**.

Reusable interaction templates should be able to serve multiple skills.

---

## Sound Making & Sound Shaping

This is a first-class curriculum domain, not a side activity.

It includes:
- attack
- sustain
- release
- dynamics
- vocal wobble
- lip trills
- airflow
- vowel/mouth shape
- vocal warmups

Some interactions may feel speech-therapy-adjacent, but the app should not claim to provide speech therapy.

---

## Guided Instrument Play

Progression should generally move from:

`colored dots/shapes → guided note patterns → piano/instrument keys → reduced visual scaffolding`

Do not assume conventional notation is required early.

---

## Reward Design

Completion feedback should itself be musical.

Current milestone/stepping-stone jingle concept:

> I've come so far  
> Keep watching me  
> I love music!

Hidden musical mapping:
- **far** lands on **Fa**
- **me** lands on **Mi**
- ending of **music** resolves to **Do**

The final line should incorporate the **Shake the Sound** mechanic: a playful sustained syllable with visible head wobble before resolution.

Exact melody is not locked.

---

## Technical / Data Guidance

Prefer a data-driven architecture.

Useful conceptual entities may include:
- Node
- Skill
- ConceptTier
- TierParameters
- AgencyLevel
- AgeBand
- PresentationVariant
- Prerequisite
- MasteryState
- ActivityTemplate

Do not hard-code:
- age vocabulary into musical stimulus generation
- a single agency level into a skill
- one UI representation as the canonical musical concept
- one game screen per skill

Favor reusable activity primitives.

---

## Known Spreadsheet Cleanup

The current `Difficulty Tiers` tab still contains some `Replay Allowed` rows.

Current decision:
**Replay is Agency/UI scaffolding, not Concept Difficulty.**

Do not model replay as a musical tier parameter unless this is intentionally revisited later.

---

## Open Product Questions

Do not invent answers to these without discussion:

- exact MVP subset
- prerequisite graph
- mastery algorithm
- tier promotion thresholds
- which agency levels apply to each skill
- final age-band boundaries
- stars/checkmarks/scoring
- daily gating / parent controls
- final companion character
- exact jingle melody
- microphone/pitch-detection strategy
- audio/sample licensing
- notation timeline
- account/progress sync
- monetization
- accessibility / alternate interaction modes

When implementation depends on one of these, surface it as a TODO or ask.

---

## Before Building Any Activity

Ask:

1. What musical **skill** is being taught?
2. What **concept tier** is the stimulus?
3. What **agency** is required?
4. What **age/UI presentation** is appropriate?
5. Does the visual or physical action reinforce the musical idea?
6. Can the interaction be reused for other skills?
7. How will this skill return later through spiral practice?

---

## Full Product Spec

For rationale, detailed examples, and learning philosophy, see:

`EAR_TRAINING_APP_PRODUCT_SPEC.md`

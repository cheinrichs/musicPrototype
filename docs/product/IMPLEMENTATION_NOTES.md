# IMPLEMENTATION_NOTES.md — Advisory Integration Guide

## Purpose

The app already has a working implementation.

This document is **not** a replacement architecture and should not be treated as the source of truth for the codebase. Its purpose is to help Claude Code / Cowork reconcile the existing implementation with the product and learning architecture described in:

- `LEARNING_ARCHITECTURE.md`
- `EAR_TRAINING_APP_PRODUCT_SPEC.md`
- the current curriculum spreadsheet / CSV snapshot

**Default rule:** preserve working architecture where it is compatible with the learning model. Prefer incremental adaptation over broad rewrites.

---

## 1. Start by Understanding the Existing App

Before proposing structural changes, inspect the repo and identify:

- current app/framework architecture
- navigation and journey/path implementation
- learner profile model
- progress persistence
- game/activity screen patterns
- audio playback and scheduling system
- state management
- content/configuration storage
- animation system
- microphone or pitch-detection capabilities, if any
- testing approach

Do not assume the product spec describes the implementation that already exists.

---

## 2. Preserve the Core Learning Distinctions

The most important architectural requirement is that these concepts remain independently representable:

`Skill + Concept Tier + Agency + Age/UI Presentation`

Do not collapse them into a single difficulty value.

While reviewing the existing codebase, determine whether these dimensions are already represented separately.

If they are not, do **not** immediately redesign the application. First identify the specific limitation created by the current model and recommend the smallest practical change.

Example:

A single `difficulty = 3` field may become problematic if it simultaneously determines:
- how hard the musical stimulus is
- whether the child must tap on time
- whether the prompt says “Up” or “Ascending”

If the existing app already handles those concerns independently in another way, preserve that approach.

---

## 3. Reuse Existing Game Architecture

Do not build one bespoke screen for every curriculum skill unless the current application architecture genuinely requires it.

Look for reusable interaction patterns already present, such as:

- listen + choose
- listen + match
- two-choice comparison
- multi-choice comparison
- tap-to-trigger sound
- timed tap
- call-and-response
- guided sequence
- free-play instrument
- visual pulse
- microphone/vocal response

Map curriculum skills onto these primitives where practical.

A single activity template may support multiple skills by changing:
- audio stimulus
- visual metaphor
- response choices
- concept tier parameters
- agency requirement
- age presentation

---

## 4. Treat Curriculum Data as Configuration Where Practical

If the existing app currently hard-codes content into screens, do not attempt a full content-engine rewrite merely to match the spreadsheet.

Prefer incremental extraction where it creates clear value.

Good candidates for data-driven configuration include:
- skill ID
- node ID
- tier
- prompt copy
- age-band labels
- icon / visual variant
- sound-generation parameters
- answer choices
- prerequisite metadata
- activity template
- mastery contribution

Avoid premature abstraction for content that is still experimental.

---

## 5. Journey Integration

The stepping-stone journey is a strong product direction, but the existing journey/navigation system should be treated as the host.

Do not replace a working path implementation solely because the curriculum model describes:
- spiral mastery
- prerequisites
- tier progression
- recurring review

Instead, determine how those concepts can be integrated into the current path.

Important distinction:

**A stepping stone is a learning encounter/session, not necessarily a permanent one-to-one representation of a single skill.**

A future session may include:
- one newly introduced skill
- one review skill
- one playful/embodied interaction

The exact session-generation/mastery algorithm is still open.

---

## 6. Separate Activity Completion from Mastery

If the current app equates “game completed” with “skill mastered,” flag this as a likely future limitation.

A child may:
- successfully complete an activity
- gain evidence toward mastery
- still need future spiral review

Similarly, A0/A1 observational or participatory activities may be valuable even when they do not generate a conventional scored result.

Do not force every activity into binary pass/fail semantics.

---

## 7. Age Presentation Should Not Rebuild the App

The goal is not to create four separate applications for four age bands.

Prefer variations within reusable screens:
- labels
- terminology
- icons
- visual metaphor
- instruction length
- animation emphasis
- amount of reading required

Examples:

`Up / Down + stairs`  
→ `Higher / Lower`  
→ `Ascending / Descending`

The underlying musical activity can remain the same.

If the current app already has a theming/configuration mechanism that can support these variants, use it.

---

## 8. Agency Should Drive Interaction Demand

Agency is about what the child must do:

- A0 Observe
- A1 Participate
- A2 Trigger
- A3 Timed
- A4 Precision

Review whether current activity components can vary response demand independently from musical content.

Examples:
- the same beat stimulus may first animate passively
- later allow loose tapping
- later score timing

Do not infer agency solely from age.

Replay support should also remain scaffolding/interaction logic rather than part of musical stimulus difficulty.

---

## 9. Audio Architecture Is a High-Leverage Area to Audit

Because the product depends heavily on sound, inspect the existing audio layer before adding many curriculum experiences.

Determine whether it can support:

- reliable pitch-specific playback
- simultaneous notes/chords
- multiple instrument timbres
- short latency for tap-triggered sounds
- scheduled rhythmic playback
- sustained notes
- fades / attacks / dynamic changes
- replay
- sequence generation
- layered music + sound effects
- future microphone input
- future pitch tracking

Do not redesign the audio engine merely for theoretical completeness, but document constraints that would block planned experiences.

Timing-sensitive audio should not rely on animation timing if the framework provides a more accurate audio scheduling mechanism.

---

## 10. Embodied Interactions Are Product Behavior, Not Decoration

The following should be treated as meaningful learning interactions when they appear in features:

- head wobble during sustained sound
- character falling after a punctuated BOO
- visual waterfall matching descending pitch
- stairs matching ascending pitch
- character freezing during a musical pause
- mouth shape matching vowels
- environment reacting to a stomp/accent
- character swaying with pulse

Preserve the relationship between sound and movement when adapting or simplifying UI.

---

## 11. Free Play Can Remain Separate From Journey Mastery

Experiences such as:
- instrument exploration
- vocal sound play
- musical books
- crafts/tutorials
- listening animations

may live in a library or sandbox without requiring mastery scoring.

Do not force them into the progression engine simply because they are educational.

---

## 12. Avoid Premature MVP Assumptions

The curriculum intentionally describes a broad future skill universe.

Do not interpret all 11 nodes as immediate implementation scope.

Likewise, do not delete or restructure future-facing architecture purely because only a subset exists in the current app.

MVP selection remains a separate product decision.

---

## 13. When Refactoring Is Justified

A refactor may be worth proposing when the current architecture makes one of these difficult or impossible:

- same skill at multiple concept tiers
- same concept presented differently by age
- same stimulus used with different agency demands
- reusable game template serving multiple skills
- spiral review/mastery tracking
- reliable audio timing
- adding content without editing core screen logic

Before refactoring:

1. explain the current limitation
2. explain which product requirement it blocks
3. propose the smallest viable change
4. identify migration risk
5. preserve existing working behavior where possible

---

## 14. Repo Reconciliation Questions

After inspecting the existing codebase, produce a short technical assessment answering:

1. Where is child/learner profile data stored?
2. Is age already stored, and how is it used?
3. How is journey progress represented?
4. How are games/activities represented?
5. Is content hard-coded or configuration-driven?
6. Can a game accept variable musical stimuli?
7. Is there already a difficulty model?
8. Does that difficulty model mix concept, agency, or presentation?
9. Is there already a mastery or unlock system?
10. Where are audio files/generation parameters defined?
11. How is rhythmic audio scheduled?
12. How are animations synchronized with audio?
13. Is microphone input currently available?
14. What reusable interaction primitives already exist?
15. What is the smallest change needed to support `Skill + Tier + Agency + Age Presentation`?
16. Which planned game concepts fit the current architecture easily?
17. Which planned concepts would require substantial new technical capability?
18. Are there existing implementation decisions that conflict with the product spec?

Do not change architecture solely to answer these questions. Use them to understand the gap between product intent and current implementation.

---

## 15. Recommended Output From Claude After Repo Review

Before a large implementation pass, produce something like:

### Existing architecture
Short summary of how the app currently works.

### Product-model compatibility
What already supports the curriculum model well.

### Gaps
Concrete incompatibilities or missing capabilities.

### Low-risk adaptations
Small changes that unlock useful flexibility.

### Larger architectural decisions
Changes that deserve explicit product/engineering approval.

### Recommended next implementation slice
Based on what is already built — not based on an imaginary greenfield project.

---

## 16. Guiding Principle

**Do not rewrite a functioning app to conform aesthetically to these documents. Use the documents to preserve product intent while evolving the implementation that already exists.**

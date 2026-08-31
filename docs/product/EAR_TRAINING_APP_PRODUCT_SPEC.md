# Ear Training App --- Product & Learning Architecture Handoff

**Status:** Working product/curriculum specification\
**Audience:** Claude Code / Claude Cowork / developers / curriculum
collaborators\
**Curriculum source of truth:** Google Sheet --- *Ear Training Music App
Skill Tree*

> This document explains the intent behind the spreadsheet. Some
> spreadsheet cells are still working scaffolds. Do not hard-code
> placeholders as product decisions.

## 1. Product vision

Build a playful, developmentally adaptive music-learning app for
children beginning around age 2 and extending into later childhood.

The experience should feel like a child-friendly journey game rather
than a conventional ear-training quiz. A learner moves along a visual
stepping-stone path, encounters short musical games, revisits skills
through spiral practice, unlocks new experiences, and gradually develops
from noticing and enjoying sound to intentionally identifying,
producing, timing, naming, and performing music.

Early-childhood learning should use movement, imitation, visual
metaphor, anticipation, humor, characters, vocal play, and cause/effect.
Formal terminology should emerge after the child already has an
intuitive perceptual model.

## 2. Core architecture: difficulty is not one number

A central decision is that the learner experience has **three
independent axes**:

1.  **Concept Difficulty Tier** --- complexity of the musical material
    itself.
2.  **Agency Level** --- what kind of response/control is required from
    the child.
3.  **Age / UI Presentation** --- how the concept is explained,
    visualized, and scaffolded developmentally.

Do **not** collapse these into one `difficulty` property.

A useful model is:

`Learning Experience = Skill + Concept Tier + Agency + Age Presentation`

A six-year-old beginner may need Tier 1 musical material with
six-year-old language and visuals. A two-year-old may experience rich
material at A0/A1 without being required to identify it precisely.

## 3. Example: Ascending vs Descending

Ages 2--3 might see: - **Up / Down** - stairs or slide imagery -
exaggerated musical movement - a character physically traveling up/down

An older beginner can hear the same introductory stimulus with: - less
metaphorical support - Higher / Lower language - eventually Ascending /
Descending

Concept difficulty independently scales through: - number of notes -
interval type/size - tempo - contour complexity - eventually direction
changes such as up-then-down

**Age does not determine concept tier. Concept tier does not determine
agency. Agency does not determine vocabulary/UI.**

## 4. Curriculum hierarchy

**Node → Skill → Difficulty Tier**

Current nodes:

1.  Sound Awareness
2.  Pitch Awareness
3.  Contour & Shape
4.  Rhythm & Timing
5.  Anticipation & Musical Punctuation
6.  Tonal Contrast & Resolution
7.  Sound Making & Sound Shaping
8.  Timbre & Instrument Awareness
9.  Guided Instrument Play
10. Harmony & Chord Feel
11. Pitch Naming & Functional Hearing

### Node learning goals

**Sound Awareness** --- Develop basic discrimination of volume,
duration, silence/sound, attack, sustain, and release.

**Pitch Awareness** --- Recognize and compare pitch relationships before
requiring symbolic labels.

**Contour & Shape** --- Understand how melodies move through pitch space
over time and connect movement to visual/embodied metaphors.

**Rhythm & Timing** --- Develop awareness of pulse, tempo, accents, and
rhythmic patterns.

**Anticipation & Musical Punctuation** --- Recognize pauses, buildup,
surprise accents, phrase endings, and musical punctuation.

**Tonal Contrast & Resolution** --- Perceive tonal color and stability.
Includes two distinct skills: Mode Contrast and Resolution Awareness.

**Sound Making & Sound Shaping** --- Intentionally produce and shape
attack, sustain, release, dynamics, airflow, mouth shape, and expressive
vocal sounds.

**Timbre & Instrument Awareness** --- Recognize and explore differences
in sound color across instruments and voices.

**Guided Instrument Play** --- Translate auditory/visual cues into
sequenced instrumental performance, from colored shapes/dots toward
reduced scaffolding.

**Harmony & Chord Feel** --- Perceive chord color, stability, movement,
and resolution.

**Pitch Naming & Functional Hearing** --- Connect pitch perception to
symbolic language such as solfege and functional tonal relationships.

The Google Sheet's **Skills** tab is the current detailed inventory.

## 5. Four concept-difficulty tiers

Each skill can have four levels of musical/structural difficulty.
Parameters vary by domain; do not force one universal matrix onto every
skill.

Examples:

**Contour & Shape:** number of notes, interval type, tempo, contour
complexity.

**Rhythm & Timing:** pulse clarity, pattern length, rhythmic density,
tempo.

**Timbre:** instrument contrast, articulation, texture/context,
register.

**Guided Instrument Play:** sequence length, melodic interval structure,
rhythmic structure, polyphony.

**Rule:** concept parameters describe the musical stimulus/material ---
not child accuracy, replay support, UI scaffolding, or motor precision.

## 6. Agency A0--A4

  --------------------------------------------------------------------------------------
  Agency         Child Role         Response Required  Interaction        Replay
                                                       Characteristics    
  -------------- ------------------ ------------------ ------------------ --------------
  A0 --- Observe Passive            None               Auto-play,         Auto and/or
                 listener/watcher                      expressive         unlimited
                                                       modeling, no       
                                                       failure state      

  A1 ---         Imitate/respond    Loose tap, echo,   Wide tolerance,    Unlimited
  Participate    loosely            gesture, vocal     playful, multiple  manual
                                    response           attempts           

  A2 --- Trigger Initiate or choose Correct            Structured         Available
                                    selection/action   turn-taking,       
                                                       feedback, no       
                                                       strict timing      

  A3 --- Timed   Respond within     Response during    Beat-based; timing Limited
                 musical time       timing window      matters            

  A4 ---         Execute accurately Accurate timing    Tight/measurable   Minimal or
  Precision                         and/or pitch       criteria           none
  --------------------------------------------------------------------------------------

A child does **not** need to traverse A0→A4 inside every concept tier.
Agency is an independent learner/interactivity dimension. A learner
comfortable at A2 can encounter a newly unlocked concept at A2 rather
than restarting at A0.

### Replay decision

Replay was initially included in some Difficulty Tier matrices. Current
decision: **replay is scaffolding/agency, not concept difficulty**.
Removing replay does not make the music itself structurally harder.

The current spreadsheet still has legacy `Replay Allowed` rows under
Pitch Awareness and Rhythm & Timing. Treat those as cleanup items, not
current architecture.

## 7. Age/UI presentation

**Ages 2--3:** symbolic/concrete, minimal language, large targets,
expressive modeling, strong metaphors, movement/cause-effect, no reading
dependency.

**Ages 4--5:** simple words, visual metaphors, short instructions, light
labels, increasingly intentional choices.

**Ages 6--7:** musical vocabulary introduced, reduced visual crutches
when useful, more independent response.

**Ages 8+:** formal terminology can become more prominent; less
metaphorical scaffolding while retaining playfulness.

These are presentation defaults, not ability levels.

UI may also vary by **tier**. Early Ascending/Descending may use literal
stairs; later tiers may use abstract contour lines. The eventual
presentation model should support **Skill + Tier + AgeBand** overrides.

The current UI Presentation sheet contains generic placeholders and
should not be blindly implemented as final game designs.

## 8. Spiral mastery and journey

The primary progression metaphor is a **Duolingo-like stepping-stone
journey**, but a skill is not completed once and retired.

Intended spiral model: - introduce - revisit after other activities -
mix prior skills into later sessions - increase concept tier as
readiness grows - revisit easier/lower-agency forms for fluency and
play - unlock concepts through prerequisites rather than one strictly
linear list

A stepping stone is best thought of as a **curated learning
encounter/session**, not necessarily one permanent skill row.

Ideas currently in the sheet include completion markers, possible
parent-controlled daily gating, a companion traveling the path, and
unlockable books/crafts/instrument exploration.

Exact mastery algorithms remain TBD.

## 9. Early-childhood interaction philosophy

For young children, musical learning can happen before precise
synchronization or verbal identification.

Important models: - delayed call-and-response is still valuable - scarf
peek-a-boo with sung response - "1--2--3 ... BOOM!" with children
copying after the event - conspicuous pauses that create anticipation -
physical gestures that embody musical events

Observation, delayed imitation, movement, and anticipation are
legitimate musical development. This is why A0 and A1 exist.

## 10. Game and interaction library

### Higher / Lower

Two notes; identify relative height. Young versions can use large/small
animals or vertical movement.

### Ascending / Descending

Short scale/contour; identify direction. Young: Up/Down + stairs/slide.
Older: Higher/Lower then formal terminology. Musical difficulty scales
independently.

### Same Note Match

Hear a target pitch, audition 2--3 options, find the match. A playful
variant uses differently sized animals correlated with pitch.

### Animal Sound / Behind the Leaves

Hear an unseen animal, choose the animal, reveal it. Functions as early
auditory/timbre discrimination and a bridge into musical matching.

### Steady Beat Feel

The **animation embodies the pulse**: glowing firefly, swaying
character, breathing/bouncing object. Child may watch, bounce, sway, or
join loosely. Precision is not required.

### Tap Along to Pulse

The animation presents **target moments for synchronization**: frog
landings, glowing spots, drum targets. This differs from Steady Beat
Feel by requiring an active timed response at higher agency.

### Rhythm Echo / Call & Response

Hear a rhythm/vocal gesture and imitate after it finishes. Early
versions welcome delayed imitation.

### Count-and-Accent

"1--2--3 ... BOOM!" uses buildup plus a strong accent.

### Wait... BOO!

Conspicuous pause followed by a punctuated BOO; another character can
comically fall over. Humor is directly tied to timing, silence,
anticipation, and accent.

### Mode Contrast

Do not force `major = happy / minor = sad`. Early lenses can include
bright/dark, calm/spooky, happy/sad. Later use major/minor.

### Resolution Awareness

Early: question/answer, finished/waiting, home/away. Later:
tension/release, resolved/unresolved, tonic/cadence language.

Mode Contrast and Resolution Awareness remain separate because major
music can be unresolved and minor music can be resolved.

### Sound Making & Sound Shaping

Explore sharp/gentle onset, held sounds, release, dynamics/crescendo,
silly sustained sounds, head-shake wobble, lip trills, vocal warmups,
vowel/mouth shapes, and airflow.

A character can visibly model mouth shapes. This can be
speech-therapy-adjacent in interaction design without positioning the
app as speech therapy.

### Shake the Sound

Sustain a final syllable/note while shaking the head side-to-side,
producing a playful wobble. This should recur as a memorable embodied
musical mechanic.

### Instrument Free Play

Sandbox where children tap instruments to hear their sounds; supports
exploration and later timbre/instrument identification.

### Guided Piano / Instrument Songs

Follow colored dots/shapes, map them to notes, transition toward piano
keys, play patterns/phrases, then gradually reduce visual scaffolding.

### Sing Along With Chords / Vocal Warmups

Hear a chord/arpeggiated pattern and sing along; potentially tap notes
as they rise/fall. Bridges harmony, pitch production, contour, and vocal
warmup behavior.

### Solfege Melody Play

Hear/sing melodies using Do--Re--Mi so functional pitch syllables become
associated with sound before formal theory drills.

## 11. Embodied sound-to-visual mapping

A distinctive principle: sound should often **cause a visually analogous
event**.

Examples: - descending contour → waterfall/falling rainbow - ascending
contour → staircase/rising object - loud accent → jump/fall/burst -
pause → freeze/wait - release → open arms/object released - stomp →
environment responds - sustained wobble → visible head shake - vowel →
visible mouth shape

The visual is a second representation of musical structure, not
unrelated decoration.

## 12. Musical reward design

Success feedback should itself be musical.

Current signature stepping-stone/milestone jingle concept:

> **I've come so far**\
> **Keep watching me**\
> **I love music!**

Hidden musical wordplay: - **far** lands on **Fa** - **me** lands on
**Mi** - **music** resolves to **Do** for a home/tonic feeling

The final "music" should incorporate **Shake the Sound**: playful
sustained syllable/note + visible head wobble before resolution.

This reinforces progress, confidence, musical identity, solfege
association, and embodied participation.

Exact melody/rhythm is not locked.

## 13. Companion and feedback philosophy

Existing exploratory character work uses a warm storybook/watercolor
direction and musical reactions.

Behavioral principles: - distinct listening state - celebratory but not
overwhelming correct state - gentle "oops," not punitive failure -
larger musical milestone celebration - character motion can embody
pitch/rhythm/dynamics/contour

Explored companion concepts include Quill (living musical note) and
Belle (living handbell). Do not assume either is final unless separately
confirmed.

Especially at A0/A1, avoid making the experience feel like a test. Model
again, encourage experimentation, and let musical/visual consequences
teach.

## 14. Data/implementation guidance

Keep the curriculum data-driven where practical.

Potential conceptual entities: - Node - Skill - ConceptTier -
TierParameters - AgencyLevel - AgeBand - PresentationVariant -
Prerequisite - MasteryState - Activity/GameTemplate

Exact implementation schema is intentionally not prescribed yet.

**A game template is not necessarily a skill.** A reusable
animal-matching interaction could teach timbre, same/different, or pitch
matching. Call-and-response could exercise rhythm, contour, production,
or anticipation. Guided piano combines several domains.

Prefer reusable interaction primitives over one bespoke screen per
curriculum row.

## 15. Progression and prerequisites

The current Skill Progression sheet contains four tier rows per skill
and working min/max agency ranges. Treat these as a curriculum working
model, not immutable application logic.

Prerequisite relationships still need refinement. Do not infer that node
number means strict linear unlock order: - rhythm and pitch can develop
in parallel - sound making can begin extremely early - instrument free
play can precede formal mastery - Guided Instrument Play combines prior
abilities but can still have simple early forms

## 16. Free play vs mastery

Not every valuable interaction needs pass/fail mastery.

Possible free-play/library experiences: - instrument sandbox - vocal
exploration - listening animations - musical books - music
crafts/tutorials

The product can contain both journey activities that affect progression
and free-play activities that encourage exploration.

## 17. MVP status

The current 11-node universe is intentionally broad.

**Do not assume every node/skill ships in MVP.** MVP trimming is a
separate future product decision based on developmental value, technical
feasibility, reusable game primitives, audio requirements, and testing
burden.

## 18. How to interpret the Google Sheet

**Nodes** --- high-level domains and learning goals.

**Skills** --- current skill identities/descriptions; strongest current
inventory of the curriculum universe.

**Skill Progression** --- working four-tier and agency-range mapping.

**Difficulty Tiers** --- human-readable node-level musical complexity
matrices. These are design matrices, not necessarily final database
schema. Legacy replay rows should be removed/moved.

**Agency** --- canonical A0--A4 interaction model.

**UI Presentation** --- working age-band matrix; generic rows are
placeholders pending skill/tier-specific design.

**Visuals** --- early UX notes about journey, companion, unlocks, and
completion feedback.

**Sheet1** --- legacy/working material; do not treat as authoritative
without review.

## 19. Strong decisions

Unless revised by the product owner: - stepping-stone journey is the
primary progression metaphor - mastery spirals rather than retiring
skills permanently - concept difficulty, agency, and age/UI are
independent - there are four concept-difficulty tiers - agency is A0
Observe → A4 Precision - observation, anticipation, delayed imitation,
and embodiment are legitimate early learning - formal terminology
follows intuitive experience - visual metaphors should meaningfully
correspond to sound - replay is scaffolding/agency, not concept
difficulty - Mode Contrast and Resolution Awareness are distinct - Sound
Making & Sound Shaping is a first-class domain - guided instrument play
scaffolds from shapes/dots toward conventional keys/notation - musical
rewards should themselves reinforce musicianship - MVP trimming happens
later

## 20. Open questions --- do not silently invent

-   exact MVP subset
-   prerequisite graph
-   mastery algorithm / promotion thresholds
-   whether every skill needs all four tiers in production
-   which agency levels apply to which skills
-   final age-band boundaries
-   parent controls/daily gating
-   stars/checkmarks/scoring
-   final companion
-   exact milestone jingle melody
-   microphone/pitch detection implementation
-   sample library/licensing
-   notation timeline
-   account/progress sync
-   monetization
-   accessibility and alternate interaction modes

Surface these as TODOs/questions rather than choosing product behavior
without discussion.

## 21. Development checklist

For each activity ask:

1.  What musical skill is this teaching?
2.  What concept tier is the stimulus?
3.  What agency is required?
4.  How should it be presented for this age band?
5.  Does the visual/physical action reinforce the musical idea?
6.  Can the interaction template be reused?
7.  How will the skill spiral back into later sessions?

## Product North Star

**Build a joyful musical journey where children first feel and play with
sound, then gradually learn to hear it, shape it, name it, and make
music intentionally.**

# SongStone — Matching Grove Game Design Specification

**Author: Cooper. Supplied 2026-11-14. This is the authoritative design for Same vs Different / Matching.**

Game: Same vs. Different / Matching
Environment: The Matching Grove
Primary skill: Auditory discrimination — recognizing whether two short melodies are identical or different
Target audience: Young children, approximately ages 2–6
Agency progression: Observe → Explore → Decide

---

## 1. Core Game Concept

The Matching Game teaches children to compare two short melodies and determine whether they match.

The guiding question is: **"Do these melodies match, or are they different?"**

This is preferable to framing the activity as a yes/no question because the child can express their answer through a familiar visual matching activity.

The game connects three ideas:

1. **Auditory comparison:** Two melodies sound the same or different.
2. **Visual comparison:** Two instrument cards look the same or different.
3. **Physical interaction:** The child selects or constructs the card relationship corresponding to what they heard.

The cards are a visual representation of the musical relationship, **not** a depiction of which physical instruments played the melodies.

The child should not need to read words such as SAME, DIFFERENT, YES, or NO.

## 2. Environment — The Matching Grove

### Visual identity

A whimsical aspen grove within SongStone's established painterly storybook meadow.

- Multiple slender, white-barked aspen trees clustered along the left and right sides.
- Golden-green foliage, soft sunlight, warm illustrated aesthetic.
- An open central meadow with the distant landscape visible between the trees.
- Familiar wooden stump platforms in the foreground.
- Piper Fox and Clef standing near the outer edges of the card platforms, facing inward.

The grove should feel airy, magical and mysterious, rather than like two large individual trees.

Intentionally distinct from the other games' landmarks:
- High/Low: Pitch Tree — vertical position represents pitch.
- Loud/Soft: Sound Meter Tree — a gauge represents volume.
- Matching: Aspen Grove — two hidden musical sources invite comparison.

### Hidden musical sources

**The instruments producing the melodies are never visible in the grove.**

Melody A originates from somewhere among the trees on the left. Melody B from the right. The child hears music emerging from the environment; the only visible representation of the instrument is on the matching cards.

### Music-note animations

When a melody plays, small magical musical notes drift out from between several aspen trunks on the corresponding side. Left melody → left grove; right melody → right grove. Notes may weave between trees at different depths. Gentle and playful.

**Critical: the note animations must not reveal the actual pitches, melodic contour, or whether the melodies match.** Use visually neutral animations regardless of the notes played. Their only purpose is to indicate which side is producing sound.

## 3. Characters

**Piper Fox** — established design: upright orange fox, adventurer outfit, dark teal scarf, belt/pouch, boots. Stands in the foreground near the outer-left side of the left stump.

**Clef** — established design: small dark bronze/black anthropomorphic treble clef with expressive eyes and little arms/feet. Stands near the outer-right side of the right stump.

**Character behaviour:** both serve as guides, observers and sources of verbal encouragement. They must **not** function as answer labels — Piper must not always be associated with "matching" and Clef with "different". The position of the matching and non-matching answers is randomized independently of the characters.

## 4. Matching Cards

### Visual design

Chunky, physical-looking illustrated instrument cards consistent with SongStone's storybook art style. Each card includes a recognizable instrument illustration, a coloured card background, decorative borders and botanical details, and a consistent card silhouette and dimensions.

The same instrument type is used throughout a trial — if the trial uses oboes, all visible cards depict oboes.

### Matching pair

The two cards must be **visually identical in every detail**: instrument design and colour, background colour and texture, border and decorations, orientation and scale, position of all decorative elements.

Ideally both cards reference the **exact same sprite asset** rather than separately generated approximations.

Example: `[BROWN OBOE] [BROWN OBOE]`

### Non-matching pair

Same instrument type, clearly different visual variants. The difference should be apparent at a glance. Use contrasting card backgrounds as well as contrasting instrument colours — e.g. warm tan/gold card with brown or gold oboe; cool blue card with silver oboe.

Example: `[BROWN OBOE] [SILVER OBOE]`

Visual matching is not the skill being assessed. The cards should communicate the answer categories effortlessly.

### Important distinction

The cards do **not** represent the actual appearance of the hidden instruments. They are symbolic representations of whether the melodies matched. A different-coloured oboe card does not mean the child heard a different instrument.

## 5. Stump Platforms

Reuse SongStone's established wooden stump assets, reinforcing a consistent environmental interaction language across games.

### Observe and Explore layouts

Two broad stump platforms in the foreground, each supporting one complete pair of cards.

- Stump A: two identical cards.
- Stump B: two visibly different cards.

The pairs should be clearly separated. Each stump and its cards should read as **one large answer group**, not four unrelated buttons. Large enough for young children to recognize and tap comfortably, without overwhelming the environment.

### Decide layout

Three stumps in a triangular arrangement.

- One taller central pedestal, slightly farther into the meadow.
- Two lower foreground stumps, left and right.

The central pedestal holds a reference card and an empty card-shaped destination. Each lower stump holds one candidate card. The child drags a candidate to the central pedestal to complete the pair.

## 6. Agency Level 1 — OBSERVE

**Goal:** teach the relationship between auditory matching and visual matching without requiring the child to answer.

1. Melody A plays from the left grove.
2. Music notes emerge from the left trees.
3. Melody B plays from the right grove.
4. Music notes emerge from the right trees.
5. Piper or Clef identifies the relationship.
6. The corresponding card pair highlights or animates.

Example dialogue — matching: "Those melodies match!" Different: "Those melodies sound different!"

**Interaction:** both complete card pairs remain visible. The child can freely tap and explore without making a wrong choice. Tapping may replay sounds or trigger educational feedback. The corresponding cards can be highlighted to reinforce the relationship. Once the required exploration conditions are met, a Continue arrow appears. **No exploratory tap should unexpectedly advance the trial.**

**Learning outcome:** "These melodies matched, just like these two cards match." Or: "These melodies were different, just like these two cards are different."

## 7. Agency Level 2 — EXPLORE

**Goal:** allow the child to experiment with expressing an auditory judgment while preserving free tapping.

1. Melody A plays from the left grove.
2. Melody B plays from the right grove.
3. Piper or Clef asks: "Do those melodies match, or are they different?"
4. Both complete card pairs are displayed on their respective stumps — one pair identical, the other visibly different.

**Interaction:** the child can tap either pair freely. A single tap is not a submitted answer. When the child begins repeatedly tapping a pair, the character can acknowledge the emerging judgment — e.g. "Keep tapping if you think they match!" After approximately five consistent taps on the correct pair, the game recognizes the answer and transitions into feedback.

The repeated-tap threshold should avoid accidental completion from random alternating taps. Consecutive taps or a similarly weighted approach could be used.

**Feedback — matching melodies:** identical cards slide gently toward each other; both glow or sparkle together; the melodies may replay; Piper/Clef confirms they match.

**Feedback — different melodies:** mismatched cards gently separate or react independently; the melodies may replay; Piper/Clef confirms they are different.

Avoid negative buzzer sounds, red X symbols, or punitive feedback.

## 8. Agency Level 3 — DECIDE

**Goal:** allow the child to intentionally construct the visual relationship corresponding to the melodies. A more deliberate interaction than repeated tapping.

### Layout

```
                  [BROWN] [EMPTY]
                    CENTER STUMP
            [BROWN]           [BLUE]
            LEFT STUMP       RIGHT STUMP
```

### Gameplay

1. Melody A plays from the left grove.
2. Melody B plays from the right grove.
3. The character asks whether the melodies match.
4. The child chooses one candidate card.
5. The child drags that card onto the empty position beside the reference card.

Matching answer: `[BROWN] + [BROWN]`. Different answer: `[BROWN] + [BLUE]`.

### Interaction rules

Tapping is exploratory. Dragging is the intentional answer. Tapping a card should not submit an answer. The child can still replay the melodies using the game's listening controls. The destination should have a generous drop zone and snap the card into place.

### Randomization

Randomize the positions of the matching and non-matching candidates. The reference card can also vary between trials.

- Trial 1: reference brown oboe; match brown oboe; different silver oboe.
- Trial 2: reference silver oboe; match silver oboe; different brown oboe.

This prevents children from learning that a particular colour or screen position always represents matching.

### Feedback

When a card is placed, animate the completed pair and provide supportive auditory feedback. The completed pair should visually reinforce the relationship the child selected. Incorrect answers should be handled gently, using the game's existing retry/scaffolding system. **The precise retry and correction behaviour still needs to be defined.**

## 9. Shared Interaction Principles

**Safe exploration.** Tap = explore/listen. Drag = intentional answer, where appropriate. Observe and Explore allow free interaction; Decide requires a deliberate action to submit.

**No unnecessary reading.** Children should understand the choices through pictures, placement, sound and animation. Written labels are not required for child-facing choices. Adult-facing instructions may still appear in the existing top UI.

**Avoid visual answer leakage.** Do not communicate the correct auditory relationship through different note-animation patterns, pitch-dependent movement of music notes, different-coloured musical effects for matching vs different melodies, or premature highlighting of the correct cards in Explore or Decide. The child should make the auditory judgment by listening.

**Reusable visual assets.** Prefer reusing existing stump platforms, instrument card sprites, Piper and Clef sprites, meadow/background elements, and established UI buttons and listening controls. New artwork should primarily provide the aspen grove environment and any required decorative/animation elements.

## 10. Musical Difficulty vs Agency

Agency and musical difficulty remain independent. Agency determines how the child interacts; musical difficulty determines how challenging the melodies are to distinguish.

- Easy matching: C–D–E vs C–D–E
- Easy different: C–D–E vs C–E–D
- Subtler different: C–D–E vs C–D–F

Illustrative examples, not a finalized difficulty curriculum. The same agency mechanic should support increasingly challenging musical comparisons without requiring a more complicated physical interaction.

## 11. Core Design Philosophy

The Matching Grove is not a multiple-choice quiz with decorative cards. Its central principle:

**The child hears a musical relationship and expresses that relationship through a familiar physical matching activity.**

- OBSERVE: "I listen and discover what matching means."
- EXPLORE: "I can experiment and show what I think."
- DECIDE: "I intentionally complete the pair to represent what I heard."

The third level is called Decide rather than Drag because its defining feature is intentional answer submission, not a particular motor gesture. For Matching, dragging a card is especially appropriate because it physically completes the pair.

## 12. Implementation Notes / Open Decisions

Treat as considerations rather than finalized requirements:

- Exact Observe exploration threshold before Continue appears.
- Whether tapping the grove, cards, or a Listen Again control replays individual melodies or the full comparison.
- Exact Explore tap threshold and counter-reset behaviour.
- Incorrect-answer handling and retry flow in Decide.
- Card animation timing and feedback audio.
- Whether reference-card and candidate-card imagery changes between every trial or less frequently.
- How the game transitions between agency levels without abruptly changing the interface.

The core visual metaphor, layout concepts and agency progression described above are the agreed design direction.

**Important: preserve existing SongStone architecture and agency/difficulty systems where possible. Treat this specification as the intended game design, not as a request to replace existing implementation patterns without reviewing them first.**

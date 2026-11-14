# Same or Different (the Matching Grove): reconciliation notes (NOT BUILT YET)

⚠️ **THE AUTHORITATIVE DESIGN IS COOPER'S SPEC:
[`MATCHING_GROVE_SPEC.md`](MATCHING_GROVE_SPEC.md)** (supplied 2026-11-14,
committed unedited). Read that first. This file holds only what the spec
leaves to the build:

- how it reconciles with decisions made elsewhere;
- the questions still open for Cooper;
- facts about the art.

An earlier version of this file, written from a summary, got the
mechanic wrong and has been replaced.

The game in `lib/games/same_different/` is the OLD prototype: two melodies
of the generic `Note` tone and a plain same/different answer, not built on
the game template. The spec replaces it rather than editing it.

## ⚠️ The core point the earlier version got wrong

**The instruments are NEVER visible.** Melody A comes from hidden sources
among the aspens on the left, melody B from the right. The cards are
SYMBOLIC OF THE RELATIONSHIP: identical cards mean "the melodies matched",
different cards mean "they differed". A silver oboe card does NOT mean a
silver oboe played (spec §2, §4).

Implementation note: the note audio is mono, so "from the left grove" is
carried by the note animations on that side, not by the sound itself.
Stereo panning (the audio engine supports it) would reinforce it. That is
Cooper's call, and it is not in the spec.

## Resolved against existing decisions

### Decide's incorrect-answer handling: ANSWERED by card 212

Spec §8 says the retry and correction behaviour "still needs to be
defined", and §12 lists it as open. **Card 212 (control of error) already
defines it:**

- the apparatus responds truthfully;
- the characters stay quiet about mistakes;
- nothing reacts to a single error, only to patterns.

Here, a wrongly placed card simply fails to complete the pair and slides
back to its stump, with no character comment. It is the same shape as the
Loud or Quiet dial's lock staying shut on a wrong drop (card 208). Any
nudge responds to PERSISTENCE (the five-repeat rule), never to one wrong
drop. **This item is removed from the open list.** It also applies card
221: the drop zone accepts whenever it lights up, generously, by the
dragged card's position, not the finger's.

### Both characters on screen at every level: a DELIBERATE EXCEPTION to card 222

In High vs Low and Loud or Quiet, card 222 settled that **only the asking
character appears at Explore and Decide.** This spec has BOTH Piper and
Clef present at every level, flanking the stumps, and requires that
neither becomes an answer label (§3: "the position of the matching and
non-matching answers is randomized independently of the characters").

⚠️ **This is deliberate.** It is a different game with different needs.
Here the characters guide; they are never the poles of the answer. Do NOT
"fix" it to match the other two games.

## ⚠️ Open for Cooper

### 1. §12 contradicts §5: the Explore → Decide layout change is abrupt

§12 lists "how the game transitions between agency levels without abruptly
changing the interface" as open. But §5's layouts DO change abruptly:

- Observe and Explore have **two stumps side by side**, each holding a
  whole pair;
- Decide has **three stumps in a triangle**: a reference card and an empty
  slot on a tall centre pedestal, and one candidate on each low stump.

The whole arrangement rearranges at the same moment the child is asked for
a new kind of answer. **Question for Cooper:** can Decide work on the
two-stump layout (for example, the reference card held up by a character,
or the empty slot on one stump), or is the triangle worth the
discontinuity?

### 2. §7's "keep tapping" cue against card 210

Spec §7 has the character acknowledge the judgement "when the child begins
repeatedly tapping a pair" ("Keep tapping if you think they match!").
**Card 210** revised the equivalent High vs Low cue:

- it must NOT fire on early taps, because with two options the first tap
  is right half the time by chance;
- the cue belongs to taps SPREAD ACROSS BOTH options with no repetition, as
  a nudge, once per round set.

The spec's cue fires on REPEATED taps on one pair, which is a different
trigger, and its wording names the answer category the child is leaning
towards. Check with Cooper which rule holds here, so Explore's three nudge
conditions don't collide:

- nothing happening at all;
- five taps on the wrong option;
- taps spread across both options.

The five-tap answer threshold itself matches the app's existing rule.

### Smaller notes

- **Ages:** §0 says "approximately ages 2–6"; the app's age bands run to
  6–8. This probably doesn't matter, but noting it.

### Still open, from §12 (unchanged)

- The Observe exploration threshold before Continue appears.
- What tapping the grove, the cards or a listen-again control replays.
- The Explore tap threshold and counter-reset behaviour (the app's
  standard is five).
- Card animation timing and feedback audio.
- How often the reference and candidate imagery changes.

## Cards: art facts

### Conventions (every future card must match)

1. ⚠️ **The warmer or lighter variant goes on the CREAM card; the cooler or
   darker one on the BLUE card.** Pale cello and gold trumpet are on cream;
   dark cello and silver trumpet on blue. "These match" can then be read
   partly from warmth, which matters at stump size.
2. **No faces.** Instruments on cards are formal and faceless, unlike the
   in-game sprites, which are characters. An earlier electric guitar pair
   had faces and was replaced.

### Slicing into SINGLE, REUSABLE cards (spec §4)

Spec §4 wants a matching pair to reference **the exact same sprite asset**.
So each two-card sheet is sliced into two SINGLE-card assets (A and B), and
the game composes pairs from them:

- a matching pair is one asset drawn twice;
- a mismatched pair is A + B.

A baked two-card image is never used.

⚠️ Slice from MEASURED bounds, never an even split; pin the bounds with a
test that re-measures them from the file, as
`test/journey/avatar_pin_slices_test.dart` does. Measured 2026-11-14:
columns, then rows, of pixels above alpha 8.

| Sheet | Card A (x, y) | Card B (x, y) | Separates cleanly? |
|---|---|---|---|
| bells | 51–755, 33–991 | 776–1485, 33–991 | Yes, 21 px gap |
| cello | 66–749, 28–991 | 782–1469, 28–992 | Yes, 33 px |
| electricguitar | 14–746, 16–1002 | 752–1521, 15–1003 | Yes, but only a 6 px gap |
| flute | 30–754, 20–1002 | 774–1505, 20–1002 | Yes, 20 px |
| guitar | 38–758, 10–1008 | 772–1500, 10–1009 | Yes, 14 px |
| oboe | 43–760, 25–995 | 775–1492, 26–995 | Yes, 15 px |
| piano | 34–760, 18–1001 | 771–1501, 18–1003 | Yes, 11 px |
| trumpet | 31–760, 22–1000 | 770–1504, 22–1001 | Yes, 10 px |
| tuba | 24–751, 26–992 | 771–1510, 26–992 | Yes, 20 px |
| violin | 21–752, 17–1001 | 767–1511, 17–1001 | Yes, 15 px |
| xylophone | 20–755, 26–985 | 769–1515, 26–986 | Yes, 14 px |
| **drum** | 32–758 | 773–1504 | ⚠️ **No transparent gap:** the two glows touch. It separates only above alpha 100. Cut at column 766, the faintest column (alpha at most 32), and accept a trace of the neighbour's glow, or ask Cooper for a re-export with a gap. |

Each sheet is sliced to ONE slice size for both of its cards, so the pair
draws at one scale. Re-measure whenever a sheet is revised.

### Cards against audio

Twelve card sheets are in
`assets/images/journey/cards_<instrument>_pair.png`. Each is 1536×1024
RGBA, copied byte-for-byte and verified by checksum. Every sheet tops out
at alpha 254, which is Cooper's export setting, not a defect.

| Cards | Audio | Can it be offered? |
|---|---|---|
| bells | 13 notes, C6–C7 | Yes |
| cello, flute, oboe, piano, trumpet, violin | 24 notes, C4–B5 | Yes |
| guitar | 22 notes, C3–B4 (A3 and A♯4 missing) | Yes. Melodies must avoid the two holes. |
| tuba | Only G♯3–B3 (4 notes) usable on a speaker | ⚠️ Barely: a melody has just 4 notes to move in. |
| xylophone | Not yet sourced (Iowa has F4–C8) | Not until the samples land. |
| drum | NONE, and unpitched | ⚠️ **NO.** Not until it is decided whether drum belongs in this game (comparing RHYTHMS) or in the rhythm game. |
| electric guitar | NONE in any library we use | ⚠️ **NO.** Needs a third source and a new licence question. |

Note: because the cards are symbolic (they say nothing about which
instrument played), the card instrument and the audio instrument need not
match in principle. Spec §4 does keep one instrument type across the cards
within a trial.

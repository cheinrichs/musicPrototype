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

## ⚠️ Cooper's amendments to the spec (2026-11-14), which override it

### A1. DECIDE USES TWO STUMPS, NOT THREE (replaces spec §5 "Decide layout")

Cooper rejected §5's three-stump triangle. For accuracy: the triangle
never meant three melodies. It is always TWO melodies, with a reference
card, an empty slot and two candidates.

**The two-stump Decide, which loses nothing:**

- one stump holds the **reference card and the empty slot**;
- the other stump holds **both candidates**;
- the child drags a candidate across to the empty slot.

Same gesture, same meaning, same randomisation rules (§8): the reference
variant varies, and so does which candidate is the match.

⚠️ **This closes §12's open question** about moving between agency
levels without an abrupt interface change. The LAYOUT IS NOW THE SAME at
Observe, Explore and Decide: two stumps, flanked by the characters. Only
what sits on the stumps changes:

- Observe and Explore: a whole pair on each stump;
- Decide: a reference card and an empty slot on one, two candidates on the
  other.

The place where the interface rearranged itself at the moment the child
was asked for a new kind of answer is gone.

### A2. Both characters at all three levels — and character size is PER GAME

Confirmed by Cooper: Piper and Clef both appear at Observe, Explore and
Decide. This is a deliberate exception to card 222 (see below).

⚠️ **It is CONDITIONAL ON FITTING.** Cooper: "we'll have to see how it
feels fitting on the screen. that's the biggest factor." This is the most
crowded of the three game screens: two stumps each carrying a PAIR of
cards, plus two characters flanking them. Piper has been enlarged twice
for the other screens (card 209 by 25%, then a further 50%), and at that
size she will almost certainly not fit here.

⚠️ **So character size is PER GAME, never one global value.** It already
is, in code: each screen's layout sizes the characters for its own room
(`SceneLayout.piperHeight` for High vs Low, `LoudQuietLayout.piperHeight`,
`JourneyMapGeometry.piperHeight`), and `CharacterArt` says so. The Grove
gets its own layout with its own size. **Never match Piper here to her
size on another screen.**

When the screen is composed: report the character scale that actually fits
on every target device (an iPhone SE in landscape is the tightest), with
renders, and flag it for Cooper's eye BEFORE treating it as settled.

## ⚠️ IMPLEMENTATION CONSTRAINT: the drifting notes must never carry the answer

The notes are built in CODE: the `♪` of `DriftingNotes`, sparkles and
flutter_animate, with no new art. That turns spec §9's "no visual answer
leakage" from something a pre-rendered animation got for free into an
ACTIVE OBLIGATION. The melody data is right there, and the obvious
implementation (one note per played note, rising with its pitch) would
draw the answer on the screen.

**So the emission is driven by a TIMER and a FIXED (or random) PATTERN.**
The ONLY thing tied to the music is WHICH SIDE emits: the left grove while
melody A plays, the right while melody B plays. The same count, the same
rhythm and the same look, whatever the notes are and whether the melodies
match. Never derive a note's count, height, timing, colour or path from
the melody. (`DriftingNotes` already works this way: two notes on a fixed
pattern, regardless of what sounds.)

A review must check this; a test should pin it (the emitted pattern is
identical for matching and differing melodies).

## The grove art: two layers, and the layer order

Delivered 2026-11-14 as two layers, so the notes can genuinely pass
BEHIND the near trunks (spec §2's "weave between trees at different
depths" needs this; a single flat painting could not do it):

- `assets/images/grove/grove_background_far.png`: the distant meadow,
  waterfall and mountains. 1672×941. Max alpha 248, so about 3% bleeds
  through; invisible, and Cooper's export setting. Do NOT re-save.
- `assets/images/grove/grove_foreground_trunks.png`: the near aspens,
  canopy and ground foliage, with a clean cut-out through the centre.
  1672×941 RGBA, 40.6% fully transparent.
- `docs/reference/REFERENCE_grove_composited.png`: the two assembled.
  REFERENCE ONLY; never ship it.

Same size, so they overlay with no alignment work. Not registered in
`pubspec.yaml` until the Grove is built.

⚠️ **LAYER ORDER, back to front. This is what makes the weaving work:**

1. `grove_background_far`
2. **the drifting music notes**
3. `grove_foreground_trunks`
4. stumps, cards, characters, UI

The notes sit BETWEEN the two background layers, so they pass behind the
near trunks and reappear. Everything interactive sits ABOVE the trunks, so
nothing hides Piper, Clef or a card the child must tap. Notes above the
trunks lose the depth; characters below them get a tree through Piper.

⚠️ **NOTE PATHS STAY IN THE OUTER THIRDS.** The foreground's centre is
open, so a note drifting into the middle has nothing to pass behind and
stops reading as coming from among the trees. This also matches §2: notes
emerge from between the trunks on each side.

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

### Both characters on screen at every level: a DELIBERATE EXCEPTION to card 222 (confirmed by Cooper, A2)

In High vs Low and Loud or Quiet, card 222 settled that **only the asking
character appears at Explore and Decide.** This spec has BOTH Piper and
Clef present at every level, flanking the stumps, and requires that
neither becomes an answer label (§3: "the position of the matching and
non-matching answers is randomized independently of the characters").

⚠️ **This is deliberate, and Cooper has confirmed it.** It is a different
game with different needs. Here the characters guide; they are never the
poles of the answer. Do NOT "fix" it to match the other two games. It is
conditional only on fitting the screen (A2).

## ⚠️ Open for Cooper

### ~~1. The Explore → Decide layout jump~~ — CLOSED by amendment A1

§12's question was how to move between agency levels without an abrupt
interface change, and §5's triangle made it abrupt. With two stumps at
every level (A1), the layout no longer changes at all.

### ~~2. §7's "keep tapping" cue against card 210~~ — RESOLVED by Cooper: no conflict

§7's cue ("Keep tapping if you think they match!") stands as the spec
writes it. Card 210's rule exists because a first correct tap is right half
the time by CHANCE, so a cue must not CONFIRM it. This cue confirms
nothing: it is neutral as to correctness, and reads identically whether
the child is tapping the right pair or the wrong one. Do not reopen it.

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
- ~~Moving between agency levels without an abrupt interface change.~~
  Closed by amendment A1: the layout is the same at every level.
- The character scale that fits this screen (A2): to be measured when it
  is composed, and judged by Cooper.

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
| flute | 28–760, 24–998 | 769–1505, 24–999 | Yes, 9 px. ⚠️ NEW SHEET 2026-11-20: a keyed concert flute, not the old recorder (superseded sheet not shipped). |
| guitar | 38–758, 10–1008 | 772–1500, 10–1009 | Yes, 14 px |
| oboe | 43–760, 25–995 | 775–1492, 26–995 | Yes, 15 px |
| piano | 34–760, 18–1001 | 771–1501, 18–1003 | Yes, 11 px |
| trumpet | 31–760, 22–1000 | 770–1504, 22–1001 | Yes, 10 px |
| tuba | 24–751, 26–992 | 771–1510, 26–992 | Yes, 20 px |
| violin | 21–752, 17–1001 | 767–1511, 17–1001 | Yes, 15 px |
| xylophone | 20–755, 26–985 | 769–1515, 26–986 | Yes, 14 px |
| **drum** | 32–758 | 773–1504 | ⚠️ **No transparent gap:** the two glows touch. It separates only above alpha 100. Cut at column 766, the faintest column (alpha at most 32), and accept a trace of the neighbour's glow, or ask Cooper for a re-export with a gap. |
| tomtom (new 2026-11-20) | from the manifest: cut at 764 | | Yes: x=764 and x=768 both fully clear |

Each sheet is sliced to ONE slice size for both of its cards, so the pair
draws at one scale. Re-measure whenever a sheet is revised.

⚠️ WHERE TO CUT (2026-11-20): `assets/images/characters/instruments/
SLICE_POINTS.json` is the source of truth for every card pair's cut (and
every three-variant instrument and character sheet). Cut each pair at its
single x: [0:x] and [x:W]. The midpoint cuts into the art on the electric
guitar (cut at 749) and violin (759) sheets. Use the manifest for all of
them, one code path. `test/games/high_low/instrument_sheets_test.dart`
asserts no opaque pixel (alpha ≥ 128) sits on any cut or at any crop's
edge. The drum pair's glow crosses its cut at alpha ≤ 33 down the whole
height, which is allowed.

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
| drum (rope-tension snare) | the snare hit (`DrumHit.snare`), unpitched | ⚠️ **NOT YET.** Not until it is decided whether drums belong in this game (comparing RHYTHMS) or in the rhythm game. |
| tom-tom (concert tom) | the tom hit (`DrumHit.tom`), unpitched | ⚠️ **NOT YET**, same reason as the drum. |

⚠️ **TWO DRUMS, TWO INSTRUMENTS (2026-11-20).** `cards_drum_pair.png` is
the rope-tension snare and `cards_tomtom_pair.png` the concert tom. The
spec keeps ONE instrument type throughout a trial, so whatever picks a
trial's card set must treat them as two distinct instruments, never as
two variants of "drum", and never mix them within a trial. (No code picks
card sets yet; this is the rule for when it is built.)
| electric guitar | NONE in any library we use | ⚠️ **NO.** Needs a third source and a new licence question. |

Note: because the cards are symbolic (they say nothing about which
instrument played), the card instrument and the audio instrument need not
match in principle. Spec §4 does keep one instrument type across the cards
within a trial.

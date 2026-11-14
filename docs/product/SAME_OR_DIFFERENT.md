# Same or Different — the specified mechanic (NOT BUILT YET)

Specified by Cooper, 2026-11-14, with art. Recorded so it is not
re-derived; the build waits on the queue (profile chain first).

The game in `lib/games/same_different/` is the OLD prototype (two melodies
of the generic `Note` tone, a plain same/different answer, not on the game
template). This spec replaces its screen and mechanic; it is not an edit of
that one.

## Art

- `assets/images/journey/cards_cello_pair.png` — cello, two variants: pale
  wood on a cream card, dark wood on a blue card.
- `assets/images/journey/cards_bells_pair.png` — bells, two variants: gold
  and silver.
- `docs/reference/REFERENCE_same_or_different_screen.png` — the composed
  screen, REFERENCE ONLY (it shows a woodwind; the instrument is
  illustrative). Piper stands at the left, Clef at the right, two stumps in
  the middle, each holding a pair of cards.

All copied byte-for-byte (sha256 checked). Both sheets are 1536×1024 RGBA,
transparent around each card. Each card has a soft coloured glow (orange
behind the cream card, blue behind the blue card).

## The mechanic

⚠️ **The cards are a visual vocabulary for the CONCEPT, not a picture of
the melodies.** Two stumps, each holding a PAIR of cards:

- one stump holds two **matching** cards — "same";
- the other holds two **mismatched** cards — "different".

The child hears two melodies and taps the stump whose pair says what they
heard.

Each instrument's sheet holds two variants of that instrument (A and B).
The game COMPOSES the pairs from them: A + A for "same", A + B for
"different".

## Slicing

⚠️ **Slice each sheet into INDIVIDUAL cards.** The game must place the same
variant twice on one stump, so a two-card sheet is unusable as-is.

⚠️ **Slice from MEASURED bounds, never an even split down the middle.**
That is how the avatar pins went wrong (an even grid drifted and caught the
neighbour). The cards have generous margins, so a drifted slice would be
subtle and harder to catch.

Measured 2026-11-14 (columns with any pixel above alpha 8, glow included):

| Sheet | Card A columns | Card B columns | Gap |
|---|---|---|---|
| cello | 66–749 | 782–1469 | 33 px |
| bells | 51–755 | 776–1485 | 21 px |

When building, measure the rows too, decide whether the glow belongs in the
slice, and pin the bounds with a test that re-measures them from the file,
as `test/journey/avatar_pin_slices_test.dart` does.

## Composition rules

All of these stop a visual or positional shortcut from replacing the
judgement being taught. It is the same principle as keeping the games
side-agnostic.

1. **Vary which variant forms the MATCHING pair.** If "same" were always
   cream + cream, a child could learn "pick the stump with two cream cards"
   without ever judging sameness. Sometimes it is blue + blue.
2. **Vary the ORDER of the MISMATCHED pair**: sometimes A + B, sometimes
   B + A.
3. **Vary WHICH STUMP is which**: "same" cannot always be the left stump.

## Card conventions — every future card must match

Established across all twelve sheets (2026-11-14):

1. ⚠️ **The warmer or lighter variant goes on the CREAM card; the cooler or
   darker one on the BLUE card.** Pale cello and gold trumpet are on cream;
   dark cello and silver trumpet on blue. "These match" can then be read
   partly from warmth, without the child having to identify the
   instrument, which matters at stump size.
2. **No faces.** Instruments on cards are formal and faceless, unlike the
   in-game sprites, which are characters. An earlier electric guitar pair
   had faces and was replaced.

## Instruments — cards against audio (2026-11-14)

Twelve card sheets are in
`assets/images/journey/cards_<instrument>_pair.png`. Each is 1536×1024
RGBA, copied byte-for-byte and verified by checksum. Every sheet tops out
at alpha 254, which is Cooper's export setting, not a defect.

| Cards | Audio | Can it be offered? |
|---|---|---|
| bells | 13 notes, C6–C7 | Yes |
| cello, flute, oboe, piano, trumpet, violin | 24 notes, C4–B5 | Yes |
| guitar | 22 notes, C3–B4 (A3 and A♯4 missing) | Yes. Melodies must avoid the two holes. |
| tuba | 24 files, but only G♯3–B3 (4 notes) usable on a phone speaker | ⚠️ Barely: a melody has just 4 notes to move in. |
| xylophone | Not yet sourced (Iowa has F4–C8) | Not until the samples land. |
| drum | NONE, and unpitched | ⚠️ **NO.** Never offer drum until it is decided whether drum belongs in this game (comparing RHYTHMS, not melodies) or in the separate rhythm game. That question is open between Cooper and the user. |
| electric guitar | NONE in any library we use | ⚠️ **NO.** Needs a third source and a new licence question. |

Every sheet needs its own measured slices. Only the first cello and bells
columns were measured above, and must be re-checked if a sheet is revised.

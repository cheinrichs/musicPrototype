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

## Instruments

Cello and bells both have full, audited sample libraries (see the
instrument inventory, 2026-11-14), so both cards can play.

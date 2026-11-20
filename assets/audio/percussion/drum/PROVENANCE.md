# Drum hits — provenance

⚠️ **ATTRIBUTION: COURTESY, NOT REQUIRED** (Philharmonia's terms, below).

⚠️ **UNPITCHED. NOT A NOTE LIBRARY.** These are HITS to sequence into
rhythms (`lib/audio/drum_hit.dart`, `DrumHit`), deliberately kept outside
`assets/audio/notes/` and out of `HighLowInstrument`. A drum has no pitch
to be high or low.

**Source:** Philharmonia Orchestra sound samples, percussion pack —
https://philharmonia.co.uk/audio-sound-samples

**Licence (Philharmonia's own words, checked by Cooper 2026-11-14):**

> "You are free to use these samples as you wish, including releasing them
> as part of a commercial work. The only restriction is that they must not
> be sold or made available 'as is' (i.e. as samples or as a sampler
> instrument)."

NOT Creative Commons (see docs/product/SAMPLE_PROVENANCE.md).

## Files

| File | Source file in the pack | Why |
|---|---|---|
| `snare.mp3` | `snare-drum__025_mezzo-forte_with-snares.mp3` | The drum art is a rope-tension snare with sticks. |
| `tom.mp3` | `tom-toms__05_mezzo-forte_struck-singly.mp3` | ⚠️ INTENTIONALLY UNUSED (2026-11-20), see below. |

The bass drum (`bass-drum__1_mezzo-forte_bass-drum-mallet`) was tried and
rejected: only 16% of its energy is above a phone speaker's 200 Hz
rolloff (snare 77%, tom 85%).

## History

2026-11-14: fetched individually from the pack by HTTP range request,
cut at the hit and padded to 1.645625 s by `tool/split_note_runs.py`,
mono 44.1 kHz, 64 kbps mp3. Loudness was normalised towards −18 LUFS;
both hits are peak-limited at about −19.6 LUFS.

## The snare is the confirmed match (2026-11-20)

The snare was **confirmed as the right sample for the drum art by a
musician Cooper consulted.** That confirmation is by ear, not by
measurement.

⚠️ DO NOT REOPEN THIS ON A BRIGHTNESS NUMBER. Measured, the snare is
bright and shallow (spectral centroid about 4 kHz, mostly wire), and on
those numbers alone it was questioned against the art's deep-shelled
field drum. The measurement was accurate; the conclusion drawn from it
was wrong. The search for a Philharmonia tenor or field drum, and a
layered snare+tom test, were both cancelled.

## `tom.mp3`: INTENTIONALLY UNUSED (2026-11-20)

- **Source:** Philharmonia percussion, `tom-toms__05_mezzo-forte_struck-singly.mp3`.
- **Why it was pulled (2026-11-14):** a second, lower voice for accents.
- **Why it is not used:** no instrument art depicts a tom, and the snare
  is the confirmed match for the drum art.
- **Kept** (13 KB): it may be wanted if a tom is ever drawn.
- **Not referenced by any code:** removed from `DrumHit` the same day, so
  nothing can play it by accident.

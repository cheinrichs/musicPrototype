# Note-sample provenance — the index

Where every note library came from, under what terms, and whether its
credit is REQUIRED or a courtesy. The per-file records sit beside the
audio: `assets/audio/notes/<instrument>/PROVENANCE.md`, and
`assets/audio/notes/bells/ATTRIBUTION.md` for the bells.

| Instrument | Source | Licence | Credit |
|---|---|---|---|
| Bells | InspectorJ, "Hand Bells, Singles" (Freesound pack 19255) | CC BY 4.0 | ⚠️ **REQUIRED**. Removing it breaches the licence. |
| Cello, flute, violin | Philharmonia Orchestra (strings, woodwind) | Philharmonia's own terms (below) | Courtesy |
| Guitar | Philharmonia Orchestra | Philharmonia's own terms | Courtesy |
| Oboe, trumpet, tuba | Philharmonia Orchestra (woodwind, brass) | Philharmonia's own terms | Courtesy |
| Piano, xylophone | University of Iowa Musical Instrument Samples | Free for any project, without restriction | Courtesy |
| Drum (2 hits, unpitched) | Philharmonia Orchestra (percussion) | Philharmonia's own terms | Courtesy |

The credits screen lists all three sources (`lib/app/credits_data.dart`).
Each entry carries `attributionRequired`, and
`test/app/credits_data_test.dart` fails if the required credit is removed
or a courtesy is mislabelled.

## Philharmonia's licence — settled 2026-11-14

Cooper checked Philharmonia's own page
(https://philharmonia.co.uk/audio-sound-samples):

> "You are free to use these samples as you wish, including releasing them
> as part of a commercial work. The only restriction is that they must not
> be sold or made available 'as is' (i.e. as samples or as a sampler
> instrument)."

Embedding the samples in this app is the permitted commercial use;
republishing them as a sample pack is what's forbidden.

⚠️ **It is NOT Creative Commons.** Commit e5730e3's message calls the
Philharmonia brass pack "free, CC-licensed". That is wrong: the claim came
from a third-party GitHub mirror, not from Philharmonia. A pushed commit's
message is not rewritten, so this file is the correction. Do not reopen it.

## The 2026-11-14 pull

- **Xylophone:** Iowa, F4–C8 (44 notes), rosewood, mezzo-forte. The
  samples are in, but it is NOT YET PLAYABLE: it has no sprite art, and its
  loudness is uneven, lowest at the bottom. See
  `assets/audio/notes/xylophone/PROVENANCE.md`.
- **Flute and violin:** extended C6–C7 (card 148), from the same
  Philharmonia take as before.
- **Guitar:** A3 restored from another take. Awaiting Cooper's ear.
- **Drum:** two Philharmonia hits (snare, tom), unpitched, in
  `assets/audio/percussion/drum/`.
- **Electric guitar:** in neither library. It needs a third source and a
  new licence question.

## ⚠️ UNDOCUMENTED: `assets/audio/notes/percussion/` (24 raw .aif files)

These were committed 2026-04-27 (ffed98e, "for future use in rhythm games")
with NO record of their source or licence. Their names (`tambourinevintage`,
`sleighbellsvintage`, `jamblockhigh`, `cajonsnare`) look like a commercial
library's. They are registered in `pubspec.yaml`, so they SHIP in the app,
although no code plays them. They are also raw AIFFs, against the rule of
committing only mp3s. **A decision is needed:** find their source and
licence, or remove them from the app bundle.

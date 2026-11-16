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

- **Xylophone:** Iowa, F4–C8 (44 notes), rosewood, mezzo-forte. A TRIAL
  instrument, dev profile only, using Cooper's UI-Kit art. Its loudness is
  uneven, lowest at the bottom, and that is what the trial is for. See
  `assets/audio/notes/xylophone/PROVENANCE.md`.
- **Flute and violin:** extended C6–C7 (card 148), from the same
  Philharmonia take as before.
- **Guitar:** A3 restored from another take. Awaiting Cooper's ear.
- **Drum:** two Philharmonia hits (snare, tom), unpitched, in
  `assets/audio/percussion/drum/`.
- **Electric guitar:** in neither library. It needs a third source and a
  new licence question.

## ⚠️ `assets/audio/notes/percussion/` (24 raw .aif files): Logic Pro, NOT our three libraries

Traced 2026-11-15. Nothing has been deleted.

- **How they arrived:** commit ffed98e, 2026-04-27, authored by Cooper
  (with Claude Sonnet 4.6), "Add percussion assets, roadmap…, for future
  use in rhythm games". It also added ROADMAP.md and registered the folder
  in `pubspec.yaml`. No source was named.
- **The metadata says where they came from.** All 24 carry the AIFF comment
  **"Creator: Logic Pro 11.2.2"**, a Logic `LGWV` chunk, and markers
  "Tempo: 109.0" plus a project timestamp. They were BOUNCED FROM A LOGIC
  PRO PROJECT at 109 BPM.
- **The format matches none of our three sources.** Every file is 16-bit
  44.1 kHz stereo, exactly 0.55 s long, about 98 KB: a uniform batch
  export.
  - Iowa ships 24-bit AIFFs named like `5.5wb.mf.aif` or
    `xylophone.rosewood.mf.C5B5.aif`.
  - Philharmonia ships mp3s named like `tom-toms__05_mezzo-forte_…`.
  - InspectorJ ships Freesound WAVs with titles like "Hand Bells, Low C".
  - These names (`jamblockhigh`, `congabrightlow`, `cowbelldry`,
    `tambourinevintage`) read like the pieces of a Logic percussion kit.
- **Nothing plays them.** The only reference in code is a comment in
  `rhythm_game_state.dart`. They still SHIP, because the folder is
  registered in `pubspec.yaml`.
- **Licence:** Apple's Logic Pro sound content is licensed for use in your
  own compositions. Whether loose one-shot samples shipped inside an app
  count as that, or as redistributing the samples themselves, should be
  checked against the licence text. **Cooper's call; not decided here.**

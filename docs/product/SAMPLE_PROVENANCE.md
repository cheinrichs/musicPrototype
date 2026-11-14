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
| Piano | University of Iowa Musical Instrument Samples | Free for any project, without restriction | Courtesy |

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

## Available but not yet sourced (2026-11-14)

- **Xylophone:** the University of Iowa percussion set has it, recorded
  note by note at three dynamic levels. It is the same source and terms as
  the piano, so there is no new licence question. Cooper recalls a decision
  to fetch it that was dropped; nothing in the repo or the commit history
  records it. Its art is in the UI Kit, not in this repo.
- **Drum:** neither library has a pitched drum (noted in bdab53d), so it
  can never serve High vs Low. Iowa's percussion could serve a rhythm game.
- **Electric guitar:** in neither library. Art only.

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

## Lead-in trims, 2026-11-15

Cooper approved cutting the dead start off the slow files (groups A and
B of the onset audit), keeping the originals.

- **Trimmed:** all 13 bells (a silent pad of 150–440 ms) and 7 guitar
  notes (240–700 ms of low rumble before the pluck). Each file's cut is
  recorded in its library's PROVENANCE.md or ATTRIBUTION.md.
- **Not trimmed:** the 4 cello files in group A. They're the right note
  from 20–30 ms in, which means a real bowed attack, not a false start.
  See `assets/audio/notes/cello/PROVENANCE.md`.
- **On hold (Cooper's call):** group C, the naturally slow attacks of
  trumpet, oboe, flute, violin and cello.
- **Originals:** byte-for-byte at `docs/audio_originals/notes/`, which
  doesn't ship. Undo a file by copying it back.
- **Tool:** `tool/trim_note_start.py`. Check the lead-in's pitch before
  using it. A quiet start that is already the note is an attack.

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
- **2026-11-20:** almost certainly Logic's own stock percussion, triggered
  and bounced (24 instruments, one identical length, one 109 BPM project),
  not original recordings; to confirm with Cooper. Marked INTENTIONALLY
  UNUSED in the folder's own `PROVENANCE.md`. Not deleted.

## ⚠️ THE RULE FOR EVERY SAMPLE IN THE REPOSITORY (2026-11-20)

Every sample in the repository is EITHER in use with a documented source,
OR explicitly marked unused with a reason, its source and a date. Nothing
sits in the tree unexplained. An unused sample still wired into a code
path is worse than an unused file: take it out of the code.

The 24 percussion .aif files and the seven playground clips each cost an
investigation because nobody wrote this down when they were added.

## Does the art match the sound? (the rule, 2026-11-20)

Cooper found the playable flute drawn as a recorder while its samples
were a concert flute. In a game about listening to instruments, art that
promises one instrument while the audio delivers another is a defect.

**THE STANDARD, in Cooper's words:** "the tone between a recorder and a
real flute is very obvious so the visual disconnect was just too big, but
many of these are probably easy to buy into the samples being a very
similar adjacent instrument."

⚠️ JUDGE THE SOUND, NOT THE NAME. The first audit ticked the drum
because "the art is a snare and the sample is a snare"; by ear they do
not match. A name match proves nothing.

So the bar is NOT "the sample is exactly the instrument drawn". It is
**"a child would not hear a disconnect between what they see and what
they hear."** A plausible adjacent instrument is fine (an upright drawn,
a grand recorded). An obvious timbral mismatch is not. Judge every new
instrument by this, not by taxonomy, and let Cooper listen to anything
borderline.

Characters' props are not playable instruments: Piper plays a recorder,
and that is her, not the flute's art.

### The audit, 2026-11-20

| Instrument | Art shows | Samples are (per provenance) | Match? |
|---|---|---|---|
| bells | handbells | InspectorJ "Hand Bells, Singles" | Yes (Cooper, by ear) |
| xylophone | xylophone | Iowa xylophone, rosewood mallet | Yes (Cooper, by ear: bright, not a marimba) |
| flute | keyed concert flute (new art) | Philharmonia flute | Yes, since the new art |
| cello | cello | Philharmonia cello, arco | Yes |
| violin | violin | Philharmonia violin, arco | Yes |
| oboe | oboe | Philharmonia oboe | Yes |
| trumpet | trumpet | Philharmonia trumpet | Yes |
| tuba | tuba | Philharmonia tuba | Yes |
| piano | upright piano | Iowa piano (Iowa's catalogue: a grand; our record does not say) | ⚠️ BORDERLINE: ticked on the name first. A grand is fuller and brighter than an upright's boxier tone; Cooper to listen |
| guitar | acoustic guitar | Philharmonia guitar (Philharmonia's is a classical, nylon-string guitar; our record does not say) | ⚠️ BORDERLINE: nylon is softer and rounder than the steel-string guitar most children picture; Cooper to listen |
| drum | rope-tension snare drum | Philharmonia snare drum with snares | ✅ YES, confirmed 2026-11-20 by a musician Cooper consulted, by ear. (It was questioned on measured brightness; that conclusion was wrong. Do not reopen it on a number.) The tom is now its own instrument (below) |
| tom-tom (new 2026-11-20) | concert tom on legs, chrome lugs, no snare; three variants and a card pair | Philharmonia tom-tom, struck once | Yes: drawn for this sample |
| electric guitar (cards only) | solid-body electric | NONE | ⚠️ NO. Trello 228 |

## The playground's seven clips (`assets/audio/playground/`)

All seven are bounces from Logic Pro 11.2.2 (each file's ID3 tag), added
by Cooper in f9f4a05 (2026-04-19) and 0d56e2c (2026-04-27).

- **The three electric guitar clips (`guitar1-3.mp3`): ORIGINAL
  RECORDINGS, made for this app by Cooper's husband, and owned outright.**
  The cleanest provenance in the project: no third-party licence at all.
  Credit him by name on the credits screen if he wishes.
- `drums.mp3`, `piano.mp3`, `trumpet.mp3`, `violin.mp3`: source not yet
  stated. Logic Pro bounces, like the 24 percussion .aif files, so the same
  open question applies (Apple's Logic content terms) unless they are his
  recordings too.

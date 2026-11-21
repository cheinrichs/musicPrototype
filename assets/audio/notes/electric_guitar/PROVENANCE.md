# Electric guitar note samples — provenance (Trello 228)

✅ **APPROVED BY EAR** (Cooper, 2026-11-20, hearing E2, C4, A4 and C6:
"those electric guitars sound good to me").

✅ **IN USE AS A TRIAL INSTRUMENT** (2026-11-20): `HighLowInstrument.electricGuitar`,
dev profile only (the dev gate's "Trials" switch), with Cooper's
three-variant sheet `electricguitar_x3.png`. The folder is registered in
`pubspec.yaml`. Loud or Quiet plays D♯4; clipping room +1.0 dB; median
ring 1580 ms (one strike in the intro).

## Source and licence

- **Library:** Karoryfer Samples, "Emilyguitar" — an Epiphone Emily the
  Strange, a solid-body electric with humbuckers, played and mapped by
  D. Smolken. GitHub: `sfzinstruments/karoryfer.emilyguitar`.
- **Release actually downloaded:** tag **`v1.001`** ("Emilyguitar
  v1.001", published 2022-11-04), asset `Karoryfer.Emilyguitar.v1.001.zip`,
  103,484,350 bytes, sha256
  `ffef3b28972763820bee73660a25cf47ea6e13b184342fd5d325a5631598cacb`.
- **Licence: CC0 1.0 Universal**, taken from the `LICENSE` file inside
  that release (copied beside these files as `LICENSE.txt`). Public
  domain: commercial use, no attribution required. The release's readme
  adds "Royalty-free for all commercial and non-commercial use." Note
  that Karoryfer's own product pages still show an older CC BY notice in
  places; the licence of record is the one in the release.
- **Recording (readme):** standard tuning, d'Addario Chromes flatwound
  strings, recorded direct with both pickups and all knobs on ten. Clean,
  no amp: dry and a little dark.

## Does it match the art?

The cards show two solid-body electrics (a red Strat style, a blue Les
Paul style). Emily is a solid body with humbuckers, like the Les Paul
card — not a hollowbody or archtop — so it reads against both cards. Its
clean, direct, amp-less tone was approved by Cooper's ear (above), under
the art-versus-sound rule in docs/product/SAMPLE_PROVENANCE.md.

## ⚠️ THE NOTE SET IS SPARSE — select from these, never assume chromatic

| | |
|---|---|
| Spacing | every THREE semitones (a minor third) |
| Range | E2 to D6 |
| The 17 notes | E2, F♯2, A2, C3, D♯3, F♯3, A3, C4, D♯4, F♯4, A4, C5, D♯5, F♯5, A5, C6, D6 |
| MIDI | 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 69, 72, 75, 78, 81, 84, 86 |

(F♯2 is two semitones above E2 and D6 two above C6: the release's own
ends.) Anything choosing notes or intervals for this instrument — a High
vs Low pair, a Matching Grove melody, a chord for Bright & Dark (card 232)
or Chord ID — must pick from the notes that EXIST. Never assume a
semitone is there; never pitch-shift one in. When this becomes a
`HighLowInstrument`, declare exactly these notes (every other MIDI in
40-86 as missing), so `availableMidis` is this list.

## Onsets aligned at import, for chords (2026-11-20)

Every file was cut 10 ms before its first sound when it was made, so all
17 start together. Measured (`tool/measure_note_onset.py`): first sound
at 10-20 ms and the note itself (t6) at 30 ms in every file — the same
common mark the rest of the library now shares. ONSETS, not peaks.
Nothing further to trim.

## Art: its own three-variant sheet (2026-11-20)

`electricguitar_x3.png`: red Strat, blue Les Paul (the centre), sunburst
Tele — three different solid-body MODELS, the first sheet whose variants
are different shapes rather than one shape recoloured. All solid bodies,
like Emily. ⚠️ A DISTINCT INSTRUMENT from the acoustic `guitar`
(`guitar_x3.png`, Philharmonia): never a variant of "guitar", never mixed
with it in a Matching Grove trial.

## The notes: SPARSE, and that is fine

Karoryfer sampled every THREE semitones (E, F♯, A, C, E♭…). The games
pick from each instrument's own real notes by gap and never need the
semitones between (docs/product/SAMPLE_PROVENANCE.md, card 228), so
**nothing is pitch-shifted**: every file is a real recording.

17 notes, E2 to D6: `e2 f_sharp_2 a2 c3 d_sharp_3 f_sharp_3 a3 c4
d_sharp_4 f_sharp_4 a4 c5 d_sharp_5 f_sharp_5 a5 c6 d6`. The release's
D♭2 (the low string tuned down, a different sound) was not taken.

## How they were made (2026-11-20)

- Source files: `notes/<pitch>_mf_rr1.wav` — the mezzo-forte layer, first
  round robin. 24-bit mono WAV, ~4.2 s each.
- `tool/split_note_runs.py --count 1`: cut from the first sound (they
  already start at 0 ms), 1.645625 s, 5 ms fade-in, 80 ms fade-out, mono
  44.1 kHz, 64 kbps CBR mp3. Named by the release's label.
- **Pitch verified:** every file is its labelled pitch, within 21 cents
  (`tool/measure_note_pitch.py --verify-labels` for C4–A5; autocorrelation
  plus spectrum for the rest). Unlike our old guitar files, Karoryfer's
  labels are the real sounding pitch.
- **Audible on a phone:** every note keeps at least 55% of its energy
  above 200 Hz (`tool/measure_speaker_audibility.py`).
- **Loudness:** `tool/normalize_loudness.py --apply --target -18`. Eight
  reach −18 LUFS. Nine are headroom-limited by their sharp direct-pickup
  transients: a3 −19.5, c4 −19.7, f♯4 −19.7, d6 −20.0, d♯3 −21.4, e2 −21.6,
  f♯2 −21.9, c3 −22.5, f♯3 −22.7 LUFS (the lowest about 4.7 dB under).
  Reported, not compressed.

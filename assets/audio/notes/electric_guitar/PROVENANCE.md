# Electric guitar note samples — provenance (Trello 228)

⚠️ **NOT YET USED, AND NOT SHIPPED** (2026-11-20). This folder is NOT
registered in `pubspec.yaml`, so it does not ship. It was pulled because
the Matching Grove has electric guitar cards (`cards_electricguitar_pair.png`)
and no electric guitar sound. It will be wired when a game uses it. To
play in High vs Low or Loud or Quiet it would also need Cooper's
three-variant electric guitar art, which does not exist yet.

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
card. A clean, direct, amp-less tone, so it sounds plainer than the art
might suggest: **Cooper to listen** (the art-versus-sound rule in
docs/product/SAMPLE_PROVENANCE.md).

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

# Attribution (Trello card TY1KDwiB, 2026-09)

⚠️ **ATTRIBUTION: REQUIRED.** CC BY 4.0. The credit for these handbells on
the app's credits screen (lib/app/credits_data.dart, marked
`attributionRequired: true`) MUST stay; removing it breaches the licence.
This is the only REQUIRED credit among the note libraries. Philharmonia
and Iowa (see each instrument's PROVENANCE.md) are courtesies.

The 13 files in this directory are derived from InspectorJ's "Hand Bells,
Singles" pack on Freesound, licensed **CC BY 4.0**
(https://creativecommons.org/licenses/by/4.0/) — attribution required,
commercial use and modification both permitted. Not CC0, and not
CC BY-NC, so this is usable on the App Store but the attribution below
is a real obligation, not a courtesy.

Per-sound licensing was confirmed from the pack's own bundled
`_readme_and_license.txt` (every one of the 13 sounds in the pack is
individually licensed CC BY 4.0 — Freesound licenses per-sound, not
per-pack, so this was checked file-by-file rather than assumed from the
pack level).

**Creator:** InspectorJ — https://freesound.org/people/InspectorJ/
**Pack:** "Hand Bells, Singles" — https://freesound.org/people/InspectorJ/packs/19255/
**License:** CC BY 4.0 — https://creativecommons.org/licenses/by/4.0/
**Modified:** Yes, all 13 — downmixed to mono (the source files are
stereo), trimmed to ~1.8s with a short fade-out (the sources ring for
7-18s; the note library's convention is a short, clean sample), and
gain-normalized to this library's standing -18 LUFS target. Encoded to
mono/44.1kHz/64kbps CBR mp3, matching every other instrument here.

| Asset (this repo)  | Freesound source                                                            | Original title |
|---------------------|------------------------------------------------------------------------------|-----------------|
| `c6.mp3`            | https://freesound.org/s/339815/ | Hand Bells, Low C, Single |
| `c_sharp_6.mp3`     | https://freesound.org/s/339808/ | Hand Bells, C#/Db, Single |
| `d6.mp3`            | https://freesound.org/s/339813/ | Hand Bells, D, Single |
| `d_sharp_6.mp3`     | https://freesound.org/s/339814/ | Hand Bells, D#/Eb, Single |
| `e6.mp3`            | https://freesound.org/s/339812/ | Hand Bells, E, Single |
| `f6.mp3`            | https://freesound.org/s/339816/ | Hand Bells, F, Single |
| `f_sharp_6.mp3`     | https://freesound.org/s/339817/ | Hand Bells, F#/Gb, Single |
| `g6.mp3`            | https://freesound.org/s/339818/ | Hand Bells, G, Single |
| `g_sharp_6.mp3`     | https://freesound.org/s/339819/ | Hand Bells, G#/Ab, Single |
| `a6.mp3`            | https://freesound.org/s/339810/ | Hand Bells, A, Single |
| `a_sharp_6.mp3`     | https://freesound.org/s/339811/ | Hand Bells, A#/Bb, Single |
| `b6.mp3`            | https://freesound.org/s/339809/ | Hand Bells, B, Single |
| `c7.mp3`            | https://freesound.org/s/339820/ | Hand Bells, High C, Single |

**Asset names are the real measured pitch, not the source filename's
implied one** — see the class doc on `HighLowInstrument.bells` and the
commit that introduced this set for the full methodology. The source
pack's own filenames (`low-c`, `cdb`, `d`, `deb`, ...) turned out to
imply a scale a full two octaves below where these bells actually ring
(measured C6-C7, not C4-C5) — a reminder that this is a field recording
of a small consumer toy set (the pack's own readme links to "Percussion
Workshop CB8" on Amazon), not a curated, verified sample library like
Philharmonia's, so labels here were trusted even less than usual.

**`c7.mp3`'s source has a very brief clip** at the exact instant of the
strike (~0.5ms, 21 samples, at the int16 rail) — investigated rather
than dropped on sight: measuring past that instant shows a clean,
correctly-tuned tone (2098Hz measured vs. real C7 at 2093.00Hz, +4
cents), and the clip itself is far shorter than the strike transient a
listener would perceive as the bell's natural attack anyway. Kept and
shipped; noted here for the record rather than treated as fully
pristine source audio.

## Lead-in trimmed, 2026-11-15 (Cooper approved; build after 137)

**Modified again: all 13.** Each file began with a near-silent pad
(-60 to -70 dB under the strike) of 150-440 ms before the bell is struck,
which a child hears as lag after a tap. The pad was cut with
`tool/trim_note_start.py`: the file now starts 10 ms before the strike,
with a 5 ms fade-in, silence added at the end to keep the length, and
the level the re-encode loses made up so each note plays as loud as it
did (within ±0.3 dB). The strike and everything after it are untouched.

**Untrimmed originals kept** at `docs/audio_originals/notes/bells/`
(not shipped). To undo a file, copy it back over this one.

| File | Cut from start (ms) |
|---|---|
| `c6.mp3` | 154.8 |
| `c_sharp_6.mp3` | 352.9 |
| `d6.mp3` | 226.7 |
| `d_sharp_6.mp3` | 301.0 |
| `e6.mp3` | 335.4 |
| `f6.mp3` | 311.6 |
| `f_sharp_6.mp3` | 264.0 |
| `g6.mp3` | 435.6 |
| `g_sharp_6.mp3` | 325.7 |
| `a6.mp3` | 308.8 |
| `a_sharp_6.mp3` | 372.1 |
| `b6.mp3` | 263.9 |
| `c7.mp3` | 294.4 |

Side effect: F♯6 (the note Loud or Quiet plays) now peaks 0.56 dB higher
(true peak -7.4, was -7.9), so its clipping room in
`DynamicLadder.measuredHeadroomDb` went from 6.5 to 6.0 dB.

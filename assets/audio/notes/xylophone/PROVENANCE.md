# Xylophone note samples — provenance

⚠️ **ATTRIBUTION: COURTESY, NOT REQUIRED.** This licence does not require
credit. The app credits the source anyway (lib/app/credits_data.dart), and
that line could be removed without breaching anything. Contrast the bells
(assets/audio/notes/bells/ATTRIBUTION.md): CC BY 4.0, where credit IS
REQUIRED.

**Source:** University of Iowa Electronic Music Studios, Musical
Instrument Samples: Xylophone (Andrew Thierauf, 2013, anechoic chamber) —
https://theremin.music.uiowa.edu/MISxylophone.html

**Licence (as recorded in the credits screen):** freely available since
1997, for any project, without restriction. The same source and terms as
the piano. Not a Creative Commons licence.

## ⚠️ A TRIAL INSTRUMENT: dev profile only

It plays only on the dev profile, behind the dev gate's "Xylophone"
switch (`HighLowInstrument.isTrial`, `inPlay`), so Cooper can judge its
loudness by ear in situ against the real instruments. A child never meets
it.

Its art is Cooper's UI-Kit sheet
(`SongStone-UI-Kit/Assets/Cast/Instruments/Xylophone.png`, light and dark
wood), copied byte-for-byte and sliced in code. An earlier version of this
file said it had "no sprite art": that was WRONG. The art existed in the UI
Kit and had simply never been imported.

**Still open before a child plays it: its loudness is uneven, lowest at the
bottom.** A struck bar is nearly all attack: its true peak hits the
−1 dBTP ceiling long before its loudness reaches −18 LUFS. Most notes sit
between −19 and −26 LUFS, but F4–A♯4 sit between −24 and −33 (marked ⚠️
below). In a PITCH game, a quieter low end is a cue: "the quiet one is the
low one". The fix is Cooper's call after the trial: a gentle peak limiter
(it would soften the mallet's attack), or leaving the bottom notes out.

Its Loud or Quiet headroom is also only **+0.5 dB** (on D♯6, the middle
of its range), since its peaks already sit at the ceiling. It could play
only the levels whose loud note is at or below full volume.

## Choosing the mallet: by measurement, not taste

Rosewood and hard rubber were both pulled (C5–B5 and C7–B7, mezzo-forte)
and measured for PITCH CLARITY: the attack's click is noise, not tone.
Both read 24/24 notes correctly, with the same tiny error (10.1 c and
10.2 c on average). Dominance, how far the pitch peak stands above any
competitor (1.0 = none):

| Mallet | Mean | Worst note |
|---|---|---|
| Rosewood | 0.889 | 0.57 (G♯7) |
| Hard rubber | 0.896 | 0.40 (C5) |

A statistical tie. Rosewood was kept on its weaker worst note; it is
also the sound a child recognises as a xylophone.

## Measuring it

The tool's defaults could not read the top octave. Autocorrelation's
whole-sample lags are too coarse at 4 kHz, and bells' 1 s spectral window
ends mostly in room rumble. So `tool/measure_note_pitch.py` now measures
the xylophone by a spectral peak in a 0.25 s window just after the strike,
above 150 Hz, with a 4400 Hz ceiling (`SPECTRAL_PEAK_SETTINGS`,
`INSTRUMENT_MAX_FREQ_HZ`). `--verify-chromatic` passes on all 44 files.

Every note reads 6 to 19 cents sharp of its label. That is the
instrument's own tuning, consistent across the range.

## History

2026-11-14: rosewood mallet, mezzo-forte, normal strokes. Five source
files (F4B4, C5B5, C6B6, C7B7, C8), each holding a run of notes, were cut
into single notes by `tool/split_note_runs.py`: at its onset, 1.645625 s
long, faded, mono 44.1 kHz, 64 kbps mp3. Raw AIFFs were kept outside the
repo. Loudness was normalised to −18 LUFS with a −1 dBTP true-peak
ceiling (tool/normalize_loudness.py); almost every note hit the ceiling
first. Speaker audibility: 98.7% of the energy is above 200 Hz on average
(lowest 81.5%).

## Files (44): F4–C8, fully chromatic

| File | Real pitch | Measured | LUFS |
|---|---|---|---|
| `f4.mp3` | F4 | +7 c | -24.9 ⚠️ |
| `f_sharp_4.mp3` | F♯4 | +7 c | -32.7 ⚠️ |
| `g4.mp3` | G4 | +10 c | -30.1 ⚠️ |
| `g_sharp_4.mp3` | G♯4 | +8 c | -25.2 ⚠️ |
| `a4.mp3` | A4 | +8 c | -26.3 ⚠️ |
| `a_sharp_4.mp3` | A♯4 | +8 c | -24.1 ⚠️ |
| `b4.mp3` | B4 | +10 c | -21.3 |
| `c5.mp3` | C5 | +8 c | -23.3 |
| `c_sharp_5.mp3` | C♯5 | +13 c | -21.1 |
| `d5.mp3` | D5 | +10 c | -20.7 |
| `d_sharp_5.mp3` | D♯5 | +12 c | -19.3 |
| `e5.mp3` | E5 | +8 c | -23.1 |
| `f5.mp3` | F5 | +8 c | -21.0 |
| `f_sharp_5.mp3` | F♯5 | +10 c | -21.8 |
| `g5.mp3` | G5 | +12 c | -21.6 |
| `g_sharp_5.mp3` | G♯5 | +12 c | -18.9 |
| `a5.mp3` | A5 | +8 c | -21.0 |
| `a_sharp_5.mp3` | A♯5 | +12 c | -24.3 ⚠️ |
| `b5.mp3` | B5 | +11 c | -21.7 |
| `c6.mp3` | C6 | +12 c | -21.5 |
| `c_sharp_6.mp3` | C♯6 | +12 c | -23.8 |
| `d6.mp3` | D6 | +9 c | -20.1 |
| `d_sharp_6.mp3` | D♯6 | +9 c | -23.3 |
| `e6.mp3` | E6 | +8 c | -22.5 |
| `f6.mp3` | F6 | +10 c | -25.9 ⚠️ |
| `f_sharp_6.mp3` | F♯6 | +13 c | -19.6 |
| `g6.mp3` | G6 | +14 c | -19.2 |
| `g_sharp_6.mp3` | G♯6 | +19 c | -24.1 ⚠️ |
| `a6.mp3` | A6 | +10 c | -21.3 |
| `a_sharp_6.mp3` | A♯6 | +11 c | -19.0 |
| `b6.mp3` | B6 | +9 c | -20.8 |
| `c7.mp3` | C7 | +10 c | -22.0 |
| `c_sharp_7.mp3` | C♯7 | +11 c | -24.3 ⚠️ |
| `d7.mp3` | D7 | +7 c | -23.6 |
| `d_sharp_7.mp3` | D♯7 | +6 c | -19.1 |
| `e7.mp3` | E7 | +7 c | -19.8 |
| `f7.mp3` | F7 | +10 c | -18.1 |
| `f_sharp_7.mp3` | F♯7 | +10 c | -18.3 |
| `g7.mp3` | G7 | +7 c | -20.8 |
| `g_sharp_7.mp3` | G♯7 | +11 c | -21.1 |
| `a7.mp3` | A7 | +12 c | -19.2 |
| `a_sharp_7.mp3` | A♯7 | +14 c | -20.5 |
| `b7.mp3` | B7 | +17 c | -19.4 |
| `c8.mp3` | C8 | +19 c | -19.4 |

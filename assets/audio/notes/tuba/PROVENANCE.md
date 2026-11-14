# Tuba note samples — provenance

⚠️ **ATTRIBUTION: COURTESY, NOT REQUIRED.** This licence does not require
credit. The app credits the source anyway (lib/app/credits_data.dart), and
that line could be removed without breaching anything. Contrast the bells
(assets/audio/notes/bells/ATTRIBUTION.md): CC BY 4.0, where credit IS
REQUIRED.

**Source:** Philharmonia Orchestra sound samples, Brass pack —
https://philharmonia.co.uk/audio-sound-samples

**Licence (Philharmonia's own words, checked by Cooper 2026-11-14):**

> "You are free to use these samples as you wish, including releasing them
> as part of a commercial work. The only restriction is that they must not
> be sold or made available 'as is' (i.e. as samples or as a sampler
> instrument)."

Embedding them in this app is the permitted commercial use. Republishing
them as a sample pack would not be. **NOT a Creative Commons licence:**
commit e5730e3's message calls Philharmonia "CC-licensed". That is WRONG
(it came from a third-party GitHub mirror). The credits screen's "free to
use for any purpose, including commercially" is correct.

## History

Added in baf0768 (card 55). Real pitch C2–B3, two octaves below the old logical slots; the files are named by real pitch. Pianissimo, except C♯3 (piano take). Only G♯3–B3 are used: lower notes are inaudible on a phone speaker (f92f539). Every file was then trimmed or padded to 1.645625 s, converted to
mono 44.1 kHz and encoded to 64 kbps mp3, processed outside the repo, with
no raw archives committed. Loudness was later re-normalised to about
−18 LUFS, with a −1 dBTP true-peak ceiling (4166189,
tool/normalize_loudness.py). Pitch was measured by tool/measure_note_pitch.py.

The original source file name of each note was NOT recorded at import.
Only the take choices above were.

## Files (24)

| File | Real pitch | Used by the app |
|---|---|---|
| `c2.mp3` | C2 | no — outside the declared range |
| `c_sharp_2.mp3` | C♯2 | no — outside the declared range |
| `d2.mp3` | D2 | no — outside the declared range |
| `d_sharp_2.mp3` | D♯2 | no — outside the declared range |
| `e2.mp3` | E2 | no — outside the declared range |
| `f2.mp3` | F2 | no — outside the declared range |
| `f_sharp_2.mp3` | F♯2 | no — outside the declared range |
| `g2.mp3` | G2 | no — outside the declared range |
| `g_sharp_2.mp3` | G♯2 | no — outside the declared range |
| `a2.mp3` | A2 | no — outside the declared range |
| `a_sharp_2.mp3` | A♯2 | no — outside the declared range |
| `b2.mp3` | B2 | no — outside the declared range |
| `c3.mp3` | C3 | no — outside the declared range |
| `c_sharp_3.mp3` | C♯3 | no — outside the declared range |
| `d3.mp3` | D3 | no — outside the declared range |
| `d_sharp_3.mp3` | D♯3 | no — outside the declared range |
| `e3.mp3` | E3 | no — outside the declared range |
| `f3.mp3` | F3 | no — outside the declared range |
| `f_sharp_3.mp3` | F♯3 | no — outside the declared range |
| `g3.mp3` | G3 | no — outside the declared range |
| `g_sharp_3.mp3` | G♯3 | yes |
| `a3.mp3` | A3 | yes |
| `a_sharp_3.mp3` | A♯3 | yes |
| `b3.mp3` | B3 | yes |

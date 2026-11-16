# Violin note samples — provenance

⚠️ **ATTRIBUTION: COURTESY, NOT REQUIRED.** This licence does not require
credit. The app credits the source anyway (lib/app/credits_data.dart), and
that line could be removed without breaching anything. Contrast the bells
(assets/audio/notes/bells/ATTRIBUTION.md): CC BY 4.0, where credit IS
REQUIRED.

**Source:** Philharmonia Orchestra sound samples, String pack —
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

Added in bdab53d (card 44), C4–B5. Extended to C7 on 2026-11-14 (card 148). Our files match the 1 s mezzo-forte arco take (B5 0.998). The new C6–C7 use it too, except F6, A♯6, B6 and C7, which use the 1 s forte take (no mezzo-forte exists for them). Known, older measurement issue: tool/measure_note_pitch.py reads c4.mp3 an octave high (failure mode 2 in its docstring); this predates the extension. Every file was then trimmed or padded to 1.645625 s, converted to
mono 44.1 kHz and encoded to 64 kbps mp3, processed outside the repo, with
no raw archives committed. Loudness was later re-normalised to about
−18 LUFS, with a −1 dBTP true-peak ceiling (4166189,
tool/normalize_loudness.py). Pitch was measured by tool/measure_note_pitch.py.

The original source file name of each note was NOT recorded at import.
Only the take choices above were.

## Files (37)

| File | Real pitch | Used by the app |
|---|---|---|
| `c4.mp3` | C4 | yes |
| `c_sharp_4.mp3` | C♯4 | yes |
| `d4.mp3` | D4 | yes |
| `d_sharp_4.mp3` | D♯4 | yes |
| `e4.mp3` | E4 | yes |
| `f4.mp3` | F4 | yes |
| `f_sharp_4.mp3` | F♯4 | yes |
| `g4.mp3` | G4 | yes |
| `g_sharp_4.mp3` | G♯4 | yes |
| `a4.mp3` | A4 | yes |
| `a_sharp_4.mp3` | A♯4 | yes |
| `b4.mp3` | B4 | yes |
| `c5.mp3` | C5 | yes |
| `c_sharp_5.mp3` | C♯5 | yes |
| `d5.mp3` | D5 | yes |
| `d_sharp_5.mp3` | D♯5 | yes |
| `e5.mp3` | E5 | yes |
| `f5.mp3` | F5 | yes |
| `f_sharp_5.mp3` | F♯5 | yes |
| `g5.mp3` | G5 | yes |
| `g_sharp_5.mp3` | G♯5 | yes |
| `a5.mp3` | A5 | yes |
| `a_sharp_5.mp3` | A♯5 | yes |
| `b5.mp3` | B5 | yes |
| `c6.mp3` | C6 | yes |
| `c_sharp_6.mp3` | C♯6 | yes |
| `d6.mp3` | D6 | yes |
| `d_sharp_6.mp3` | D♯6 | yes |
| `e6.mp3` | E6 | yes |
| `f6.mp3` | F6 | yes |
| `f_sharp_6.mp3` | F♯6 | yes |
| `g6.mp3` | G6 | yes |
| `g_sharp_6.mp3` | G♯6 | yes |
| `a6.mp3` | A6 | yes |
| `a_sharp_6.mp3` | A♯6 | yes |
| `b6.mp3` | B6 | yes |
| `c7.mp3` | C7 | yes |

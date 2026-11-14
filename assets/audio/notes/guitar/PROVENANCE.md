# Guitar note samples — provenance

⚠️ **ATTRIBUTION: COURTESY, NOT REQUIRED.** This licence does not require
credit. The app credits the source anyway (lib/app/credits_data.dart), and
that line could be removed without breaching anything. Contrast the bells
(assets/audio/notes/bells/ATTRIBUTION.md): CC BY 4.0, where credit IS
REQUIRED.

**Source:** Philharmonia Orchestra sound samples, guitar samples —
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

Added in bdab53d (card 44). The 2026-09 pitch audit (5d0e267) found the real pitch an octave BELOW the original file names: files renamed to their real pitch, four removed. F♯3 and G♯3 restored in d362df3. A3 and A♯4 are gone for good (A3 was mic clicks, A♯4 an incongruous pluck). Every file was then trimmed or padded to 1.645625 s, converted to
mono 44.1 kHz and encoded to 64 kbps mp3, processed outside the repo, with
no raw archives committed. Loudness was later re-normalised to about
−18 LUFS, with a −1 dBTP true-peak ceiling (4166189,
tool/normalize_loudness.py). Pitch was measured by tool/measure_note_pitch.py.

The original source file name of each note was NOT recorded at import.
Only the take choices above were.

## Files (22)

| File | Real pitch | Used by the app |
|---|---|---|
| `c3.mp3` | C3 | yes |
| `c_sharp_3.mp3` | C♯3 | yes |
| `d3.mp3` | D3 | yes |
| `d_sharp_3.mp3` | D♯3 | yes |
| `e3.mp3` | E3 | yes |
| `f3.mp3` | F3 | yes |
| `f_sharp_3.mp3` | F♯3 | yes |
| `g3.mp3` | G3 | yes |
| `g_sharp_3.mp3` | G♯3 | yes |
| `a_sharp_3.mp3` | A♯3 | yes |
| `b3.mp3` | B3 | yes |
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
| `b4.mp3` | B4 | yes |

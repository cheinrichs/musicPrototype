# Trumpet note samples — provenance

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

Added in e5730e3 (card 53). Mostly the 1.5 s pianissimo take. A5 used the forte take and F♯5 a long "piano" take trimmed, as no pianissimo existed. Every file was then trimmed or padded to 1.645625 s, converted to
mono 44.1 kHz and encoded to 64 kbps mp3, processed outside the repo, with
no raw archives committed. Loudness was later re-normalised to about
−18 LUFS, with a −1 dBTP true-peak ceiling (4166189,
tool/normalize_loudness.py). Pitch was measured by tool/measure_note_pitch.py.

The original source file name of each note was NOT recorded at import.
Only the take choices above were.

## Files (24)

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

## Leading silence trimmed, 2026-11-20 (for chords)

Measured separately for every note: the silence before the first sound,
and the attack after it. The trumpet's 220 ms spread in start times was
SILENCE, not attack, and almost all of it one file: `a5.mp3` (the forte
take; no pianissimo exists) sat silent for 270 ms, the rest for 50-110
ms. So this was group A work, not the group C attack hold.

Cut with `tool/trim_note_start.py --to-first-sound`, which cuts only
before the first sound (40 dB below the note's own peak) and NEVER into
the attack. Each file now starts 10 ms before its sound begins, with a
5 ms fade-in, silence added at the end to keep the length, and the level
made up to the original's (within 0.04 dB). After: every note's first
sound is within 20-40 ms of its file's start.

⚠️ **The attacks are untouched, and one is different: for Cooper to weigh
now that chords are on the table.** The pianissimo notes swell for
180-260 ms to full level; that IS the instrument and stays. But `a5.mp3`
is the forte take and reaches full level in 10 ms. In a trumpet chord
containing A5, the A5 would punch in about a quarter-second ahead of the
others' full level. It starts with them; it just is not the same kind of
note. Options: accept it, keep A5 out of chords, or find a pianissimo A5
elsewhere (Philharmonia has none).

**Untrimmed originals kept** at `docs/audio_originals/notes/trumpet/`
(not shipped). To undo a file, copy it back over this one.

| File | Cut from start (ms) |
|---|---|
| `a4.mp3` | 80.0 |
| `a5.mp3` | 260.0 |
| `a_sharp_4.mp3` | 40.0 |
| `a_sharp_5.mp3` | 40.0 |
| `b4.mp3` | 100.0 |
| `b5.mp3` | 40.0 |
| `c4.mp3` | 40.0 |
| `c5.mp3` | 40.0 |
| `c_sharp_4.mp3` | 60.0 |
| `c_sharp_5.mp3` | 40.0 |
| `d4.mp3` | 50.0 |
| `d5.mp3` | 40.0 |
| `d_sharp_4.mp3` | 40.0 |
| `d_sharp_5.mp3` | 60.0 |
| `e4.mp3` | 40.0 |
| `e5.mp3` | 40.0 |
| `f4.mp3` | 40.0 |
| `f5.mp3` | 40.0 |
| `f_sharp_4.mp3` | 40.0 |
| `f_sharp_5.mp3` | 40.0 |
| `g4.mp3` | 50.0 |
| `g5.mp3` | 40.0 |
| `g_sharp_4.mp3` | 40.0 |
| `g_sharp_5.mp3` | 40.0 |

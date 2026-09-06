# Voice lines (Trello card 93)

Recordings for `VoiceLine` (see `lib/audio/voice_line.dart`) go here, one
`.mp3` per enum value, named after it: `piperSaysLow.mp3`,
`piperSaysLowSecond.mp3`, `clefSaysHigh.mp3`, `clefSaysHighSecond.mp3`,
`listenForHigh.mp3`, `putMeOnHigh.mp3`, `putMeOnLow.mp3`,
`tryAgainClef.mp3`, `tryAgainPiper.mp3`.

`listenForLow.mp3` is deliberately absent — no recording exists yet for
Piper's "listen for the low one" (Clef's `listenForHigh` equivalent).
`AudioController.playVoiceLine` silently no-ops on the missing asset and
the stage falls back to `VoiceLine.captionText` on screen, same as any
other missing line — don't fill this gap with a placeholder/stand-in
take.

Re-recorded 2026-09 (nine files, `tool/build_voice_lines.py`) from 24kHz
mono WAVs to this project's standard mono/44.1kHz/64kbps CBR mp3, gain-
normalized (never pitch-shifted — Clef and Piper's relative pitch is
deliberate character design) to their own target, separate from the note
library and derived from the data rather than picked upfront: an initial
attempt at -14.0 LUFS (chosen only to sit above the notes' -18.0) left 8
of 9 files headroom-limited and *widened* the spread instead of closing
it — a target most files can't reach isn't a target. Re-derived by
forcing every file to its true post-encode headroom ceiling first, then
targeting the lowest of those ceilings among files with no recording
artifact (see next paragraph) — landed on -18.6 LUFS, which lets 8 of 9
files land within 0.12 LU of each other (essentially uniform). Ended up
close to, and just under, the notes' -18.0 rather than above it —
correct per Cooper: consistency between the nine lines matters more than
the voice-vs-notes offset, which if it matters can be restored later with
a uniform playback-time gain across the whole voice set rather than
sacrificed here.

The ninth file, `clefSaysHighSecond.mp3`, sits 2.6+ LU quieter than the
other eight and is *not* a normalization shortfall to chase further: its
source recording has an isolated ~20ms transient spike around t=1.34s
(peak sample ~31300/32768, next to neighboring 20ms windows around
4000-16000) — almost certainly a plosive pop or mic click, not the
line's actual vocal level, confirmed by comparing its envelope shape
against a legitimate loud vocal onset elsewhere in the batch (a gradual
RMS build-up, not an isolated spike). That one sample caps how much gain
the whole file can safely take under a flat scalar gain. Leaving it
quieter rather than forcing it to -18.6 and risking that spike clipping;
a surgical de-click/limiter on just that moment could let it join the
rest, but wasn't applied here without asking first — flag to Cooper.

True peak is held to ≤-1dBTP no matter what for every file, verified
against the actual *encoded* mp3 (which can overshoot a pre-encode
estimate for speech more than it ever did for the note library — see
`tool/normalize_loudness.py`'s `process_file`, which now iterates until
the real encoded peak clears the ceiling). Processing happens in a
scratch dir outside the repo — the source WAVs are never committed, only
the final mp3s.

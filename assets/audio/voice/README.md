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
deliberate character design) to their own target separate from the note
library: -14.0 LUFS (integrated, whole-clip — unlike the note library,
voice has no decay-tail to exclude), chosen to sit comfortably above the
notes' -18.0 LUFS so a line is never buried under an instrument. Several
of Clef's lines are headroom-limited below that target by their own
transient content — true peak is held to -1 dBTP no matter what, so a
punchy take stays at its safe maximum rather than hitting target and
clipping. Processing happens in a scratch dir outside the repo — the
source WAVs are never committed, only the final mp3s.

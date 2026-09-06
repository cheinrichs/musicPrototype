# Voice lines (Trello card 93)

Recordings for `VoiceLine` (see `lib/audio/voice_line.dart`) go here, one
`.mp3` per enum value, named after it: `piperSaysLow.mp3`,
`piperSaysLowSecond.mp3`, `clefSaysHigh.mp3`, `clefSaysHighSecond.mp3`,
`listenForHigh.mp3`, `listenForLow.mp3`, `giveMeHigh.mp3`,
`giveMeLow.mp3`, `tryAgainClef.mp3`, `tryAgainPiper.mp3`. All ten now
exist. (`giveMeHigh`/`giveMeLow` were named `putMeOnHigh`/`putMeOnLow`
until the A2 drag direction reversed 2026-09 — the child now drags an
instrument to the character instead of dragging the character onto an
instrument, so "put me on the high one" read backwards; the recording
itself already said "give me the high one," so only the enum/asset names
needed to catch up. See lib/audio/voice_line.dart's doc comments.)

Nine re-recorded 2026-09 (`tool/build_voice_lines.py`) from 24kHz mono
WAVs, replacing the original placeholder takes. The tenth,
`listenForLow.mp3` (Piper's "listen for the low one," the counterpart to
Clef's `listenForHigh`), predates that batch — it wasn't part of the
nine but Cooper confirmed the existing take was already fine to use
("there's nothing wrong with the listen for the low one line ... that
line is fine for use"), so it was run through the same pipeline and
folded in rather than left as a gap or re-recorded unnecessarily. Same
24kHz source format as the rest; its measured fundamental (108Hz) sits
inside the other Piper lines' own range (106-142Hz).

**Cross-batch consistency is a standing concern, not a one-off.** Cooper
records against a free Gemini credit allowance and comes back with more
lines whenever a fresh session allows — sometimes a full batch, sometimes
one replacement line. `tool/build_voice_lines.py` supports both: point
`--uploads-dir` at a session's folder to process whatever's mapped and
present there (older mapped files simply not being in a given folder is
normal, not an error), or `--file`/`--voice-line` to drop in a single new
line directly. Either way, always check the new file's own headroom
ceiling against the standing `VOICE_TARGET_LUFS` before trusting it fits
— the script warns if a newly-processed file can't reach target, which
is the signal that a new batch needs the target re-derived rather than
just applied.

All ten files are gain-normalized together (never pitch-shifted — Clef
and Piper's relative pitch is deliberate character design) to their own
target, separate from the note library and derived from the data rather
than picked upfront: an initial attempt at -14.0 LUFS (chosen only to
sit above the notes' -18.0) left most files headroom-limited and
*widened* their spread instead of closing it — a target most files can't
reach isn't a target. Re-derived by forcing every file to its true
post-encode headroom ceiling first (run at an unreachably hot target and
read off where each one actually lands), then targeting the lowest of
those ceilings among files with no recording defect. One 2026-09 line
(`clefSaysHighSecond.mp3`) was investigated for a suspected defect — its
envelope has an unusually loud ~20ms passage that looked like an isolated
click at a coarse (20ms-window) resolution — but a finer (2ms-window)
look at the untouched 24kHz source showed a smooth build-and-decay over
that whole passage, the signature of genuine vocal emphasis, not a
click's instant discontinuity. Nothing was excluded or altered on that
basis; the line's lower ceiling (its performance is simply more dynamic
than the other eight) is real and left as recorded.

Current target: **-18.6 LUFS**, derived from the ten lines above. Nine
land within 0.12 LU of each other; `clefSaysHighSecond.mp3` sits about
2.6 LU quieter, capped by its own loud passage under a flat scalar gain
— not a shortfall to chase further without either accepting it as this
take's character or getting a re-take with less peak dynamics. This ends
up close to, and just under, the note library's -18.0 rather than above
it — correct per Cooper: consistency between the voice lines matters
more than the voice-vs-notes offset, which if it matters can be restored
later with a uniform playback-time gain across the whole voice set
rather than sacrificed here.

True peak is held to ≤-1dBTP no matter what for every file, verified
against the actual *encoded* mp3 (which can overshoot a pre-encode
estimate for speech more than it ever did for the note library — see
`tool/normalize_loudness.py`'s `process_file`, which iterates until the
real encoded peak clears the ceiling). Processing happens in a scratch
dir outside the repo — source WAVs are never committed, only the final
mp3s.

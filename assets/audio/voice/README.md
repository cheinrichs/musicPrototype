# Voice lines (Trello card 93)

Recordings for `VoiceLine` (see `lib/audio/voice_line.dart`) go here, one
`.mp3` per enum value, named after it. 23 exist as of 2026-09-07 — see
`lib/audio/voice_line.dart`'s class doc for the full list and what each
one is. (`giveMeHigh`/`giveMeLow` were named `putMeOnHigh`/`putMeOnLow`
until the A2 drag direction reversed 2026-09 — the child now drags an
instrument to the character instead of dragging the character onto an
instrument, so "put me on the high one" read backwards; the recording
itself already said "give me the high one," so only the enum/asset names
needed to catch up. See lib/audio/voice_line.dart's doc comments.)

## 2026-09-07: the 4-5 and 6-7 age bands

Seventeen new lines (Trello card "Voice clips for the next age band of
High/Low"), processed through the same `tool/build_voice_lines.py`
pipeline as the batch below. Four of them *replace* existing files
rather than adding new ones — `clefSaysHigh.mp3`, `clefSaysHighSecond.mp3`,
`piperSaysLow.mp3`, `piperSaysLowSecond.mp3` — because Cooper's script
review decided 4-5's slightly fuller wording ("That **one** sounds
high") becomes canonical for both the 2-3 and 4-5 bands, retiring the
2-3-only originals rather than keeping two near-identical recordings
live. The other thirteen are new members, several for a 6-7 band that
isn't complete yet (Clef's 6-7 A1/A2/nudge and the second half of his
A0 pair have no recording yet) and one for 8+ (a single nudge line —
see `lib/audio/voice_line.dart`'s class doc for why the rest of 8+
collapsed into 6-7).

No age-band selector exists in the app yet, so only the four repointed
A0 files are actually reachable in a real session today — the other
thirteen are real, committed, and tested (`test/audio/voice_line_test.dart`
checks every `VoiceLine` resolves to a file that exists), ready for
whenever that selector lands. Not a guess about scope: the age-band
picker is its own separate, unstarted epic (Trello card PqqgLOwF), and
this card's own description already treats "which band plays when" as
outside what it's asking for — same shape as `ConceptTier`'s three-note
tiers landing ahead of their own screen, which Cooper did confirm
explicitly for that case.

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

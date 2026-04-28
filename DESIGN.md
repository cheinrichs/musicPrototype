# Ear Training App — Design Document

This document captures the design decisions, lessons learned, and future direction
for the kids' ear training app. Written to support knowledge transfer to a Unity
port or any future rebuild.

---

## What This Is

A playful, offline-first ear training app for kids (ages ~4–8). The core philosophy
is that it should feel like a toy, not a lesson. Sessions are short (2–5 min),
feedback is fast and positive, and kids never feel like they failed.

The app is not trying to teach music theory. It's building the *listening muscles*
that make music feel intuitive — pitch awareness, timbre recognition, rhythm feel,
tonal color. The games come first; the skill labels are for parents/developers, not
kids.

---

## Design Principles

### Kids Can't Lose
There is no failure state. Wrong answers get gentle "try the next one!" feedback,
never a harsh buzzer or "game over." XP is only awarded when a session goes well
(≥4/5 correct), but the reward screen always celebrates. The skill profile showing
XP and levels is intentionally hidden from the main game flow — it's a parent/dev
view, not a kid-facing score.

### Short Sessions
5 rounds per game. Not 10, not 8 — 5. This was a deliberate correction from an
early implementation that used 10. At 5 rounds with audio playback time, a session
is about 2–3 minutes, which matches kids' attention spans and fits in a car ride or
before-bed slot.

### Fast Feedback Loop
Home → game → 5 rounds → reward screen → home. No loading screens, no menus, no
account setup. Audio plays immediately on game start.

### Audio Is the Product
The app is nothing without reliable, low-latency audio. Every design decision around
audio should optimize for: no perceivable lag between tap and sound, consistent
volume across instruments and notes, clean start/stop with no clicks or buzz.

---

## Skill System

### The 11 Skills
Defined in `lib/models/musical_skill.dart`. These map to a musical learning
progression framework:

| Skill | Emoji | Description |
|-------|-------|-------------|
| soundAwareness | 🌱 | Volume, duration, presence, attack, release |
| pitchAwareness | 🎵 | Recognize and compare pitch differences |
| contourAndShape | 🌈 | How melodies move through space over time |
| rhythmAndTiming | ⏳ | Pulse, timing, rhythmic patterns |
| anticipationAndPunctuation | 🎭 | Pauses, accents, musical endings |
| tonalContrast | 🎶 | Emotional color, tonal stability |
| soundMaking | 🎤 | Producing and shaping sound (requires mic — deferred) |
| timbreAndInstrument | 🎻 | Sound color across voices and instruments |
| guidedPlay | 🎹 | Translating listening to execution (requires MIDI — deferred) |
| harmonyAndChordFeel | 🎼 | How notes combine to create emotional color |
| pitchNaming | 🎵 | Connecting pitch to solfege/note names |

### XP & Levels
- XP range: 0–1000 per skill
- 5 levels total
- Thresholds: `[0, 1, 100, 300, 600, 1000]`
  - The `1` threshold means any XP at all immediately shows bar progress,
    avoiding the "just leveled up but bar looks empty" visual bug that existed
    with the original thresholds.
- XP is only awarded when `correctCount >= 4` in a 5-round session
- XP per session: `correctCount * 10` (max 50 per session)
- Persisted via SharedPreferences

---

## Games

### Current Games (9 total)

| Game | Route | Skill | Mechanic |
|------|-------|-------|----------|
| High vs Low | `/high-low` | pitchAwareness | Two notes — is the second higher or lower? |
| Same or Different | `/same-different` | soundAwareness | Two melodies — same or different? |
| Match the Note | `/match-note` | pitchAwareness | Hear a note, pick which of 3 choices matches |
| Scale Direction | `/scale-direction` | contourAndShape | 3-note run — going up or down? |
| Intervals | `/interval-id` | pitchAwareness | Identify interval: m3, M3, P5, or Octave |
| Chord ID | `/chord-id` | harmonyAndChordFeel | Major (happy) or minor (sad)? |
| Which Instrument? | `/timbre-id` | timbreAndInstrument | Hear a clip, pick guitar/drums/trumpet/violin |
| Same Beat? | `/rhythm-id` | rhythmAndTiming | Two rhythmic patterns — same or different? |
| Name That Note | `/pitch-name` | pitchNaming | Hear a C major scale note, pick solfege (Do/Re/Mi…) |

### Game Architecture Pattern
All games follow the same structure:
- `GameState extends ChangeNotifier` — all logic, audio calls, and state transitions
- `GameScreen extends StatefulWidget` — subscribes to state, handles navigation
- On complete: award XP → navigate to `/reward` with `correctCount`, `totalCount`,
  `gameType`, `fromPath`, `nodeId`
- `GameStatus` enum: `notStarted → playing → awaitingInput → showingFeedback → completed`

### Learning Path
Sequential unlock — complete the active node to unlock the next. The path is defined
as a static list in `lib/ui/screens/learning_path_screen.dart`. Completion state
persists via `ProgressState` (SharedPreferences). A player marker animates between
nodes on the path.

### Skill Coverage Gaps
Two skills have no game because they require hardware v1 doesn't support:
- **soundMaking** — requires microphone
- **guidedPlay** — requires MIDI/instrument input

Two skills have no game yet:
- **anticipationAndPunctuation** — phrase endings, pauses, accents
- **tonalContrast** — emotional color, resolved vs unresolved tension

---

## Audio Implementation

### Stack
- **flutter_soloud** (v3.1.5) wrapping **miniaudio**
- Singleton `AudioController` in `lib/audio/audio_controller.dart`
- Three asset caches: `_noteCache` (Note enum), `_sfxCache` (SfxType enum),
  `_clipCache` (String paths, used for playground and timbre clips)
- All assets preloaded at startup via `preloadAll()`; playground clips preloaded
  on screen entry

### Supported Formats
miniaudio supports: **MP3, WAV, FLAC, Ogg Vorbis**. It does NOT support AIFF.

**Critical lesson**: `.aif` files will load without error but play as loud buzzing
noise (raw bytes interpreted as PCM). The app has 24 `.aif` percussion samples in
`assets/audio/notes/percussion/` that need to be converted to `.mp3` or `.wav`
before use. The rhythm game currently uses `Note.c5` as a placeholder beat sound
for this reason.

### Key Audio Methods
- `playNote(Note)` — plays from note cache, concurrent (no stopping)
- `playNoteForScale(Note)` — stops previous note, plays new one (for sequential scales)
- `playClip(String path)` — plays from clip cache, stops previous clip
- `playClipAndAwait(String path)` — plays clip and waits for natural completion
  (polls `getIsValidVoiceHandle`). Used by Timbre ID game so UI transitions happen
  after audio finishes, not just after the play call.
- `playSfx(SfxType)` — plays sound effect
- `preloadClips(List<String>)` — preloads paths into clip cache

### Audio Pitfalls Encountered
1. **.aif buzzing** — described above. Convert all percussion assets before use.
2. **No stopAll** — the AudioController has an empty `stopAll()` stub. Individual
   sound handles must be tracked to stop them. Percussion-style "fire and forget"
   plays that don't track handles can't be stopped on navigation.
3. **Clip completion** — `playClip` returns immediately after starting playback.
   For games that need to wait for audio to finish before showing buttons, use
   `playClipAndAwait`.

### Note Assets
24 notes, two octaves: C4–B5 (chromatic). All in `assets/audio/notes/`.
File naming: `c4.mp3`, `c_sharp_4.mp3`, etc. The `Note` enum's `assetPath`
getter handles this mapping.

### Playground Samples
4 instruments with clips in `assets/audio/playground/`:
- Guitar: `guitar1.mp3`, `guitar2.mp3`, `guitar3.mp3` (3 samples, random selection)
- Drums: `drums.mp3`
- Trumpet: `trumpet.mp3`
- Violin: `violin.mp3`
- Piano: `piano.mp3` (clip exists but piano is excluded from Timbre ID game
  since it sounds too similar to other pitched instruments in isolation)

Multi-sample support: `Instrument` enum has `List<String> assetPaths` and a
`randomAssetPath` getter. This is the right pattern for any instrument with
multiple recordings.

---

## What Worked Well

- **flutter_soloud** — genuinely low latency, no click artifacts, good API
- **flutter_animate** — fast to write, good results for UI polish
- **ChangeNotifier pattern** — simple, no over-engineering, easy to test
- **5-round sessions** — kids actually finish them
- **Gentle feedback copy** — "Try the next one!" vs "Wrong!" makes a real difference
- **Same/Different game mechanic** — works well for multiple skill types (used for
  both melody comparison and rhythm comparison)

## What Needs Work

- **Rhythm game beats** — `Note.c5` as a metronome click is functional but not
  satisfying. Woodblock samples exist but need format conversion.
- **No visual feedback during audio** — while a clip plays, the screen just shows
  a headphones emoji. Animated waveform or pulsing character would be better.
- **Pitch Naming difficulty** — Do/Re/Mi labeling is meaningful to adults but may
  not resonate with young kids who haven't learned solfege. May need rethinking.
- **Scale Direction** — reduced to 3 notes which is better, but still feels
  abstract. Visual contour representation could help.
- **No character/mascot** — the single highest-impact visual upgrade would be a
  reactive character (correct = cheers, wrong = shrug). Rive is the right tool
  for this on Flutter; Unity has native animation tools.

---

## Deferred / Future Ideas

### Near-term
- Convert `.aif` percussion files to `.mp3` and wire woodblock into rhythm game
  with proper handle tracking (accent beat 1 with high block, others with low)
- `anticipationAndPunctuation` game — phrase endings, musical punctuation
- `tonalContrast` game — resolved vs unresolved tension

### Medium-term
- Character mascot with Rive (Flutter) or Unity Animator
- Difficulty progression — currently all games are fixed difficulty; adaptive
  difficulty based on skill XP would be the right next step
- TestFlight distribution for family testing

### Longer-term / Unity territory
- Note highway / rhythm tap gameplay (Guitar Hero style)
- Real-time visual feedback synchronized to audio
- More complex rhythm games with visual beat grids
- Microphone input for pitch matching (soundMaking skill)

---

## Project Structure Quick Reference

```
lib/
  app/           — routing (go_router), state (ProgressState, SkillState)
  audio/         — AudioController, Note enum, SfxType enum
  games/         — one folder per game, each has screens/ and state/
  models/        — shared data models (MusicalSkill, Instrument, etc.)
  rewards/       — reward screen
  ui/            — reusable components, theme, home/path/playground screens
assets/
  audio/notes/          — 24 chromatic note samples (mp3)
  audio/notes/percussion/ — 24 percussion samples (aif — needs conversion)
  audio/sfx/            — correct, incorrect, tap, reward, streak sounds
  audio/playground/     — instrument melody clips (mp3)
```

---

## For the Unity Port

The game design and skill system translate directly. Key questions to answer
before starting:

1. **Audio**: Unity's audio latency on mobile is trickier than flutter_soloud.
   Research FMOD or a low-latency audio middleware before committing to Unity's
   built-in AudioSource for anything timing-sensitive.

2. **Note samples**: The same MP3 assets can be reused. The percussion .aif files
   will need conversion regardless of platform.

3. **What Unity buys you**: Animated characters, physics-based UI, note highway
   gameplay, particle systems. Not obviously better for the current quiz-style games.

4. **MCP + CLI**: Unity now has MCP support and CLI build tooling. Claude Code can
   work with Unity projects via these — worth prototyping before committing to a
   full rewrite.

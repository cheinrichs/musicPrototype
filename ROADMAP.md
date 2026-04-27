# Roadmap

## Immediate / High Impact

- [ ] **Instrument samples for Sound Playground** — drop 5 files into `assets/audio/playground/`: `piano.mp3`, `guitar.mp3`, `trumpet.mp3`, `violin.mp3`, `drums.mp3`. GarageBand on Mac is the easiest path. 3–5 seconds each, export as MP3.
- [ ] **Sound effects in games** — `correct.mp3` and `incorrect.mp3` exist in `assets/audio/sfx/` but aren't wired up in game screens. Quick win.
- [ ] **App icon + name** — still showing default Flutter icon. Breaks the "toy" feeling on the home screen.

## Core Experience Polish

- [ ] **Reward screen character reactions** — currently just a star + confetti. A level-up callout ("Pitch Awareness leveled up! 🎵") or animated character reaction would make completing a game feel much more satisfying for kids.
- [ ] **Difficulty scaling within games** — games are fixed difficulty. Even a simple easy/medium/hard parameter lays the groundwork for the adaptive system (auto-adjusting difficulty so kids never feel discouraged).

## Learning Structure

- [ ] **More learning path nodes** — stages 1, 4, 5, 6, 7, 9, and 11 from STATS_README.md have no game yet. Good candidates:
  - Stage 1 (Sound Awareness): volume/duration discrimination
  - Stage 4 (Rhythm & Timing): tap-back a rhythm
- [ ] **Adaptive difficulty** — if a child struggles, the system should reduce difficulty before they feel discouraged. Data model is in place (SkillState + XP); tuning logic comes next.

## Infrastructure

- [ ] **Tests** — game state logic (prompt generation, scoring, XP award threshold) has no test coverage yet.
- [ ] **Android smoke test** — codebase is designed to be cross-platform; worth a quick run to catch any platform-specific issues before they accumulate.

Node Skill Description
🔉1. Sound Awareness
Sound Awareness Loud vs Soft Discriminate between loud and soft sounds (early dynamics awareness).
Sound Awareness Long vs Short Differentiate sustained sounds from short bursts.
Sound Awareness Silence vs Sound Recognize the presence or absence of sound.
Sound Awareness Same vs Different Identify whether two sounds are identical or different.
Sound Awareness Attack vs Smooth Beginning Recognize sharp, accented starts versus gentle starts.
Sound Awareness Sustain vs Short Burst Differentiate held tones from quick sounds.
Sound Awareness Release Awareness Notice whether sounds stop abruptly or fade out.
🏄 2. Pitch Awareness
Pitch Awareness Higher vs Lower Identify which of two notes is higher or lower.
Pitch Awareness Same Note Match Hear a note and select the matching pitch.
Pitch Awareness Pitch Memory Listen to a short tone sequence and identify or recall it.
Pitch Awareness Small vs Big Interval Feel Sense whether two notes are close together or far apart.
Pitch Awareness Near vs Far Pitch Comparison Compare pitch distances between notes.
🌈 3. Contour & Shape
Contour & Shape Ascending vs Descending Identify whether a melody moves upward or downward.
Contour & Shape Contour Shape Match Match a melody to a visual shape (e.g., waterfall or rainbow).
Contour & Shape Stepwise vs Leaping Motion Distinguish between smooth stepwise motion and larger jumps.
Contour & Shape Mixed Contour Recognition Recognize melodies that change direction (up then down).
Contour & Shape Contour Imitation Reproduce melodic shape through tapping or singing.
⏳ 4. Rhythm & Timing
Rhythm & Timing Steady Beat Feel Develop awareness of a consistent pulse.
Rhythm & Timing Tap Along to Pulse Synchronize tapping or movement to a steady beat.
Rhythm & Timing Accent on the Beat Recognize and respond to strong beats.
Rhythm & Timing Rhythm Echo Listen to a short rhythmic pattern and imitate it.
Rhythm & Timing Tempo Awareness Distinguish between faster and slower speeds.
Rhythm & Timing Count-and-Accent Respond with an accented sound after a counted buildup.
🎭 5. Anticipation & Musical Punctuation
Anticipation & Musical Punctuation Call & Response Echo Imitate a sound or phrase after a delay.
Anticipation & Musical Punctuation Wait... BOO! Anticipate a pause followed by a surprise accent.
Anticipation & Musical Punctuation Variable Pause Recognition Adjust to unpredictable pause lengths.
Anticipation & Musical Punctuation Phrase Ending Recognition Identify whether a musical phrase feels finished.
Anticipation & Musical Punctuation Surprise Accent Detection Notice unexpected accented sounds.
🎶 6. Tonal Contrast & Resolution
Tonal Contrast & Resolution Mode Contrast Recognize differences in tonal color (e.g., bright/dark, major/minor).
Tonal Contrast & Resolution Resolution Awareness Recognize tonal stability and whether music feels finished or unresolved.
🎤 7. Sound Making & Sound Shaping
Sound Making & Sound Shaping Attack Control Practice producing sharp or gentle sound beginnings.
Sound Making & Sound Shaping Sustain Control Hold a sound steadily for a duration.
Sound Making & Sound Shaping Release Control End a sound cleanly or smoothly.
Sound Making & Sound Shaping Dynamic Control Change volume gradually from soft to loud and back.
Sound Making & Sound Shaping Shake the Sound Sustain and play with vocal wobble or vibrato.
Sound Making & Sound Shaping Lip Trills / Vocal Warmups Explore airflow and vocal flexibility.
Sound Making & Sound Shaping Vowel Shape Awareness Notice how mouth shape affects sound quality.
Sound Making & Sound Shaping Airflow Awareness Feel breath support and air movement while producing sound.
🎻 8. Timbre & Instrument Awareness
Timbre & Instrument Awareness Instrument Identification Recognize different instruments by sound.
Timbre & Instrument Awareness Same Note Different Instrument Hear how the same pitch changes across instruments.
Timbre & Instrument Awareness Instrument Family Recognition Group instruments by shared characteristics.
Timbre & Instrument Awareness Timbre Matching Match sounds based on tone color.
Timbre & Instrument Awareness Instrument Free Play Explore instrument sounds in an open sandbox environment.
🎹 9. Guided Instrument Play
Guided Instrument Play Follow the Dots (Single Notes) Play highlighted notes in sequence.
Guided Instrument Play Follow Short Pattern Perform a short guided melodic sequence.
Guided Instrument Play Follow Phrase Play a longer musical phrase with guidance.
Guided Instrument Play Memory Replay Watch a pattern once and replay from memory.
Guided Instrument Play Expression While Playing Incorporate dynamics or articulation while performing.
Guided Instrument Play Remove Visual Scaffolds Gradually play without visual cues.
🎼 10. Harmony & Chord Feel
Harmony & Chord Feel Major vs Minor Chord Recognition Identify emotional color of chords.
Harmony & Chord Feel Chord Color Feel Recognize distinct chord qualities by ear.
Harmony & Chord Feel Sing Along With Chord Match voice to sustained chord tones.
Harmony & Chord Feel Root vs Non-Root Feel Sense stability of chord tones.
Harmony & Chord Feel Simple Resolution Feel Hear basic harmonic movement and return to home.
🎵 11. Pitch Naming & Functional Hearing
Pitch Naming & Functional Hearing Do-Re-Mi Association Associate solfege syllables with pitches.
Pitch Naming & Functional Hearing Melody Echo Using Solfege Imitate melodies using solfege syllables.
Pitch Naming & Functional Hearing Hear 'So' as Home Develop awareness of tonal anchor tones.
Pitch Naming & Functional Hearing Basic Interval Naming Identify simple pitch intervals by name.
Pitch Naming & Functional Hearing Moveable Do Awareness Understand solfege in different tonal centers.

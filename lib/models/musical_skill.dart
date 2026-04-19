/// The 11 musical skill nodes from the learning progression framework.
/// Each maps to one or more games and accumulates XP independently.
enum MusicalSkill {
  soundAwareness(
    '🌱',
    'Sound Awareness',
    'Volume, duration, presence, attack, and release',
  ),
  pitchAwareness(
    '🎵',
    'Pitch Awareness',
    'Recognize and compare differences in pitch',
  ),
  contourAndShape(
    '🌈',
    'Contour & Shape',
    'Understand how melodies move through space over time',
  ),
  rhythmAndTiming(
    '⏳',
    'Rhythm & Timing',
    'Pulse, timing, and rhythmic patterns',
  ),
  anticipationAndPunctuation(
    '🎭',
    'Anticipation & Punctuation',
    'Pauses, accents, and musical endings',
  ),
  tonalContrast(
    '🎶',
    'Tonal Contrast & Resolution',
    'Emotional color and tonal stability in music',
  ),
  soundMaking(
    '🎤',
    'Sound Making',
    'Control over producing and shaping sound intentionally',
  ),
  timbreAndInstrument(
    '🎻',
    'Timbre & Instrument',
    'Differences in sound color across voices and instruments',
  ),
  guidedPlay(
    '🎹',
    'Guided Instrument Play',
    'Translate listening and visual cues into musical execution',
  ),
  harmonyAndChordFeel(
    '🎼',
    'Harmony & Chord Feel',
    'How multiple notes combine to create emotional color',
  ),
  pitchNaming(
    '🎵',
    'Pitch Naming',
    'Connect pitch perception to symbolic language (e.g., solfege)',
  );

  const MusicalSkill(this.emoji, this.label, this.description);

  final String emoji;
  final String label;
  final String description;
}

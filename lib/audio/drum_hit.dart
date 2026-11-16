/// Pure Dart, like `HighLowInstrument`.
library;

/// The drum: an UNPITCHED instrument, so not a note library.
///
/// ⚠️ NEVER PUT THE DRUM IN `HighLowInstrument` or anything expecting a
/// chromatic range. A drum has no pitch to be high or low, so it can never
/// serve a pitch game. What it needs is a FEW GOOD HITS TO SEQUENCE INTO
/// RHYTHMS. A same-or-different comparison with drums compares RHYTHMS,
/// not melodies, and whether that belongs in the Matching Grove or in the
/// rhythm game is still open between Cooper and the user.
///
/// Two hits, matching the drum art (a rope-tension snare with sticks):
/// the snare, and a tom as a second, lower voice for accents. Philharmonia
/// percussion, 2026-11-14 (assets/audio/percussion/drum/PROVENANCE.md).
/// Nothing plays them yet.
enum DrumHit {
  snare('assets/audio/percussion/drum/snare.mp3'),
  tom('assets/audio/percussion/drum/tom.mp3');

  const DrumHit(this.assetPath);

  final String assetPath;
}

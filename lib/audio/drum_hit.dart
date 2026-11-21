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
/// Two drums, each with its own art and its own sample (2026-11-20):
///
/// - SNARE: the rope-tension snare (drum_x3.png). Its sample is the
///   confirmed match for that art (a musician Cooper consulted).
/// - TOM: a concert tom on legs, chrome lugs, no snare hardware
///   (tomtom_x3.png), drawn deliberately unlike the snare. Its sample is
///   Philharmonia's tom-tom, which had no art until Cooper drew this.
///
/// Snare against tom (Cooper, 2026-11-21): allowed in every game except the
/// Matching Grove, but NEVER in High vs Low. The snare is unpitched noise
/// and the tom sits near D4, so "which is higher" is not a question. Kept
/// out by construction: neither is a `HighLowInstrument`.
///
/// Philharmonia percussion (assets/audio/percussion/drum/PROVENANCE.md).
/// Nothing plays them yet.
enum DrumHit {
  snare('assets/audio/percussion/drum/snare.mp3', 'drum'),
  tom('assets/audio/percussion/drum/tom.mp3', 'tomtom');

  const DrumHit(this.assetPath, this.sheet);

  final String assetPath;

  /// Its art: a key of `instrumentSheets`.
  final String sheet;
}

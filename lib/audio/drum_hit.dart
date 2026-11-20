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
/// One hit: the snare, the confirmed match for the drum art (a
/// rope-tension snare with sticks; confirmed by a musician Cooper
/// consulted, 2026-11-20). Philharmonia percussion
/// (assets/audio/percussion/drum/PROVENANCE.md). Nothing plays it yet.
///
/// The tom (tom.mp3) is INTENTIONALLY UNUSED and deliberately not listed
/// here: no instrument art depicts a tom. Add it back only if one is drawn.
enum DrumHit {
  snare('assets/audio/percussion/drum/snare.mp3');

  const DrumHit(this.assetPath);

  final String assetPath;
}

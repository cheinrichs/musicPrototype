/// Instruments that can appear as the two characters in the High/Low game.
///
/// The game's pitch audio (assets/audio/notes/) is a single shared,
/// instrument-agnostic tone — there is no per-instrument pitched sample
/// library anywhere in the kit (see Trello card 39's audit). Picking a
/// different instrument here is a visual reskin only; the same note audio
/// plays no matter which one is showing. That's already true of the
/// previously-hardcoded Guitar, so this doesn't introduce a new gap.
///
/// The seven values match every character the SongStone-UI-Kit ships art
/// for under assets/images/characters/instruments/ (each as a "1"/"2" pair
/// used for the left/right character respectively).
enum HighLowInstrument {
  bells('Bell', 'bell'),
  cello('Cello', 'cello'),
  drum('Drum', 'drum'),
  flute('Flute', 'flute'),
  guitar('Guitar', 'guitar'),
  piano('Piano', 'piano'),
  violin('Violin', 'violin');

  const HighLowInstrument(this._assetBaseName, this.displayName);

  final String _assetBaseName;

  /// Lowercase singular name for prompt/status copy, e.g. "Which piano
  /// played a higher note?"
  final String displayName;

  String get leftAssetPath =>
      'assets/images/characters/instruments/${_assetBaseName}1.png';

  String get rightAssetPath =>
      'assets/images/characters/instruments/${_assetBaseName}2.png';
}

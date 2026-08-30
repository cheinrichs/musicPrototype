/// Instruments that can appear as the two characters in the High/Low game.
///
/// Six of the seven now have their own recorded, per-note sample library
/// under `assets/audio/notes/<instrument>/` (see [sampleInstrument] and
/// Trello card 44). Drum has none — real drums don't have a chromatic
/// scale to record in the first place — so it falls back to the shared
/// instrument-agnostic tone via [Note.assetPath]'s own fallback. A future
/// card covers sourcing a genuinely pitched drum-like library.
///
/// The seven values match every character the SongStone-UI-Kit ships art
/// for under assets/images/characters/instruments/ (each as a "1"/"2" pair
/// used for the left/right character respectively).
enum HighLowInstrument {
  bells('Bell', 'bell', 'bells'),
  cello('Cello', 'cello', 'cello'),
  drum('Drum', 'drum', null),
  flute('Flute', 'flute', 'flute'),
  guitar('Guitar', 'guitar', 'guitar'),
  piano('Piano', 'piano', 'piano'),
  violin('Violin', 'violin', 'violin');

  const HighLowInstrument(
    this._assetBaseName,
    this.displayName,
    this.sampleInstrument,
  );

  final String _assetBaseName;

  /// Lowercase singular name for prompt/status copy, e.g. "Which piano
  /// played a higher note?"
  final String displayName;

  /// Key to pass as `Note.assetPath(instrument: ...)` / the AudioController
  /// `instrument` param to reach this instrument's own sample library, or
  /// null when there isn't one (falls back to the generic tone).
  final String? sampleInstrument;

  String get leftAssetPath =>
      'assets/images/characters/instruments/${_assetBaseName}1.png';

  String get rightAssetPath =>
      'assets/images/characters/instruments/${_assetBaseName}2.png';
}

/// Instruments that can appear as the two characters in the High/Low game.
///
/// Each one has its own recorded, per-note sample library under
/// `assets/audio/notes/<instrument>/` (see [sampleInstrument] and Trello
/// card 44), so every rotation plays genuinely instrument-appropriate
/// audio — there's no generic-tone fallback reachable from this game.
///
/// Drum is deliberately not among the values below (Trello card 45):
/// a real drum isn't chromatically pitched, which makes it a poor vehicle
/// for teaching high vs. low. The character and its art are still used
/// elsewhere (the rhythm games), just not here — see
/// assets/images/characters/instruments/ for the full SongStone-UI-Kit
/// set, which still includes Drum1/Drum2.
enum HighLowInstrument {
  bells('Bell', 'bell', 'bells'),
  cello('Cello', 'cello', 'cello'),
  flute('Flute', 'flute', 'flute'),
  guitar('Guitar', 'guitar', 'guitar'),
  // Oboe character art (Trello card 55) — SongStone-UI-Kit's Oboe.png is a
  // two-up sheet (black/silver-keys / rosewood/gold-keys); black-with-silver
  // is used as Oboe1 since it's the traditional, most recognizable finish
  // for a professional oboe (mirrors trumpet's gold-as-Trumpet1 reasoning).
  oboe('Oboe', 'oboe', 'oboe'),
  piano('Piano', 'piano', 'piano'),
  trumpet('Trumpet', 'trumpet', 'trumpet'),
  // Tuba character art (Trello card 55) — SongStone-UI-Kit's Tuba.png is a
  // two-up sheet (silver / brass-gold); brass-gold is used as Tuba1 as the
  // traditional, most recognizable finish (same reasoning as trumpet).
  tuba('Tuba', 'tuba', 'tuba'),
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
  /// `instrument` param to reach this instrument's own sample library.
  final String sampleInstrument;

  String get leftAssetPath =>
      'assets/images/characters/instruments/${_assetBaseName}1.png';

  String get rightAssetPath =>
      'assets/images/characters/instruments/${_assetBaseName}2.png';
}

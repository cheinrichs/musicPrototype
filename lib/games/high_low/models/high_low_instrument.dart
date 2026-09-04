import 'dart:math' as math;

/// Instruments that can appear as the two characters in the High/Low game.
///
/// Each one declares the real MIDI range its own sample library actually
/// covers — [lowestSampleMidi]/[highestSampleMidi] — and [assetPathForMidi]
/// looks its files up directly by that real pitch. This replaced an
/// earlier design (Trello card 44) that forced every instrument's samples
/// into the same fixed C4-B5 slot names as the shared `Note` enum,
/// papering over instruments that don't actually play there with a
/// per-instrument "real pitch offset" applied everywhere the number was
/// used. That offset went uncorrected for guitar for roughly a year —
/// nobody had measured the audio directly, so a copy-by-analogy guess
/// (guitar assumed to be transposed the same two octaves as tuba) shipped
/// as fact. A 2026-09 audit (`tool/measure_note_pitch.py`, committed so
/// this doesn't happen silently again) measured every note file's actual
/// fundamental and found: guitar's real pitch is one octave down, not
/// two, and its 24-file set has four files with bad or duplicate content
/// rather than a labeling problem; tuba's two-octaves-down transposition
/// was correct, but one of its files also had bad content. Both
/// instruments' ranges below reflect the largest gap-free stretch that's
/// left after removing those files — see each constructor call's comment
/// for specifics, and the audit's own report for what would need
/// re-recording to close the gaps.
///
/// This also means an instrument's declared range is no longer always two
/// octaves. [semitoneOverlapWith]/[canPairWith] exist for exactly that: a
/// future cross-instrument round (Trello, tier T3 — not implemented yet;
/// today's [PromptGenerator] still always plays both sides of a round on
/// one instrument) can check two instruments actually have enough shared
/// range for the interval it wants, rather than assuming every instrument
/// can reach every other one.
///
/// Drum is deliberately not among the values below (Trello card 45):
/// a real drum isn't chromatically pitched, which makes it a poor vehicle
/// for teaching high vs. low. The character and its art are still used
/// elsewhere (the rhythm games), just not here — see
/// assets/images/characters/instruments/ for the full SongStone-UI-Kit
/// set, which still includes Drum1/Drum2.
enum HighLowInstrument {
  // Bells (2026-09 audit): kept at its original real C4-B5, matching its
  // label — but unlike every other instrument here, that's *not* a
  // confirmed-correct range, it's "not confidently wrong enough to
  // change." Most of bells' 24 files individually read a clean octave
  // *above* label under autocorrelation, which usually means the false
  // positive its own docs warn about (struck idiophones have strong
  // inharmonic overtones that can dominate a naive pitch read). But the
  // audit's structural safeguard — chromatic-scale consistency, checked
  // file-to-file rather than file-to-label, so a uniform octave error
  // can't hide behind it — actually *fails* for bells, in a way it
  // doesn't for any other instrument here: five files (c#5, g#5, a5, a#5,
  // b5) break the chromatic run relative to their neighbors, and three of
  // those (a5, a#5, b5) measure at essentially the *same* pitch as their
  // octave-4 counterparts rather than an octave above. That's real
  // internal inconsistency, not just an ambiguous single reading — bells
  // needs a human listen before its range or any individual file here
  // should be trusted further.
  bells('Bell', 'bell', 'bells', 60, 83),
  cello('Cello', 'cello', 'cello', 60, 83),
  flute('Flute', 'flute', 'flute', 60, 83),
  // Guitar (2026-09 audit): real pitch is one octave below its file names
  // (not two, which is what an uncorrected guess — copied from tuba's own
  // offset without measuring guitar independently — had assumed for
  // roughly a year). Likely cause: the source pack's guitar notation is
  // conventionally written an octave above where it sounds. Renamed the
  // 20 files whose content cleanly matched that one-octave shift; deleted
  // four whose content didn't (two had no clear tonal signal at all, two
  // had real but wrong-octave content each duplicating a note guitar
  // already has elsewhere in its 24). That leaves real gaps at F#3, G#3,
  // A3, and A#4. [58, 69] (A#3-A4) is the largest gap-free run left —
  // smaller than every other instrument's two octaves, honestly, until
  // those four notes get re-recorded.
  guitar('Guitar', 'guitar', 'guitar', 58, 69),
  oboe('Oboe', 'oboe', 'oboe', 60, 83),
  piano('Piano', 'piano', 'piano', 60, 83),
  trumpet('Trumpet', 'trumpet', 'trumpet', 60, 83),
  // Tuba (Trello card 55, confirmed by the 2026-09 audit): real pitch is
  // two octaves below its file names, exactly as originally sourced — the
  // one instrument the uncorrected guess above happened to get right.
  // One file (real C#3) measured ambiguously between C#3 and D3 rather
  // than cleanly matching either and was deleted rather than guessed at,
  // leaving a gap. [36, 48] (C2-C3) is the largest gap-free run left —
  // and notably sits entirely below every other instrument's range,
  // including guitar's [58, 69] just above: closing that C#3 gap would
  // restore tuba's full C2-B3 (up to 59), which *does* reach guitar's
  // bottom end, but until then tuba can't be paired with anything for a
  // cross-instrument round (canPairWith is false against every other
  // value here).
  tuba('Tuba', 'tuba', 'tuba', 36, 48),
  violin('Violin', 'violin', 'violin', 60, 83);

  const HighLowInstrument(
    this._assetBaseName,
    this.displayName,
    this.sampleInstrument,
    this.lowestSampleMidi,
    this.highestSampleMidi,
  );

  final String _assetBaseName;

  /// Lowercase singular name for prompt/status copy, e.g. "Which piano
  /// played a higher note?"
  final String displayName;

  /// Directory name under `assets/audio/notes/` holding this instrument's
  /// sample library.
  final String sampleInstrument;

  /// Lowest real MIDI note this instrument's sample library covers,
  /// gap-free, up to [highestSampleMidi] — see the class doc for how this
  /// was measured and why it isn't always a full two octaves.
  final int lowestSampleMidi;

  /// Highest real MIDI note this instrument's sample library covers.
  final int highestSampleMidi;

  String get leftAssetPath =>
      'assets/images/characters/instruments/${_assetBaseName}1.png';

  String get rightAssetPath =>
      'assets/images/characters/instruments/${_assetBaseName}2.png';

  /// Asset path for the sample that sounds at real MIDI [midi]. The file's
  /// name is that real pitch directly — no separate logical slot to
  /// translate through. [midi] must fall within [lowestSampleMidi]..
  /// [highestSampleMidi].
  String assetPathForMidi(int midi) {
    assert(
      midi >= lowestSampleMidi && midi <= highestSampleMidi,
      '$name has no sample at MIDI $midi '
      '(range is $lowestSampleMidi-$highestSampleMidi)',
    );
    return 'assets/audio/notes/$sampleInstrument/${_sampleFilenameForMidi(midi)}.mp3';
  }

  /// Every asset path in this instrument's declared range, for preloading.
  List<String> get allAssetPaths => [
    for (var midi = lowestSampleMidi; midi <= highestSampleMidi; midi++)
      assetPathForMidi(midi),
  ];

  /// Semitones [lowestSampleMidi]..[highestSampleMidi] overlaps with
  /// [other]'s own range. Zero or negative means no usable overlap at
  /// all — e.g. tuba (C2-C3) and flute (C4-B5) don't share any range.
  int semitoneOverlapWith(HighLowInstrument other) {
    final overlapLow = math.max(lowestSampleMidi, other.lowestSampleMidi);
    final overlapHigh = math.min(highestSampleMidi, other.highestSampleMidi);
    return overlapHigh - overlapLow;
  }

  /// Whether this instrument and [other] can be paired for a cross-
  /// instrument round needing at least [minSemitones] of interval room —
  /// typically a [ConceptTier]'s `minSemitones`. True exactly when their
  /// ranges overlap by that much, which is also exactly enough for a round
  /// generator to place either instrument as the higher note (pick any
  /// note at the bottom of the overlap for one side and [minSemitones]
  /// above it, within the overlap, for the other — swap which instrument
  /// gets which to flip who's higher). Tuba vs. flute is never pairable
  /// (no overlap at all); tuba vs. guitar is, since their ranges share
  /// several semitones. Deliberately not modeled as register "families" —
  /// register is a property of the measured samples, not a fixed trait of
  /// the instrument, and cello/piano/guitar all span whatever boundary a
  /// family list would try to draw.
  bool canPairWith(HighLowInstrument other, {required int minSemitones}) =>
      semitoneOverlapWith(other) >= minSemitones;
}

const _sampleNoteNames = [
  'c',
  'c_sharp',
  'd',
  'd_sharp',
  'e',
  'f',
  'f_sharp',
  'g',
  'g_sharp',
  'a',
  'a_sharp',
  'b',
];

String _sampleFilenameForMidi(int midi) {
  final name = _sampleNoteNames[midi % 12];
  final octave = midi ~/ 12 - 1;
  // Sharps carry an underscore before the octave digit too (c_sharp_4),
  // naturals don't (c4) — matches the existing asset naming convention.
  return name.contains('_sharp') ? '${name}_$octave' : '$name$octave';
}

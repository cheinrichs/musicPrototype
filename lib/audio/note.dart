/// Musical note enum representing piano notes from C4 to B5
/// Two octaves (24 notes total) for ear training exercises
enum Note {
  c4,
  cSharp4,
  d4,
  dSharp4,
  e4,
  f4,
  fSharp4,
  g4,
  gSharp4,
  a4,
  aSharp4,
  b4,
  c5,
  cSharp5,
  d5,
  dSharp5,
  e5,
  f5,
  fSharp5,
  g5,
  gSharp5,
  a5,
  aSharp5,
  b5,
}

extension NoteExtension on Note {
  /// MIDI number for the note (C4 = 60)
  int get midiNumber {
    switch (this) {
      case Note.c4:
        return 60;
      case Note.cSharp4:
        return 61;
      case Note.d4:
        return 62;
      case Note.dSharp4:
        return 63;
      case Note.e4:
        return 64;
      case Note.f4:
        return 65;
      case Note.fSharp4:
        return 66;
      case Note.g4:
        return 67;
      case Note.gSharp4:
        return 68;
      case Note.a4:
        return 69;
      case Note.aSharp4:
        return 70;
      case Note.b4:
        return 71;
      case Note.c5:
        return 72;
      case Note.cSharp5:
        return 73;
      case Note.d5:
        return 74;
      case Note.dSharp5:
        return 75;
      case Note.e5:
        return 76;
      case Note.f5:
        return 77;
      case Note.fSharp5:
        return 78;
      case Note.g5:
        return 79;
      case Note.gSharp5:
        return 80;
      case Note.a5:
        return 81;
      case Note.aSharp5:
        return 82;
      case Note.b5:
        return 83;
    }
  }

  /// Instruments with their own recorded, per-note sample library under
  /// `assets/audio/notes/<instrument>/` (roughly two octaves each, one
  /// dynamic level, trimmed and loudness-matched — see Trello card 44).
  /// Anything else falls back to the shared instrument-agnostic set.
  static const Set<String> _instrumentsWithSamples = {
    'bells',
    'cello',
    'flute',
    'guitar',
    'piano',
    'trumpet',
    'violin',
  };

  /// Public view of [_instrumentsWithSamples], for preloading.
  static Set<String> get instrumentsWithSamples => _instrumentsWithSamples;

  /// Asset path for the note's audio file.
  ///
  /// Pass [instrument] (e.g. 'cello') to use that instrument's own sample
  /// library when one exists; otherwise (or when omitted) this falls back
  /// to the shared instrument-agnostic tone under assets/audio/notes/.
  String assetPath({String? instrument}) {
    final filename = name
        .replaceAll('Sharp', '_sharp_')
        .replaceAllMapped(RegExp(r'(\d)'), (m) => '${m[1]}');
    if (instrument != null && _instrumentsWithSamples.contains(instrument)) {
      return 'assets/audio/notes/$instrument/$filename.mp3';
    }
    return 'assets/audio/notes/$filename.mp3';
  }

  /// Human-readable name for display
  String get displayName {
    switch (this) {
      case Note.c4:
        return 'C4';
      case Note.cSharp4:
        return 'C#4';
      case Note.d4:
        return 'D4';
      case Note.dSharp4:
        return 'D#4';
      case Note.e4:
        return 'E4';
      case Note.f4:
        return 'F4';
      case Note.fSharp4:
        return 'F#4';
      case Note.g4:
        return 'G4';
      case Note.gSharp4:
        return 'G#4';
      case Note.a4:
        return 'A4';
      case Note.aSharp4:
        return 'A#4';
      case Note.b4:
        return 'B4';
      case Note.c5:
        return 'C5';
      case Note.cSharp5:
        return 'C#5';
      case Note.d5:
        return 'D5';
      case Note.dSharp5:
        return 'D#5';
      case Note.e5:
        return 'E5';
      case Note.f5:
        return 'F5';
      case Note.fSharp5:
        return 'F#5';
      case Note.g5:
        return 'G5';
      case Note.gSharp5:
        return 'G#5';
      case Note.a5:
        return 'A5';
      case Note.aSharp5:
        return 'A#5';
      case Note.b5:
        return 'B5';
    }
  }

  /// Check if this note is higher than another
  bool isHigherThan(Note other) => midiNumber > other.midiNumber;

  /// Check if this note is lower than another
  bool isLowerThan(Note other) => midiNumber < other.midiNumber;

  /// Get the interval in semitones between this note and another
  int intervalTo(Note other) => (other.midiNumber - midiNumber).abs();

  /// Get note by MIDI number
  static Note? fromMidiNumber(int midi) {
    for (final note in Note.values) {
      if (note.midiNumber == midi) return note;
    }
    return null;
  }
}

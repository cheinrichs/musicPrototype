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
  ///
  /// The 24 files always fill the `Note` enum's logical C4-B5 slots
  /// positionally (c4.mp3 .. b5.mp3), but for an instrument whose real
  /// playable range doesn't cleanly cover two gap-free chromatic octaves
  /// at true C4-B5, the samples are taken from wherever the source
  /// library *is* gap-free and mapped in at the same positions — the
  /// files sound like a real, correctly-ordered two-octave run on that
  /// instrument, just not at the pitches their names would suggest on a
  /// piano. Guitar is transposed this way: its 24 files are sourced from
  /// real C2-B3 (two real octaves down), same as tuba below. So is tuba
  /// (Trello card 55): its practical range tops out around F4, so its 24
  /// files are also sourced from real C2-B3 rather than C4-B5. Oboe (also
  /// card 55) needed no transposition — its real C4-B5 is gap-free. Bells
  /// likewise sounds at true written pitch (C4-B5, no transposition) —
  /// confirmed by measuring every note file's fundamental frequency
  /// against its label (2026-09 pitch-mapping audit). That same audit
  /// found two bells files (c4, c#5) whose *content* — not the mapping —
  /// measured off-pitch/inharmonic and need re-recording, not a code fix.
  ///
  /// Decided (Cooper: "i don't think we'll be pitting different
  /// instruments against each other ever and comparing pitch"): a
  /// High/Low round is always two notes on the *same* instrument, enforced
  /// by an assertion in [HighLowPrompt]'s constructor. Guitar/tuba's
  /// transposition therefore always cancels out between the two sides —
  /// but [HighLowPrompt.correctAnswer] compares real sounding pitch
  /// ([midiNumber] plus the instrument's transposition) rather than
  /// [midiNumber] alone regardless, so it stays correct even if that rule
  /// ever changes.
  static const Set<String> _instrumentsWithSamples = {
    'bells',
    'cello',
    'flute',
    'guitar',
    'oboe',
    'piano',
    'trumpet',
    'tuba',
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

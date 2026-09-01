/// Spoken lines used by the agency-staged games (Trello card 91). All
/// eight recordings now exist under assets/audio/voice/ (Trello card 93).
/// [AudioController.playVoiceLine] still silently no-ops on a missing
/// asset (same fallback the Sound Playground uses for missing instrument
/// clips), and callers still pair every voice line with an on-screen
/// caption via [captionText] so the stage stays legible if audio is ever
/// missing — but in normal play the caption fallback is unreachable now
/// that the recordings are all in place.
enum VoiceLine {
  /// Piper, narrating the lower instrument in Observe (A0).
  piperSaysLow,

  /// Clef, narrating the higher instrument in Observe (A0).
  clefSaysHigh,

  /// Participate (A1) round prompt when the target is the higher one.
  listenForHigh,

  /// Participate (A1) round prompt when the target is the lower one.
  listenForLow,

  /// Trigger (A2) round prompt when the target is the higher one. Clef
  /// owns the high pole (Trello card 101), so this is Clef speaking in the
  /// first person — Clef is also the one centered and dragged.
  putMeOnHigh,

  /// Trigger (A2) round prompt when the target is the lower one. Piper
  /// owns the low pole (Trello card 101), so this is Piper speaking in the
  /// first person — Piper is also the one centered and dragged.
  putMeOnLow,

  /// Trigger (A2) gentle retry after a wrong drop, when Clef is the
  /// dragged character (i.e. the target was the high pole).
  tryAgainClef,

  /// Trigger (A2) gentle retry after a wrong drop, when Piper is the
  /// dragged character (i.e. the target was the low pole).
  tryAgainPiper;

  String get assetPath => 'assets/audio/voice/$name.mp3';

  /// Placeholder-friendly caption shown alongside the (currently silent)
  /// audio — see the class doc.
  String get captionText => switch (this) {
    VoiceLine.piperSaysLow => 'Piper: this sounds low!',
    VoiceLine.clefSaysHigh => 'Clef: this sounds high!',
    VoiceLine.listenForHigh => 'Listen for the high one.',
    VoiceLine.listenForLow => 'Listen for the low one.',
    VoiceLine.putMeOnHigh => 'Clef: put me on the high one.',
    VoiceLine.putMeOnLow => 'Piper: put me on the low one.',
    VoiceLine.tryAgainClef => "Clef: hmm, let's listen again!",
    VoiceLine.tryAgainPiper => "Piper: hmm, let's listen again!",
  };
}

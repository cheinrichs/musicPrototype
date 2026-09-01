/// Spoken lines used by the agency-staged games (Trello card 91). The
/// actual recordings don't exist yet (Trello card 93 — Cooper is
/// producing them); until they land, [AudioController.playVoiceLine]
/// silently no-ops on the missing asset (same fallback the Sound
/// Playground already uses for missing instrument clips), and callers
/// pair every voice line with an on-screen caption via [captionText] so
/// the stage stays legible with audio alone missing. Dropping in real
/// files later is just adding them under assets/audio/voice/ and
/// declaring that directory in pubspec.yaml — no code changes required.
enum VoiceLine {
  /// Piper, narrating the lower instrument in Observe (A0).
  piperSaysLow,

  /// Clef, narrating the higher instrument in Observe (A0).
  clefSaysHigh,

  /// Participate (A1) round prompt when the target is the higher one.
  listenForHigh,

  /// Participate (A1) round prompt when the target is the lower one.
  listenForLow,

  /// Trigger (A2) round prompt when the target is the higher one.
  putClefOnHigh,

  /// Trigger (A2) round prompt when the target is the lower one.
  putClefOnLow,

  /// Trigger (A2) gentle retry after a wrong drop.
  tryAgainListen;

  String get assetPath => 'assets/audio/voice/$name.mp3';

  /// Placeholder-friendly caption shown alongside the (currently silent)
  /// audio — see the class doc.
  String get captionText => switch (this) {
    VoiceLine.piperSaysLow => 'Piper: this sounds low!',
    VoiceLine.clefSaysHigh => 'Clef: this sounds high!',
    VoiceLine.listenForHigh => 'Listen for the high one.',
    VoiceLine.listenForLow => 'Listen for the low one.',
    VoiceLine.putClefOnHigh => 'Put Clef on the high one.',
    VoiceLine.putClefOnLow => 'Put Clef on the low one.',
    VoiceLine.tryAgainListen => "Hmm, let's listen again!",
  };
}

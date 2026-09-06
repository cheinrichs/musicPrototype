/// Spoken lines used by the agency-staged games (Trello card 91).
/// [AudioController.playVoiceLine] silently no-ops on a missing asset
/// (same fallback the Sound Playground uses for missing instrument
/// clips), and callers still pair every voice line with an on-screen
/// caption via [captionText] so the stage stays legible if audio is ever
/// missing — that fallback is exactly what [listenForLow] currently
/// depends on (see its doc comment).
///
/// Re-recorded (2026-09, nine files) to replace the original placeholder
/// takes, gain-normalized separately from the note library (voice sits
/// louder — see tool/build_voice_lines.py) and format-converted from the
/// 24kHz mono WAVs Cooper delivered to this project's standard mono/
/// 44.1kHz/64kbps CBR mp3.
enum VoiceLine {
  /// Piper, narrating the lower instrument in Observe (A0) — spoken as
  /// the first note of the pair ("That sounds low!").
  piperSaysLow,

  /// Piper, narrating the lower instrument in Observe (A0) — spoken as
  /// the *second* note of the pair, continuing the sentence the first
  /// note's narration started ("...and that sounds low!"). Distinct
  /// recording from [piperSaysLow], not a reuse — the two are meant to
  /// join into one sentence across the pair, so whichever narration
  /// happens second needs the "and" continuation, not a repeat of the
  /// first-note line.
  piperSaysLowSecond,

  /// Clef, narrating the higher instrument in Observe (A0) — spoken as
  /// the first note of the pair ("Ooh, that sounds high!").
  clefSaysHigh,

  /// Clef, narrating the higher instrument in Observe (A0) — spoken as
  /// the *second* note of the pair ("...and ooh, that sounds high!") —
  /// see [piperSaysLowSecond]'s doc comment for why this is a distinct
  /// recording rather than a reuse of [clefSaysHigh].
  clefSaysHighSecond,

  /// Participate (A1) round prompt when the target is the higher one.
  listenForHigh,

  /// Participate (A1) round prompt when the target is the lower one —
  /// Piper's equivalent of [listenForHigh]. No recording exists for this
  /// yet (2026-09's nine-file re-recording batch covered every other
  /// line but not this one) — until one is delivered, this asset is
  /// simply absent and play falls back to the on-screen caption only,
  /// via the same missing-asset handling every other line already has.
  /// Do not point this at a placeholder/stand-in take; leave it silent
  /// until the real line exists.
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

  /// Placeholder-friendly caption shown alongside the audio — see the
  /// class doc. Transcribes what's actually recorded, not a paraphrase,
  /// so the fallback reads the same as what a working line would sound
  /// like.
  String get captionText => switch (this) {
    VoiceLine.piperSaysLow => 'Piper: that sounds low!',
    VoiceLine.piperSaysLowSecond => 'Piper: ...and that sounds low!',
    VoiceLine.clefSaysHigh => 'Clef: ooh, that sounds high!',
    VoiceLine.clefSaysHighSecond => 'Clef: ...and ooh, that sounds high!',
    VoiceLine.listenForHigh => 'Clef: ooh, listen for the high one.',
    VoiceLine.listenForLow => 'Listen for the low one.',
    VoiceLine.putMeOnHigh => 'Clef: give me the high one.',
    VoiceLine.putMeOnLow => 'Piper: give me the low one.',
    VoiceLine.tryAgainClef => 'Clef: ooh, nearly! Let\'s listen again.',
    VoiceLine.tryAgainPiper => "Piper: nearly! Let's have another listen.",
  };
}

import 'spoken_line.dart';

/// Lines the app owns for every game, not any one game (Trello card 183,
/// "Shared voice lines", decided 2026-10-05). High vs Low, Loud or Quiet and
/// Matching all use the nudge pool; the arrow cue is the same in every game
/// that has an arrow.
///
/// **Each member's name is its asset name**, so the recordings already in
/// `assets/audio/voice/` need no renaming. The nudge members keep the
/// `tryAgain…` names they were recorded under; the age-band suffix says which
/// recording it is, and the pool is shared across bands on purpose (Trello
/// card 151: none is too advanced for two or too babyish for eight).
///
/// **A game may replace a shared line** for itself, through the override map
/// its state takes, when the shared wording stops fitting that game. Shared by
/// default, overridden on purpose.
///
/// The arrow cue has no recording yet, so it plays as a silent no-op until one
/// is made, the same as any other missing asset.
enum SharedVoiceLine implements SpokenLine {
  /// Clef's nudge, 2-3 and 4-5 wording ("Ooh, nearly! Listen again.").
  tryAgainClef,

  /// Clef's nudge, 4-5 wording ("Ooh, so close! Let's hear that again.").
  tryAgainClef45,

  /// Piper's nudge, 2-3 and 4-5 wording ("Nearly! Have another listen.").
  tryAgainPiper,

  /// Piper's nudge, 4-5 wording ("So close! Let's hear it again.").
  tryAgainPiper45,

  /// Piper's nudge, 6-7 wording ("Not that one — one more listen.").
  tryAgainPiper67,

  /// Piper's nudge, 8+ wording ("That's not it. Try again.").
  tryAgainPiper8plus,

  /// The arrow cue, in Piper's voice (Trello card 183, decided 2026-10-05): a
  /// calm instruction, "Press the arrow when you're done!" (card 182's
  /// wording). Replaces the earlier unrecorded hook, "Tap the arrow when
  /// you're ready." No recording yet.
  pressTheArrowWhenDone;

  @override
  String get assetName => name;

  @override
  String get assetPath => 'assets/audio/voice/$name.mp3';

  @override
  bool get isPiper => switch (this) {
    SharedVoiceLine.tryAgainClef => false,
    SharedVoiceLine.tryAgainClef45 => false,
    SharedVoiceLine.tryAgainPiper => true,
    SharedVoiceLine.tryAgainPiper45 => true,
    SharedVoiceLine.tryAgainPiper67 => true,
    SharedVoiceLine.tryAgainPiper8plus => true,
    SharedVoiceLine.pressTheArrowWhenDone => true,
  };
}

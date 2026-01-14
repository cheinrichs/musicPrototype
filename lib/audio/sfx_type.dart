/// Sound effects used throughout the app
enum SfxType {
  /// Played when the user answers correctly
  correct,

  /// Played when the user answers incorrectly (gentle)
  incorrect,

  /// Played on button tap for feedback
  tap,

  /// Played on reward/celebration screen
  reward,

  /// Played when achieving a streak milestone
  streak,
}

extension SfxTypeExtension on SfxType {
  /// Asset path for the sound effect
  String get assetPath => 'assets/audio/sfx/$name.mp3';
}

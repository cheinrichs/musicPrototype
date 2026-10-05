/// Anything the app can say aloud: a game's own [VoiceLine]s, or a line the
/// app owns for every game ([SharedVoiceLine]). The audio controller and the
/// speaking indicator take this rather than either enum, so a shared line
/// plays and animates the same way a game's own line does.
abstract interface class SpokenLine {
  /// The asset name, which is also the enum name — the speaking indicator and
  /// the voice envelope library key off this (see `VoiceEnvelopeLibrary`).
  String get assetName;

  /// `assets/audio/voice/<name>.mp3`.
  String get assetPath;

  /// True if Piper speaks this line, false if Clef does.
  bool get isPiper;
}

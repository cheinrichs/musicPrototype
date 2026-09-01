# Voice lines (Trello card 93)

Recordings for `VoiceLine` (see `lib/audio/voice_line.dart`) go here, one
`.mp3` per enum value, named after it: `piperSaysLow.mp3`, `clefSaysHigh.mp3`,
`listenForHigh.mp3`, `listenForLow.mp3`, `putClefOnHigh.mp3`,
`putClefOnLow.mp3`, `tryAgainListen.mp3`.

Until these exist, `AudioController.playVoiceLine` silently no-ops and the
game falls back to the on-screen caption text (`VoiceLine.captionText`).

Once real files land here, add `assets/audio/voice/` to the `flutter.assets`
list in `pubspec.yaml` (it's deliberately left out today — an asset
directory declared in pubspec.yaml but missing on disk breaks the build).

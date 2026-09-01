# Voice lines (Trello card 93)

Recordings for `VoiceLine` (see `lib/audio/voice_line.dart`) go here, one
`.mp3` per enum value, named after it: `piperSaysLow.mp3`, `clefSaysHigh.mp3`,
`listenForHigh.mp3`, `listenForLow.mp3`, `putMeOnHigh.mp3`,
`putMeOnLow.mp3`, `tryAgainClef.mp3`, `tryAgainPiper.mp3`.

All eight now exist, so `AudioController.playVoiceLine` should always find
its asset in normal play; the on-screen caption fallback
(`VoiceLine.captionText`) only matters if a file is ever missing.

Each file is mono, 44.1kHz, 64kbps CBR mp3, peak-normalized to roughly
−1.6 to −2.3 dBFS (measured on the note sample library) to match loudness
across lines. Processing happens in a scratch dir outside the repo — the
source WAVs are never committed, only the final mp3.

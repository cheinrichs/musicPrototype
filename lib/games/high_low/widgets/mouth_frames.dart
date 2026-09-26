import 'package:flutter/material.dart';

/// Builds a character from the live pulse amplitude and mouth frame.
typedef MouthSpriteBuilder =
    Widget Function(BuildContext context, double amplitude, MouthFrame mouth);

/// The three mouth shapes a speaking character cycles through, driven by
/// the voice line's own loudness envelope (see `SpeakingPulse`) — the same
/// data that drives the scale pulse, so the two cues cannot drift apart.
enum MouthFrame { closed, open, wide }

/// Clef's three registered mouth frames, in [MouthFrame] order. Sliced and
/// aligned from the UI kit's `Clef_MouthFrames_3.png` by
/// `tool/slice_mouth_frames.py` so swapping between them never moves the
/// body — only the mouth (and a little of the face) changes.
const clefMouthFrameAssets = [
  'assets/images/characters/clef/clef_mouth_0.png',
  'assets/images/characters/clef/clef_mouth_1.png',
  'assets/images/characters/clef/clef_mouth_2.png',
];

/// Piper's three mouth frames — a stopgap cut from the rejected sheet; see
/// `CharacterArt.piper`.
const piperMouthFrameAssets = [
  'assets/images/characters/piper/piper_mouth_0.png',
  'assets/images/characters/piper/piper_mouth_1.png',
  'assets/images/characters/piper/piper_mouth_2.png',
];

// Each frame is entered above one threshold and only left below a lower
// one, so a loudness envelope hovering around a boundary holds a frame
// instead of fluttering between two at the envelope's own 30ms rate.
const _openAt = 0.20;
const _closeBelow = 0.10;
const _wideAt = 0.60;
const _openFromWideBelow = 0.50;

/// The frame to show for [amplitude] (0-1, the eased envelope value) given
/// the frame currently showing, with hysteresis — see the thresholds above.
MouthFrame nextMouthFrame(MouthFrame current, double amplitude) {
  switch (current) {
    case MouthFrame.closed:
      if (amplitude >= _wideAt) return MouthFrame.wide;
      if (amplitude >= _openAt) return MouthFrame.open;
      return MouthFrame.closed;
    case MouthFrame.open:
      if (amplitude >= _wideAt) return MouthFrame.wide;
      if (amplitude < _closeBelow) return MouthFrame.closed;
      return MouthFrame.open;
    case MouthFrame.wide:
      if (amplitude < _closeBelow) return MouthFrame.closed;
      if (amplitude < _openFromWideBelow) return MouthFrame.open;
      return MouthFrame.wide;
  }
}

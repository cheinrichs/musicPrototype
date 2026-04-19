import 'package:flutter/material.dart';

/// Instruments available in the Sound Playground
enum Instrument {
  piano('Piano', '🎹', Color(0xFF6C5CE7)),
  guitar('Guitar', '🎸', Color(0xFF00B894)),
  trumpet('Trumpet', '🎺', Color(0xFFE17055)),
  violin('Violin', '🎻', Color(0xFF74B9FF)),
  drums('Drums', '🥁', Color(0xFFFDCB6E));

  const Instrument(this.label, this.emoji, this.color);

  final String label;
  final String emoji;
  final Color color;

  /// Path to the pre-rendered melody clip for this instrument.
  /// Drop a 3–5 second .mp3 at this path to enable sound.
  String get assetPath => 'assets/audio/playground/$name.mp3';
}

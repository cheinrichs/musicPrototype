import 'dart:math';
import 'package:flutter/material.dart';

/// Instruments available in the Sound Playground
enum Instrument {
  piano('Piano', '🎹', Color(0xFF6C5CE7), ['assets/audio/playground/piano.mp3']),
  guitar('Guitar', '🎸', Color(0xFF00B894), [
    'assets/audio/playground/guitar1.mp3',
    'assets/audio/playground/guitar2.mp3',
    'assets/audio/playground/guitar3.mp3',
  ]),
  trumpet('Trumpet', '🎺', Color(0xFFE17055), ['assets/audio/playground/trumpet.mp3']),
  violin('Violin', '🎻', Color(0xFF74B9FF), ['assets/audio/playground/violin.mp3']),
  drums('Drums', '🥁', Color(0xFFFDCB6E), ['assets/audio/playground/drums.mp3']);

  const Instrument(this.label, this.emoji, this.color, this.assetPaths);

  final String label;
  final String emoji;
  final Color color;
  final List<String> assetPaths;

  String get randomAssetPath {
    if (assetPaths.length == 1) return assetPaths.first;
    return assetPaths[Random().nextInt(assetPaths.length)];
  }
}

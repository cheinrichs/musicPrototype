import 'dart:math';
import 'package:flutter/material.dart';

/// Instruments available in the Sound Playground
enum Instrument {
  piano(
    'Piano',
    '🎹',
    Color(0xFF6C5CE7),
    ['assets/audio/playground/piano.mp3'],
    artAssetPath: 'assets/images/characters/instruments/Piano1.png',
  ),
  guitar(
    'Guitar',
    '🎸',
    Color(0xFF00B894),
    [
      'assets/audio/playground/guitar1.mp3',
      'assets/audio/playground/guitar2.mp3',
      'assets/audio/playground/guitar3.mp3',
    ],
    artAssetPath: 'assets/images/characters/instruments/Guitar1.png',
  ),
  // No trumpet character exists in SongStone-UI-Kit/Assets/Cast/Instruments
  // yet (the kit has Bells, Cello, Drum, Flute, Guitar, Piano and Violin),
  // so this one still falls back to its emoji in the playground. Give it an
  // artAssetPath as soon as the art lands.
  trumpet(
    'Trumpet',
    '🎺',
    Color(0xFFE17055),
    ['assets/audio/playground/trumpet.mp3'],
  ),
  violin(
    'Violin',
    '🎻',
    Color(0xFF74B9FF),
    ['assets/audio/playground/violin.mp3'],
    artAssetPath: 'assets/images/characters/instruments/Violin1.png',
  ),
  drums(
    'Drums',
    '🥁',
    Color(0xFFFDCB6E),
    ['assets/audio/playground/drums.mp3'],
    artAssetPath: 'assets/images/characters/instruments/Drum1.png',
  );

  const Instrument(
    this.label,
    this.emoji,
    this.color,
    this.assetPaths, {
    this.artAssetPath,
  });

  final String label;
  final String emoji;
  final Color color;
  final List<String> assetPaths;

  /// Painted character art from the Lumi/SongStone UI kit, or null when the
  /// kit has no character for this instrument yet.
  final String? artAssetPath;

  String get randomAssetPath {
    if (assetPaths.length == 1) return assetPaths.first;
    return assetPaths[Random().nextInt(assetPaths.length)];
  }
}

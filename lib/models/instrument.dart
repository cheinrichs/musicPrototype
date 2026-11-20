import 'dart:math';
import 'package:flutter/material.dart';

import '../games/high_low/models/high_low_instrument.dart';
import '../games/high_low/models/instrument_sheets.dart';

/// Instruments available in the Sound Playground
enum Instrument {
  piano('Piano', '🎹', Color(0xFF6C5CE7), [
    'assets/audio/playground/piano.mp3',
  ]),
  guitar('Guitar', '🎸', Color(0xFF00B894), [
    'assets/audio/playground/guitar1.mp3',
    'assets/audio/playground/guitar2.mp3',
    'assets/audio/playground/guitar3.mp3',
  ]),
  // Trumpet character art (Trello card 53) — SongStone-UI-Kit's
  // Trumpet.png is a two-up sheet (silver / gold-brass); the gold one is
  // used here as the traditional, most recognizable trumpet finish.
  trumpet('Trumpet', '🎺', Color(0xFFE17055), [
    'assets/audio/playground/trumpet.mp3',
  ]),
  violin('Violin', '🎻', Color(0xFF74B9FF), [
    'assets/audio/playground/violin.mp3',
  ]),
  drums('Drums', '🥁', Color(0xFFFDCB6E), [
    'assets/audio/playground/drums.mp3',
  ]);

  const Instrument(this.label, this.emoji, this.color, this.assetPaths);

  final String label;
  final String emoji;
  final Color color;
  final List<String> assetPaths;

  /// Its painted art: the first (left) variant of Cooper's three-variant
  /// sheet (2026-11-20), as in the games.
  ///
  /// Electric guitar (Trello card 52) — the playground's guitar clips are
  /// electric, so the character matches; it has no three-variant sheet, so
  /// it keeps the red Strat-style one from SongStone-UI-Kit's two-up
  /// ElectricGuitar.png, which reads more clearly against the Meadow's
  /// greens than the blue.
  InstrumentLook get art => switch (this) {
    piano => instrumentSheets['piano']!.look(0),
    guitar => const InstrumentLook(
      'assets/images/characters/instruments/ElectricGuitar1.png',
    ),
    trumpet => instrumentSheets['trumpet']!.look(0),
    violin => instrumentSheets['violin']!.look(0),
    drums => instrumentSheets['drum']!.look(0),
  };

  String get randomAssetPath {
    if (assetPaths.length == 1) return assetPaths.first;
    return assetPaths[Random().nextInt(assetPaths.length)];
  }
}

import 'dart:io';

import 'package:ear_trainer/audio/drum_hit.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:flutter_test/flutter_test.dart';

/// The drum is unpitched: a few hits, never a note library.
void main() {
  test('every hit is a real file', () {
    for (final hit in DrumHit.values) {
      expect(File(hit.assetPath).existsSync(), isTrue, reason: hit.name);
    }
  });

  test('THE DRUM IS NOT A PITCHED INSTRUMENT: it is in no note library and '
      'never in HighLowInstrument', () {
    expect(
      HighLowInstrument.values.map((i) => i.sampleInstrument),
      isNot(contains(anyOf('drum', 'drums', 'percussion'))),
    );
    for (final hit in DrumHit.values) {
      expect(hit.assetPath, isNot(contains('/notes/')));
    }
  });
}

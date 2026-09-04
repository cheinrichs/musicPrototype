import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/services/cross_instrument_pairing.dart';

void main() {
  group('CrossInstrumentPairing', () {
    test('instrumentsCanPair matches HighLowInstrument.canPairWith', () {
      final pairing = CrossInstrumentPairing();
      expect(
        pairing.instrumentsCanPair(
          HighLowInstrument.tuba,
          HighLowInstrument.flute,
          minSemitones: 2,
        ),
        isFalse,
      );
      expect(
        pairing.instrumentsCanPair(
          HighLowInstrument.piano,
          HighLowInstrument.guitar,
          minSemitones: 2,
        ),
        isTrue,
      );
    });

    test('generatePair throws when the instruments cannot pair at the '
        'requested interval — same spirit as the same-instrument '
        'invariant test in prompt_generator_test.dart, but for the '
        'cross-instrument rule instead', () {
      final pairing = CrossInstrumentPairing();
      expect(
        () => pairing.generatePair(
          HighLowInstrument.tuba,
          HighLowInstrument.flute,
          minSemitones: 2,
          maxSemitones: 4,
        ),
        throwsStateError,
      );
    });

    test('every generated pair falls within the requested interval, for '
        'every legally-pairable combination of instruments', () {
      final pairing = CrossInstrumentPairing(random: Random(42));
      const minSemitones = 2;
      const maxSemitones = 7;

      for (final a in HighLowInstrument.values) {
        for (final b in HighLowInstrument.values) {
          if (a == b) continue;
          if (!a.canPairWith(b, minSemitones: minSemitones)) continue;

          for (var i = 0; i < 20; i++) {
            final pair = pairing.generatePair(
              a,
              b,
              minSemitones: minSemitones,
              maxSemitones: maxSemitones,
            );
            final interval = (pair.aMidi - pair.bMidi).abs();
            expect(
              interval,
              greaterThanOrEqualTo(minSemitones),
              reason:
                  '$a/$b pair $i had interval $interval, below the '
                  'requested minimum',
            );
            expect(
              interval,
              lessThanOrEqualTo(maxSemitones),
              reason:
                  '$a/$b pair $i had interval $interval, above the '
                  'requested maximum',
            );
            // Both notes must actually be playable on their instrument.
            expect(
              pair.aMidi,
              inInclusiveRange(a.lowestSampleMidi, a.highestSampleMidi),
            );
            expect(
              pair.bMidi,
              inInclusiveRange(b.lowestSampleMidi, b.highestSampleMidi),
            );
          }
        }
      }
    });

    test('across many samples, each instrument in a legal pairing '
        'sometimes lands as the higher note — "X means low" must never '
        'be a guaranteed winning strategy', () {
      final pairing = CrossInstrumentPairing(random: Random(7));
      const a = HighLowInstrument.piano;
      const b = HighLowInstrument.guitar;
      expect(a.canPairWith(b, minSemitones: 2), isTrue);

      var aHigherCount = 0;
      var bHigherCount = 0;
      for (var i = 0; i < 200; i++) {
        final pair = pairing.generatePair(
          a,
          b,
          minSemitones: 2,
          maxSemitones: 7,
        );
        if (pair.aMidi > pair.bMidi) {
          aHigherCount++;
        } else {
          bHigherCount++;
        }
      }

      expect(aHigherCount, greaterThan(0));
      expect(bHigherCount, greaterThan(0));
    });
  });
}

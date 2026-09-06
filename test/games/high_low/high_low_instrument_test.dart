import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';

void main() {
  group('HighLowInstrument range', () {
    test('assetPathForMidi resolves to the real-pitch filename', () {
      expect(
        HighLowInstrument.piano.assetPathForMidi(60), // C4
        'assets/audio/notes/piano/c4.mp3',
      );
      expect(
        HighLowInstrument.piano.assetPathForMidi(61), // C#4
        'assets/audio/notes/piano/c_sharp_4.mp3',
      );
      // Tuba's range is real C2-B3 (36-59) — a MIDI value outside a
      // standard instrument's C4-B5 shape, exactly the case the old
      // Note-enum-keyed lookup couldn't represent.
      expect(
        HighLowInstrument.tuba.assetPathForMidi(36), // C2
        'assets/audio/notes/tuba/c2.mp3',
      );
    });

    test('allAssetPaths covers exactly lowestSampleMidi..highestSampleMidi '
        'for a gap-free instrument', () {
      final tuba = HighLowInstrument.tuba;
      final expectedCount = tuba.highestSampleMidi - tuba.lowestSampleMidi + 1;
      expect(tuba.allAssetPaths.length, expectedCount);
      expect(tuba.allAssetPaths.first, 'assets/audio/notes/tuba/c2.mp3');
      expect(tuba.allAssetPaths.last, 'assets/audio/notes/tuba/b3.mp3');
    });

    test(
      'allAssetPaths skips missingMidis for a gapped instrument (guitar)',
      () {
        final guitar = HighLowInstrument.guitar;
        final expectedCount =
            guitar.highestSampleMidi -
            guitar.lowestSampleMidi +
            1 -
            guitar.missingMidis.length;
        expect(guitar.allAssetPaths.length, expectedCount);
        expect(
          guitar.allAssetPaths,
          isNot(contains('assets/audio/notes/guitar/a3.mp3')),
        );
        expect(
          guitar.allAssetPaths,
          isNot(contains('assets/audio/notes/guitar/a_sharp_4.mp3')),
        );
        // The two 2026-09 restorations are in there.
        expect(
          guitar.allAssetPaths,
          contains('assets/audio/notes/guitar/f_sharp_3.mp3'),
        );
        expect(
          guitar.allAssetPaths,
          contains('assets/audio/notes/guitar/g_sharp_3.mp3'),
        );
      },
    );

    test('semitoneOverlapWith is the full range for an instrument with '
        'itself', () {
      for (final instrument in HighLowInstrument.values) {
        final fullSpan =
            instrument.highestSampleMidi - instrument.lowestSampleMidi;
        expect(instrument.semitoneOverlapWith(instrument), fullSpan);
      }
    });

    test('tuba and flute never overlap — their ranges are two octaves '
        'apart with a gap between', () {
      final overlap = HighLowInstrument.tuba.semitoneOverlapWith(
        HighLowInstrument.flute,
      );
      expect(overlap, lessThan(0));
      expect(
        HighLowInstrument.tuba.canPairWith(
          HighLowInstrument.flute,
          minSemitones: 2,
        ),
        isFalse,
      );
    });

    test('piano and guitar overlap enough to pair at a small interval '
        '(unlike tuba/flute above, which never can)', () {
      expect(
        HighLowInstrument.piano.canPairWith(
          HighLowInstrument.guitar,
          minSemitones: 2,
        ),
        isTrue,
      );
    });

    test('tuba pairs with guitar now that its C#3 gap is closed (real '
        'C2-B3 reaches guitar\'s real C3-B4 bottom end), but with nothing '
        'else — every other instrument starts at C4, one semitone above '
        'tuba\'s own top note', () {
      expect(
        HighLowInstrument.tuba.canPairWith(
          HighLowInstrument.guitar,
          minSemitones: 2,
        ),
        isTrue,
      );
      for (final other in HighLowInstrument.values) {
        if (other == HighLowInstrument.tuba ||
            other == HighLowInstrument.guitar) {
          continue;
        }
        expect(
          HighLowInstrument.tuba.canPairWith(other, minSemitones: 2),
          isFalse,
          reason:
              'tuba unexpectedly pairs with $other now — '
              'if a range was corrected, this test (and the class doc '
              'comment about tuba only pairing with guitar) may need '
              'updating',
        );
      }
    });

    test('canPairWith requires the full requested interval, not just any '
        'overlap', () {
      final overlap = HighLowInstrument.piano.semitoneOverlapWith(
        HighLowInstrument.guitar,
      );
      expect(
        HighLowInstrument.piano.canPairWith(
          HighLowInstrument.guitar,
          minSemitones: overlap + 1,
        ),
        isFalse,
      );
      expect(
        HighLowInstrument.piano.canPairWith(
          HighLowInstrument.guitar,
          minSemitones: overlap,
        ),
        isTrue,
      );
    });
  });
}

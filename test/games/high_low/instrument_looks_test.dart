import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'dart:math' as math;

import 'package:ear_trainer/games/high_low/models/high_low_instrument.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/pitch_direction.dart';
import 'package:ear_trainer/games/loud_quiet/models/dynamic_ladder.dart';
import 'package:flutter_test/flutter_test.dart';

/// An instrument's LOOKS (Cooper, 2026-11-14): one instrument on three
/// platforms must be three tellable-apart sprites. Appearance only.
void main() {
  group('the handbell sheet', () {
    late ByteData pixels;
    late int width, height;

    setUpAll(() async {
      final bytes = File(
        'assets/images/characters/instruments/bells_x3_variants.png',
      ).readAsBytesSync();
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final image = (await codec.getNextFrame()).image;
      width = image.width;
      height = image.height;
      pixels = (await image.toByteData())!;
    });

    bool visible(int x, int y) => pixels.getUint8((y * width + x) * 4 + 3) > 8;

    test('each slice holds its whole bell and nothing of a neighbour', () {
      final looks = HighLowInstrument.bells.lookSets[1];
      expect(looks, hasLength(3));
      for (var i = 0; i < 3; i++) {
        final r = looks[i].region!;
        expect(r.sheetWidth, width);
        expect(r.sheetHeight, height);
        // Visible pixels in this bell's column band (between the gutters)
        // all fall inside its slice…
        final bandLeft = i == 0
            ? 0
            : ((looks[i - 1].region!.left + 460 + r.left) / 2).floor();
        final bandRight = i == 2
            ? width
            : ((r.left + 460 + looks[i + 1].region!.left) / 2).floor();
        for (var y = 0; y < height; y++) {
          for (var x = bandLeft; x < bandRight; x++) {
            if (!visible(x, y)) continue;
            expect(
              x >= r.left &&
                  x < r.left + r.width &&
                  y >= r.top &&
                  y < r.top + r.height,
              isTrue,
              reason: 'bell $i clipped at ($x, $y)',
            );
          }
        }
        // …and nothing outside the band falls inside it.
        for (var y = r.top.toInt(); y < (r.top + r.height).toInt(); y++) {
          for (var x = r.left.toInt(); x < (r.left + r.width).toInt(); x++) {
            if (x < bandLeft || x >= bandRight) {
              expect(
                visible(x, y),
                isFalse,
                reason: 'bell $i catches a neighbour',
              );
            }
          }
        }
      }
    });
  });

  test('one instrument on THREE positions: three different looks, where '
      'the art has them — the bells', () {
    final looks = HighLowInstrument.looksForRound(
      List.filled(3, HighLowInstrument.bells),
    );
    expect(looks.toSet(), hasLength(3));
    expect(HighLowInstrument.bells.hasDistinctLooksFor(3), isTrue);
  });

  test('two positions keep their familiar pair — nothing changes there', () {
    for (final i in HighLowInstrument.values.where((i) => !i.isTrial)) {
      expect(i.looksFor(2).map((l) => l.asset), [
        i.leftAssetPath,
        i.rightAssetPath,
      ]);
    }
  });

  test('built generally: an instrument without a third look repeats its '
      'pair in order (until Cooper supplies more), never crashes', () {
    final looks = HighLowInstrument.looksForRound(
      List.filled(3, HighLowInstrument.cello),
    );
    expect(looks.map((l) => l.asset), [
      HighLowInstrument.cello.leftAssetPath,
      HighLowInstrument.cello.rightAssetPath,
      HighLowInstrument.cello.leftAssetPath,
    ]);
    expect(HighLowInstrument.cello.hasDistinctLooksFor(3), isFalse);
  });

  test('two instruments in one round each keep their own looks apart', () {
    final looks = HighLowInstrument.looksForRound([
      HighLowInstrument.flute,
      HighLowInstrument.piano,
      HighLowInstrument.flute,
    ]);
    expect(looks.map((l) => l.asset), [
      HighLowInstrument.flute.leftAssetPath,
      HighLowInstrument.piano.leftAssetPath,
      HighLowInstrument.flute.rightAssetPath,
    ]);
  });

  test('LOOKS NEVER TOUCH ELIGIBILITY: which instruments play a Loud or '
      'Quiet step is the room rule alone — bells with three looks are in '
      'exactly the steps their headroom reaches', () {
    const ladder = DynamicLadder.standard;
    for (var step = 0; step < ladder.length; step++) {
      expect(ladder.eligibleAt(step), [
        for (final i in DynamicLadder.poolFor(ladder.instrumentCountAt(step)))
          if (ladder.headroomOf(i) >= ladder.loudDbAt(step)) i,
      ]);
    }
    // Three-instrument rounds still leave the bells out (their half-size
    // art, not their looks).
    expect(DynamicLadder.poolFor(3), isNot(contains(HighLowInstrument.bells)));
  });

  group('the xylophone: a TRIAL instrument, dev profile only', () {
    tearDown(() => HighLowInstrument.trialsEnabled = false);

    test('OUT of every pool unless trials are on — a child never meets it', () {
      HighLowInstrument.trialsEnabled = false;
      expect(
        HighLowInstrument.inPlay,
        isNot(contains(HighLowInstrument.xylophone)),
      );
      expect(
        DynamicLadder.poolFor(2),
        isNot(contains(HighLowInstrument.xylophone)),
      );
      HighLowInstrument.trialsEnabled = true;
      expect(HighLowInstrument.inPlay, contains(HighLowInstrument.xylophone));
      expect(DynamicLadder.poolFor(2), contains(HighLowInstrument.xylophone));
    });

    test("two distinct looks, both slices of Cooper's UI-Kit sheet", () {
      final looks = HighLowInstrument.xylophone.looksFor(2);
      expect(looks.toSet(), hasLength(2));
      for (final l in looks) {
        expect(l.asset, 'assets/images/characters/instruments/Xylophone.png');
        expect(l.region, isNotNull);
      }
    });

    test(
      'each slice holds its whole xylophone and nothing of the other',
      () async {
        final bytes = File(
          'assets/images/characters/instruments/Xylophone.png',
        ).readAsBytesSync();
        final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
        final image = (await codec.getNextFrame()).image;
        final px = (await image.toByteData())!;
        bool visible(int x, int y) =>
            px.getUint8((y * image.width + x) * 4 + 3) > 8;
        final looks = HighLowInstrument.xylophone.looksFor(2);
        const half = 887; // the gap between the two runs 867-907
        for (var i = 0; i < 2; i++) {
          final r = looks[i].region!;
          for (var y = 0; y < image.height; y += 2) {
            for (
              var x = i == 0 ? 0 : half;
              x < (i == 0 ? half : image.width);
              x += 2
            ) {
              if (!visible(x, y)) continue;
              expect(
                x >= r.left &&
                    x < r.left + r.width &&
                    y >= r.top &&
                    y < r.top + r.height,
                isTrue,
                reason: 'xylophone $i clipped at ($x, $y)',
              );
            }
          }
        }
      },
    );

    test('with trials on, both games generate rounds with it, and Loud or '
        "Quiet keeps it to the levels its +0.5 dB room allows", () {
      HighLowInstrument.trialsEnabled = true;
      final generator = PromptGenerator(random: math.Random(7));
      var seen = false;
      for (final tier in ConceptTier.values) {
        for (var i = 0; i < 150; i++) {
          final p = generator.generatePrompt(
            promptNumber: i,
            tier: tier,
            targetDirection: PitchDirection.higher,
          );
          if (p.firstInstrument == HighLowInstrument.xylophone) seen = true;
        }
      }
      expect(seen, isTrue);
      const ladder = DynamicLadder.standard;
      for (var step = 0; step < ladder.length; step++) {
        expect(
          ladder.eligibleAt(step).contains(HighLowInstrument.xylophone),
          ladder.instrumentCountAt(step) >= 2 && ladder.loudDbAt(step) <= 0.5,
          reason: 'T${step + 1}',
        );
      }
    });
  });
}

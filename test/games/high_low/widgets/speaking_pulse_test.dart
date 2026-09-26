import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/audio/voice_envelope.dart';
import 'package:ear_trainer/games/high_low/widgets/mouth_frames.dart';
import 'package:ear_trainer/games/high_low/widgets/speaking_pulse.dart';

void main() {
  setUp(() => VoiceEnvelopeLibrary.debugSetCache(null));
  tearDown(() => VoiceEnvelopeLibrary.debugSetCache(null));

  Future<void> pump(
    WidgetTester tester, {
    required bool speaking,
    required String? line,
    required int generation,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SpeakingPulse(
            speaking: speaking,
            line: line,
            generation: generation,
            child: const SizedBox(width: 40, height: 80),
          ),
        ),
      ),
    );
  }

  double scaleOf(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(SpeakingPulse),
        matching: find.byType(Transform),
      ),
    );
    // Uniform scale about (0,0,0) in x/y — read the x scale factor.
    return transform.transform.getMaxScaleOnAxis();
  }

  testWidgets('a silent character stays at scale 1 with nothing running', (
    tester,
  ) async {
    await pump(tester, speaking: false, line: null, generation: 0);
    await tester.pump(const Duration(seconds: 1));

    expect(scaleOf(tester), 1.0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'with no envelope loaded, a speaking character still pulses (a flat '
    'fallback) rather than doing nothing',
    (tester) async {
      await pump(tester, speaking: true, line: 'unknownLine', generation: 1);
      await tester.pump(const Duration(milliseconds: 500));

      expect(scaleOf(tester), greaterThan(1.0));
    },
  );

  testWidgets(
    'follows the envelope: grows on the loud block and settles back down '
    'in the quiet block that follows it',
    (tester) async {
      VoiceEnvelopeLibrary.debugSetCache({
        'loudThenQuiet': const VoiceEnvelope(
          hopMs: 30,
          samples: [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        ),
      });
      await pump(
        tester,
        speaking: true,
        line: 'loudThenQuiet',
        generation: 1,
      );

      await tester.pump(const Duration(milliseconds: 150));
      final loud = scaleOf(tester);
      expect(loud, greaterThan(1.0));

      await tester.pump(const Duration(milliseconds: 300));
      final quiet = scaleOf(tester);
      expect(
        quiet,
        lessThan(loud),
        reason: 'must ease back down once the envelope goes quiet',
      );
    },
  );

  testWidgets(
    'the pulse amplitude stays small — well under the scale the playing '
    'instrument itself uses, so it never fights the scene\'s depth cue',
    (tester) async {
      VoiceEnvelopeLibrary.debugSetCache({
        'loud': const VoiceEnvelope(hopMs: 30, samples: [1.0, 1.0, 1.0, 1.0]),
      });
      await pump(tester, speaking: true, line: 'loud', generation: 1);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        scaleOf(tester),
        lessThan(1.10),
        reason: 'the instrument-playing pulse already uses ~1.12',
      );
    },
  );

  testWidgets(
    'a new line starting resets the elapsed clock even when the same '
    'character keeps speaking — generation change, not just line change',
    (tester) async {
      // "first" is silent for its whole 600ms; "second" is loud for its
      // whole 600ms. If the clock is *not* reset on the generation change,
      // the elapsed time carried over from "first" already exceeds
      // "second"'s own duration the moment it starts, so amplitudeAt reads
      // as "past the end" (silent) for all of it — the pulse would stay at
      // rest through both lines. Only a genuine reset lets it reach
      // "second"'s loud content.
      VoiceEnvelopeLibrary.debugSetCache({
        'first': VoiceEnvelope(hopMs: 30, samples: List.filled(20, 0.0)),
        'second': VoiceEnvelope(hopMs: 30, samples: List.filled(20, 1.0)),
      });

      await pump(tester, speaking: true, line: 'first', generation: 1);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(
        scaleOf(tester),
        closeTo(1.0, 0.005),
        reason: "first's envelope is silent throughout",
      );

      await pump(tester, speaking: true, line: 'second', generation: 2);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(
        scaleOf(tester),
        greaterThan(1.0 + SpeakingPulse.maxScaleDelta * 0.7),
        reason:
            "second's envelope is loud throughout, so a reset clock should "
            "have driven the pulse close to its max by now — anything low "
            "means the elapsed time kept running against first's timeline "
            "instead of resetting",
      );
    },
  );

  testWidgets('eases to rest and stops running once the line ends', (
    tester,
  ) async {
    VoiceEnvelopeLibrary.debugSetCache({
      'loud': const VoiceEnvelope(hopMs: 30, samples: [1.0, 1.0, 1.0, 1.0]),
    });
    await pump(tester, speaking: true, line: 'loud', generation: 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    await pump(tester, speaking: false, line: 'loud', generation: 1);
    // Several settling ticks.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(scaleOf(tester), closeTo(1.0, 0.001));
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('SpeakingPulse.builder — the mouth follows the same envelope', () {
    Future<void> pumpBuilder(
      WidgetTester tester, {
      required bool speaking,
      required String? line,
      required List<MouthFrame> seen,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: SpeakingPulse.builder(
            speaking: speaking,
            line: line,
            generation: 1,
            builder: (context, amplitude, mouth) {
              seen.add(mouth);
              return const SizedBox(width: 40, height: 80);
            },
          ),
        ),
      );
    }

    testWidgets('a loud envelope opens the mouth wide; silence closes it',
        (tester) async {
      VoiceEnvelopeLibrary.debugSetCache({
        'loud': VoiceEnvelope(hopMs: 30, samples: List.filled(30, 1.0)),
      });
      final seen = <MouthFrame>[];
      await pumpBuilder(tester, speaking: true, line: 'loud', seen: seen);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(seen.last, MouthFrame.wide);

      await pumpBuilder(tester, speaking: false, line: 'loud', seen: seen);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(seen.last, MouthFrame.closed);
    });

    testWidgets(
      'the mouth and the scale pulse are driven by one amplitude — a '
      'quiet stretch closes the mouth at the same time the pulse settles',
      (tester) async {
        VoiceEnvelopeLibrary.debugSetCache({
          'loudThenQuiet': VoiceEnvelope(
            hopMs: 30,
            samples: [...List.filled(15, 1.0), ...List.filled(30, 0.0)],
          ),
        });
        final seen = <MouthFrame>[];
        await pumpBuilder(
          tester,
          speaking: true,
          line: 'loudThenQuiet',
          seen: seen,
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(seen.last, MouthFrame.wide, reason: 'during the loud part');

        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(seen.last, MouthFrame.closed, reason: 'after it goes quiet');
      },
    );
  });
}

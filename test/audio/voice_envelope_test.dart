import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/audio/voice_envelope.dart';

void main() {
  group('VoiceEnvelope', () {
    test('interpolates linearly between samples', () {
      const env = VoiceEnvelope(hopMs: 30, samples: [0.0, 1.0, 0.0]);
      expect(env.amplitudeAt(Duration.zero), 0.0);
      expect(env.amplitudeAt(const Duration(milliseconds: 15)), closeTo(0.5, 1e-9));
      expect(env.amplitudeAt(const Duration(milliseconds: 30)), closeTo(1.0, 1e-9));
      expect(env.amplitudeAt(const Duration(milliseconds: 45)), closeTo(0.5, 1e-9));
      expect(env.amplitudeAt(const Duration(milliseconds: 60)), closeTo(0.0, 1e-9));
    });

    test('is silent before start and once past the last sample', () {
      const env = VoiceEnvelope(hopMs: 30, samples: [0.4, 0.8]);
      expect(env.amplitudeAt(const Duration(milliseconds: -5)), 0.0);
      expect(env.amplitudeAt(const Duration(seconds: 5)), 0.0);
    });

    test('an empty envelope is always silent, never throws', () {
      const env = VoiceEnvelope(hopMs: 30, samples: []);
      expect(env.amplitudeAt(Duration.zero), 0.0);
      expect(env.amplitudeAt(const Duration(seconds: 1)), 0.0);
    });

    test('duration is hopMs * sample count', () {
      const env = VoiceEnvelope(hopMs: 25, samples: [0, 0, 0, 0]);
      expect(env.duration, const Duration(milliseconds: 100));
    });
  });

  group('VoiceEnvelopeLibrary', () {
    setUp(() => VoiceEnvelopeLibrary.debugSetCache(null));
    tearDown(() => VoiceEnvelopeLibrary.debugSetCache(null));

    test('a synchronous lookup before anything is loaded returns null, '
        'never throws', () {
      expect(VoiceEnvelopeLibrary.envelopeForSync('giveMeHigh'), isNull);
    });

    test('once injected, a sync lookup returns the matching envelope by '
        "the line's asset name, and null for one that has none", () {
      const env = VoiceEnvelope(hopMs: 30, samples: [0.1, 0.9]);
      VoiceEnvelopeLibrary.debugSetCache({'giveMeHigh': env});

      expect(VoiceEnvelopeLibrary.envelopeForSync('giveMeHigh'), same(env));
      expect(VoiceEnvelopeLibrary.envelopeForSync('giveMeLow'), isNull);
    });
  });
}

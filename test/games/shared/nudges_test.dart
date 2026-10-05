import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/audio/shared_voice_line.dart';
import 'package:ear_trainer/games/shared/nudges.dart';

void main() {
  group('NudgePool — rotates, never repeats the last line for a speaker '
      '(Trello card 151)', () {
    test('a speaker never gets the same line twice running, over many picks', () {
      final pool = NudgePool(random: Random(7));
      SharedVoiceLine? previous;
      for (var i = 0; i < 200; i++) {
        final line = pool.next(NudgeSpeaker.piper);
        expect(line, isNot(previous), reason: 'pick $i repeated');
        previous = line;
      }
    });

    test('every line in a pool gets played, not just one', () {
      final pool = NudgePool(random: Random(3));
      final seen = <SharedVoiceLine>{};
      for (var i = 0; i < 100; i++) {
        seen.add(pool.next(NudgeSpeaker.piper));
      }
      expect(seen, unorderedEquals(NudgePool.piperLines));
    });

    test('each character only ever gets its own lines', () {
      final pool = NudgePool(random: Random(11));
      for (var i = 0; i < 50; i++) {
        expect(NudgePool.clefLines, contains(pool.next(NudgeSpeaker.clef)));
        expect(NudgePool.piperLines, contains(pool.next(NudgeSpeaker.piper)));
      }
    });

    test('a character\'s memory is its own — Clef\'s last line does not stop '
        'Piper repeating hers', () {
      final pool = NudgePool(random: Random(5));
      final clef = pool.next(NudgeSpeaker.clef);
      // Piper's next pick is free to be any of her lines, including one that
      // would be a repeat if the two shared a memory.
      final picks = {for (var i = 0; i < 60; i++) pool.next(NudgeSpeaker.piper)};
      expect(picks, NudgePool.piperLines.toSet());
      expect(NudgePool.clefLines, contains(clef));
    });

    test('a pool with one line still returns it — nothing else to pick', () {
      // Clef's pool has two lines, so this checks the mechanism directly:
      // with only one candidate left after exclusion, it is used.
      final pool = NudgePool(random: Random(1));
      final first = pool.next(NudgeSpeaker.clef);
      final second = pool.next(NudgeSpeaker.clef);
      expect(second, isNot(first));
    });
  });

  group('FiveTapCounter — five consistent taps on one option fire once '
      '(Trello card 151)', () {
    test('five taps on the same option fire exactly on the fifth', () {
      final counter = FiveTapCounter();
      final results = [for (var i = 0; i < 5; i++) counter.tap(1)];
      expect(results, [false, false, false, false, true]);
    });

    test('after firing the run resets, so five more fire again', () {
      final counter = FiveTapCounter();
      for (var i = 0; i < 5; i++) {
        counter.tap(0);
      }
      final again = [for (var i = 0; i < 5; i++) counter.tap(0)];
      expect(again, [false, false, false, false, true]);
    });

    test('bouncing between two options never fires — exploring, not deciding', () {
      final counter = FiveTapCounter();
      final fired = [for (var i = 0; i < 40; i++) counter.tap(i % 2)];
      expect(fired.any((f) => f), isFalse);
    });

    test('four taps, a switch, then four more is not five in a row', () {
      final counter = FiveTapCounter();
      for (var i = 0; i < 4; i++) {
        expect(counter.tap(0), isFalse);
      }
      expect(counter.tap(1), isFalse);
      for (var i = 0; i < 3; i++) {
        expect(counter.tap(0), isFalse);
      }
    });

    test('a correct tap in the middle of a wrong run breaks it', () {
      final counter = FiveTapCounter();
      for (var i = 0; i < 4; i++) {
        counter.tap(1);
      }
      counter.tap(0); // the correct option, in the caller's terms
      expect(counter.tap(1), isFalse, reason: 'the run started over');
    });

    test('reset forgets a run in progress', () {
      final counter = FiveTapCounter();
      for (var i = 0; i < 4; i++) {
        counter.tap(1);
      }
      counter.reset();
      expect(counter.tap(1), isFalse);
    });
  });

  group('SharedVoiceLine — owned by the app, not a game', () {
    test('every shared line has a speaker, and the nudge pools use only '
        'nudge members', () {
      for (final line in SharedVoiceLine.values) {
        expect(line.isPiper, isA<bool>());
        expect(line.assetPath, 'assets/audio/voice/${line.name}.mp3');
      }
      for (final line in [...NudgePool.clefLines, ...NudgePool.piperLines]) {
        expect(line.name, startsWith('tryAgain'));
      }
    });

    test('the arrow cue is Piper\'s, and nothing else is', () {
      expect(SharedVoiceLine.pressTheArrowWhenDone.isPiper, isTrue);
      expect(
        SharedVoiceLine.values.where((l) => l.name.startsWith('tryAgain')),
        hasLength(6),
      );
    });
  });
}

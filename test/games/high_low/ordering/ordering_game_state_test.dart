import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_game_state.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/game_status.dart';

/// Three notes (T5) or two (T1), from a fixed seed so the round is known.
OrderingGameState make({
  ConceptTier tier = ConceptTier.t5,
  int totalPrompts = 3,
  List<String>? played,
  int seed = 1,
}) => OrderingGameState(
  tier: tier,
  totalPrompts: totalPrompts,
  generator: PromptGenerator(random: Random(seed)),
  playNote: played == null ? null : (path) async => played.add(path),
);

/// Skip past the opening playback.
Future<void> finishIntro(WidgetTester tester, OrderingGameState s) async {
  await tester.pump();
  await tester.pump(OrderingGameState.noteGap * 4);
}

/// Drop every note onto its own slot per [slotOf] (note index -> slot).
void placeAll(OrderingGameState s, List<int> slotOf) {
  for (var note = 0; note < slotOf.length; note++) {
    expect(s.dropOnSlot(note, slotOf[note]), isTrue, reason: 'note $note');
  }
}

Iterable<List<int>> permutations(int n) sync* {
  Iterable<List<int>> go(List<int> rest, List<int> chosen) sync* {
    if (rest.isEmpty) {
      yield chosen;
      return;
    }
    for (final x in rest) {
      yield* go([...rest]..remove(x), [...chosen, x]);
    }
  }

  yield* go([for (var i = 0; i < n; i++) i], []);
}

void main() {
  group('OrderingGameState', () {
    testWidgets('an instrument sounds as it lands — the exact sample for that '
        'instrument and pitch', (tester) async {
      final played = <String>[];
      final s = make(played: played)..startGame();
      await finishIntro(tester, s);
      played.clear();

      final note = s.round!.notes[1];
      expect(s.dropOnSlot(1, 2), isTrue);

      expect(played, [note.instrument.assetPathForMidi(note.midi)]);
      s.dispose();
    });

    testWidgets('nothing is evaluated until every slot is filled — no ticks, '
        'no returns, however long the child waits', (tester) async {
      final s = make()..startGame();
      await finishIntro(tester, s);

      s.dropOnSlot(0, 0);
      s.dropOnSlot(1, 1);
      await tester.pump(const Duration(seconds: 10));

      expect(s.lockedNotes, isEmpty);
      expect(s.evaluations, 0);
      expect(s.returnedNotes, isEmpty);
      expect(s.placements.length, 2);
      s.dispose();
    });

    testWidgets('a perfect ordering locks every instrument and completes '
        'the round, then moves on', (tester) async {
      final s = make()..startGame();
      await finishIntro(tester, s);

      placeAll(s, [for (var n = 0; n < 3; n++) s.round!.correctSlotOf(n)]);
      await tester.pump(OrderingGameState.evaluateDelay);

      expect(s.lockedNotes, {0, 1, 2});
      expect(s.returnedNotes, isEmpty);
      expect(s.status, GameStatus.showingFeedback);

      await tester.pump(OrderingGameState.celebrateFor);
      expect(s.currentPromptIndex, 1);
      expect(s.placements, isEmpty, reason: 'a fresh round starts clean');
      expect(s.lockedNotes, isEmpty);
      s.dispose();
    });

    testWidgets('three items can only score 3, 1 or 0 — every possible first '
        'placement, played through the real state, never leaves exactly two '
        'locked', (tester) async {
      final outcomes = <int>{};
      for (final perm in permutations(3)) {
        final s = make()..startGame();
        await finishIntro(tester, s);
        // perm[note] = slot the note is dropped on (any bijection).
        placeAll(s, perm);
        await tester.pump(OrderingGameState.evaluateDelay);
        outcomes.add(s.lockedNotes.length);
        s.dispose();
      }
      expect(outcomes, {0, 1, 3});
    });

    testWidgets('wrong placements go back to their stumps and their slots '
        'free up; right ones stay put', (tester) async {
      final s = make()..startGame();
      await finishIntro(tester, s);
      final right = [for (var n = 0; n < 3; n++) s.round!.correctSlotOf(n)];
      // Note 0 right; swap the other two.
      placeAll(s, [right[0], right[2], right[1]]);
      final serialBefore = s.returnSerial;
      await tester.pump(OrderingGameState.evaluateDelay);

      expect(s.lockedNotes, {0});
      expect(s.returnedNotes, {1, 2});
      expect(s.placements, {0: right[0]}, reason: 'only the locked one stays');
      expect(s.returnedFrom, {
        1: right[2],
        2: right[1],
      }, reason: 'each went back from the slot it stood on');
      expect(s.returnSerial, greaterThan(serialBefore));
      expect(s.status, isNot(GameStatus.showingFeedback));
      s.dispose();
    });

    testWidgets('after a return, the child can place the two again and finish '
        'the round', (tester) async {
      final s = make()..startGame();
      await finishIntro(tester, s);
      final right = [for (var n = 0; n < 3; n++) s.round!.correctSlotOf(n)];
      placeAll(s, [right[0], right[2], right[1]]);
      await tester.pump(OrderingGameState.evaluateDelay);

      expect(s.dropOnSlot(1, right[1]), isTrue);
      expect(s.dropOnSlot(2, right[2]), isTrue);
      await tester.pump(OrderingGameState.evaluateDelay);

      expect(s.lockedNotes, {0, 1, 2});
      expect(s.status, GameStatus.showingFeedback);
      s.dispose();
    });

    testWidgets('a locked instrument cannot be lifted or moved, and an '
        'occupied or unused slot refuses a drop', (tester) async {
      final s = make(tier: ConceptTier.t1)..startGame();
      await finishIntro(tester, s);
      final r = s.round!;

      expect(s.dropOnSlot(0, 2), isFalse, reason: 'bottom slot is unused');
      expect(s.dropOnSlot(0, r.correctSlotOf(0)), isTrue);
      expect(s.dropOnSlot(1, r.correctSlotOf(0)), isFalse, reason: 'occupied');

      s.dropOnSlot(1, r.correctSlotOf(1));
      await tester.pump(OrderingGameState.evaluateDelay);
      expect(s.lockedNotes, {0, 1});
      s.lift(0);
      expect(s.placements.containsKey(0), isTrue, reason: 'locked stays');
      s.dispose();
    });

    testWidgets('lifting an instrument before the check cancels it', (
      tester,
    ) async {
      final s = make()..startGame();
      await finishIntro(tester, s);
      placeAll(s, [0, 1, 2]);
      await tester.pump(OrderingGameState.evaluateDelay ~/ 2);

      s.lift(1);
      await tester.pump(OrderingGameState.evaluateDelay * 3);

      expect(s.evaluations, 0);
      expect(s.placements.length, 2);
      s.dispose();
    });

    testWidgets('a two-note round fills two slots and checks then', (
      tester,
    ) async {
      final s = make(tier: ConceptTier.t1)..startGame();
      await finishIntro(tester, s);
      final r = s.round!;
      expect(r.notes.length, 2);

      s.dropOnSlot(0, r.correctSlotOf(0));
      await tester.pump(const Duration(seconds: 5));
      expect(s.evaluations, 0, reason: 'one of two is not "every slot"');

      s.dropOnSlot(1, r.correctSlotOf(1));
      await tester.pump(OrderingGameState.evaluateDelay);
      expect(s.lockedNotes, {0, 1});
      s.dispose();
    });

    testWidgets('replay plays the notes again in their original order and '
        'counts each use — three are offered, more are never refused', (
      tester,
    ) async {
      final played = <String>[];
      final s = make(played: played)..startGame();
      await finishIntro(tester, s);
      final expected = [
        for (final n in s.round!.notes) n.instrument.assetPathForMidi(n.midi),
      ];
      played.clear();

      s.replay();
      await tester.pump(OrderingGameState.noteGap * 4);
      expect(played, expected);
      expect(s.replaysUsed, 1);

      for (var i = 0; i < 3; i++) {
        s.replay();
        await tester.pump(OrderingGameState.noteGap * 4);
      }
      expect(s.replaysUsed, 4, reason: 'the count is the signal, not a cap');
      expect(OrderingGameState.freeReplays, 3);
      s.dispose();
    });

    testWidgets('tapping an instrument plays it and never places it', (
      tester,
    ) async {
      final played = <String>[];
      final s = make(played: played)..startGame();
      await finishIntro(tester, s);
      played.clear();

      s.tapInstrument(2);

      expect(played.length, 1);
      expect(s.placements, isEmpty);
      s.dispose();
    });

    testWidgets('what happened is logged per round: checks made, replays '
        'used, and how many were right the first time', (tester) async {
      final s = make(totalPrompts: 2)..startGame();
      await finishIntro(tester, s);
      s.replay();
      await tester.pump(OrderingGameState.noteGap * 4);
      final right = [for (var n = 0; n < 3; n++) s.round!.correctSlotOf(n)];
      placeAll(s, [right[0], right[2], right[1]]);
      await tester.pump(OrderingGameState.evaluateDelay);
      s.dropOnSlot(1, right[1]);
      s.dropOnSlot(2, right[2]);
      await tester.pump(OrderingGameState.evaluateDelay);
      await tester.pump(OrderingGameState.celebrateFor);

      final r = s.results.single;
      expect(r.evaluations, 2);
      expect(r.replaysUsed, 1);
      expect(r.firstEvaluationCorrect, 1);
      expect(r.skipped, isFalse);
      s.dispose();
    });

    testWidgets('the adult skip moves on without recording an answer', (
      tester,
    ) async {
      final s = make(totalPrompts: 2)..startGame();
      await finishIntro(tester, s);
      s.escape();

      expect(s.currentPromptIndex, 1);
      expect(s.results.single.skipped, isTrue);
      expect(s.correctCount, 0);
      s.dispose();
    });

    testWidgets('finishing the last round completes the game', (tester) async {
      final s = make(totalPrompts: 1)..startGame();
      await finishIntro(tester, s);
      placeAll(s, [for (var n = 0; n < 3; n++) s.round!.correctSlotOf(n)]);
      await tester.pump(OrderingGameState.evaluateDelay);
      await tester.pump(OrderingGameState.celebrateFor);

      expect(s.status, GameStatus.completed);
      expect(s.correctCount, 1);
      s.dispose();
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/game_status.dart';
import 'package:ear_trainer/games/high_low/state/high_low_game_state.dart';

// Uses `testWidgets` (not plain `test`) purely to get Flutter's fake-async
// test zone, so `Future.delayed` inside HighLowGameState can be
// fast-forwarded with `tester.pump(duration)` instead of really waiting —
// no widgets are ever pumped. AudioController is left uninitialized
// throughout, which makes every playback call in it an immediate no-op
// (see AudioController.playNoteForScale's `if (!_isInitialized) return;`
// guard), so these tests never touch a real audio plugin.
void main() {
  group('HighLowGameState — Observe (A0)', () {
    testWidgets('a tap never cuts the intro, scores, or advances', (
      tester,
    ) async {
      final state = HighLowGameState(
        totalPrompts: 3,
        agencyStage: AgencyStage.observe,
      );
      addTearDown(state.dispose);
      state.startGame();
      await tester.pump();
      expect(state.introPlaying, isTrue);

      state.tapInstrument(0);
      await tester.pump();
      expect(
        state.introPlaying,
        isTrue,
        reason: 'Observe never lets a tap interrupt the auto-play',
      );

      await tester.pump(const Duration(milliseconds: 2400));
      expect(state.status, GameStatus.awaitingInput);
      expect(state.correctCount, 0);
      expect(
        state.currentPromptIndex,
        0,
        reason: 'Observe never auto-advances',
      );
    });
  });

  group('HighLowGameState — Participate (A1)', () {
    testWidgets('a tap cuts the intro short and is never swallowed', (
      tester,
    ) async {
      final state = HighLowGameState(
        totalPrompts: 3,
        agencyStage: AgencyStage.participate,
      );
      addTearDown(state.dispose);
      state.startGame();
      await tester.pump();
      expect(state.introPlaying, isTrue);

      state.tapInstrument(0);
      await tester.pump();

      expect(state.introPlaying, isFalse);
      expect(state.status, GameStatus.awaitingInput);
      expect(
        state.showHint,
        isTrue,
        reason: 'Clef should sparkle on the target once listening begins',
      );
      expect(state.correctCount, 0, reason: 'no question, no wrong answers');
    });

    testWidgets('never records anything — there is nothing to score', (
      tester,
    ) async {
      final state = HighLowGameState(
        totalPrompts: 1,
        agencyStage: AgencyStage.participate,
      );
      addTearDown(state.dispose);
      state.startGame();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2400));

      expect(state.status, GameStatus.awaitingInput);
      state.moveOn();
      await tester.pump();
      expect(state.status, GameStatus.completed);
      expect(state.instrumentation, isEmpty);
    });
  });

  group('HighLowGameState — Trigger (A2)', () {
    testWidgets(
      'a correct drop records a result, shows correct feedback, and advances',
      (tester) async {
        final state = HighLowGameState(
          totalPrompts: 2,
          agencyStage: AgencyStage.trigger,
          conceptTier: ConceptTier.t1,
        );
        // Disposed explicitly at the end of this test (it starts a new
        // round's intro along the way) rather than via addTearDown — see
        // the comment there.
        state.startGame();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 2400));

        final prompt = state.currentPrompt!;
        expect(state.canDropClef, isTrue);

        state.dropClef(prompt.targetSide);
        await tester.pump();

        expect(state.dragFeedback, DragFeedback.correct);
        expect(state.correctCount, 1);
        expect(state.instrumentation, hasLength(1));
        expect(state.instrumentation.single.waitedForPlaythrough, isTrue);
        expect(state.instrumentation.single.firstResponseCorrect, isTrue);

        await tester.pump(const Duration(milliseconds: 1300));
        expect(
          state.currentPromptIndex,
          1,
          reason: 'a correct drop auto-advances',
        );
        // The next round's own intro has already started (with a fresh
        // pending timer of its own) — dispose explicitly rather than
        // leaving it for the test framework to notice as unfinished.
        state.dispose();
      },
    );

    testWidgets(
      'a wrong drop is never a failure state — gentle retry, no score, no advance',
      (tester) async {
        final state = HighLowGameState(
          totalPrompts: 2,
          agencyStage: AgencyStage.trigger,
          conceptTier: ConceptTier.t1,
        );
        addTearDown(state.dispose);
        state.startGame();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 2400));

        final prompt = state.currentPrompt!;
        final wrongSide = 1 - prompt.targetSide;

        state.dropClef(wrongSide);
        await tester.pump();

        expect(state.dragFeedback, DragFeedback.retry);
        expect(state.correctCount, 0);
        expect(state.currentPromptIndex, 0);
        expect(state.instrumentation, isEmpty);

        // Retry delay, then a fresh listen replays automatically.
        await tester.pump(const Duration(milliseconds: 1500));
        expect(state.status, GameStatus.playing);
        await tester.pump(const Duration(milliseconds: 2400));

        expect(state.status, GameStatus.awaitingInput);
        expect(state.dragFeedback, DragFeedback.none);
        expect(state.canDropClef, isTrue, reason: 'a real retry, not stuck');
      },
    );

    testWidgets('tapping an instrument explores but never commits an answer', (
      tester,
    ) async {
      final state = HighLowGameState(
        totalPrompts: 1,
        agencyStage: AgencyStage.trigger,
      );
      addTearDown(state.dispose);
      state.startGame();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2400));

      final prompt = state.currentPrompt!;
      state.tapInstrument(prompt.targetSide);
      await tester.pump();

      expect(
        state.status,
        GameStatus.awaitingInput,
        reason: 'a tap must never commit an answer, even the right side',
      );
      expect(state.correctCount, 0);
    });
  });

  group('HighLowGameState — shared controls', () {
    testWidgets('moveOn always advances immediately, mid-intro, unscored', (
      tester,
    ) async {
      final state = HighLowGameState(
        totalPrompts: 2,
        agencyStage: AgencyStage.trigger,
      );
      // Disposed explicitly at the end of this test (it starts a new
      // round's intro along the way) rather than via addTearDown.
      state.startGame();
      await tester.pump();
      expect(state.status, GameStatus.playing);

      state.moveOn();
      await tester.pump();

      expect(state.currentPromptIndex, 1);
      expect(state.correctCount, 0);
      // The next round's own intro has already started — see the
      // matching comment above.
      state.dispose();
    });

    testWidgets('moveOn on the last prompt completes the session', (
      tester,
    ) async {
      final state = HighLowGameState(
        totalPrompts: 1,
        agencyStage: AgencyStage.observe,
      );
      addTearDown(state.dispose);
      state.startGame();
      await tester.pump();

      state.moveOn();
      await tester.pump();

      expect(state.status, GameStatus.completed);
    });
  });
}

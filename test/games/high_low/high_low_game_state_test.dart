import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/models/game_status.dart';
import 'package:ear_trainer/models/pitch_direction.dart';
import 'package:ear_trainer/models/round_order.dart';
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
      // Disposed explicitly at the end (this round's own 6-second nudge
      // timer — see HighLowGameState._finishIntro — is still pending once
      // awaitingInput is reached, and addTearDown's dispose only runs
      // after flutter_test's own pending-timer check) rather than via
      // addTearDown — see the matching comment on the "targetCharacterIsPiper"
      // test below.
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

      await tester.pump(const Duration(milliseconds: 4700));
      expect(state.status, GameStatus.awaitingInput);
      expect(state.correctCount, 0);
      expect(
        state.currentPromptIndex,
        0,
        reason: 'Observe never auto-advances',
      );
      state.dispose();
    });

    testWidgets(
      'targetCharacterIsPiper is meaningful and canDrop is false — Trello '
      'card 1SpHq2la: the target-pole character centers as a visual cue '
      'even here, but there is no drag at this stage',
      (tester) async {
        // RoundOrder.blocked needs at least 3 rounds to produce its
        // deterministic high-block-first sequence (see RoundSequencer) —
        // with that, round 1's target is always "higher", i.e. Clef's
        // pole, so targetCharacterIsPiper is deterministically false here
        // rather than a coin flip.
        final state = HighLowGameState(
          totalPrompts: 3,
          agencyStage: AgencyStage.observe,
          roundOrder: RoundOrder.blocked,
        );
        state.startGame();
        // Let the intro's own scheduled timer run to completion, same
        // reason the other tests in this file that don't otherwise
        // interact with the intro advance past it — but that alone isn't
        // enough any more: reaching awaitingInput schedules a further
        // 6-second nudge timer (Trello card 5tdMOMh3/xpAkja5b), which
        // would still be pending at teardown, so this disposes explicitly
        // at the end instead of via `addTearDown` (which runs *after*
        // flutter_test's own pending-timer assertion).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4700));

        expect(state.currentPrompt, isNotNull);
        expect(
          state.targetCharacterIsPiper,
          isFalse,
          reason: 'round 1 targets the high pole, which Clef owns',
        );
        expect(
          state.canDrop,
          isFalse,
          reason: 'Observe has no drag interaction at all',
        );
        state.dispose();
      },
    );
  });

  group('HighLowGameState — Participate (A1)', () {
    testWidgets('a tap cuts the intro short and is never swallowed', (
      tester,
    ) async {
      final state = HighLowGameState(
        totalPrompts: 3,
        agencyStage: AgencyStage.participate,
      );
      // Disposed explicitly at the end — see the matching comment on the
      // Observe "a tap never cuts the intro" test above (awaitingInput
      // schedules a 6-second nudge timer still pending at teardown).
      state.startGame();
      await tester.pump();
      expect(state.introPlaying, isTrue);

      state.tapInstrument(0);
      await tester.pump();

      expect(state.introPlaying, isFalse);
      expect(state.status, GameStatus.awaitingInput);
      expect(state.correctCount, 0, reason: 'no question, no wrong answers');
      state.dispose();
    });

    testWidgets(
      'escaping without tapping records nothing — there is nothing to '
      'score unless a real tap streak resolved the round',
      (tester) async {
        final state = HighLowGameState(
          totalPrompts: 1,
          agencyStage: AgencyStage.participate,
        );
        addTearDown(state.dispose);
        state.startGame();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4700));

        expect(state.status, GameStatus.awaitingInput);
        state.escape();
        await tester.pump();
        expect(state.status, GameStatus.completed);
        expect(state.instrumentation, isEmpty);
      },
    );

    testWidgets(
      'targetCharacterIsPiper is meaningful and canDrop is false — Trello '
      'card 1SpHq2la: the target-pole character centers as a visual cue '
      'even here, but there is no drag at this stage',
      (tester) async {
        final state = HighLowGameState(
          totalPrompts: 3,
          agencyStage: AgencyStage.participate,
          roundOrder: RoundOrder.blocked,
        );
        state.startGame();
        // Disposed explicitly at the end — see the matching comment on
        // the Observe version of this test above.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4700));

        expect(state.currentPrompt, isNotNull);
        expect(
          state.targetCharacterIsPiper,
          isFalse,
          reason: 'round 1 targets the high pole, which Clef owns',
        );
        expect(
          state.canDrop,
          isFalse,
          reason: 'Participate has no drag interaction at all',
        );
        state.dispose();
      },
    );
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
        await tester.pump(const Duration(milliseconds: 4700));

        final prompt = state.currentPrompt!;
        expect(state.canDrop, isTrue);

        state.dropInstrument(prompt.targetSide);
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
        state.startGame();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4700));

        final prompt = state.currentPrompt!;
        final wrongSide = 1 - prompt.targetSide;

        state.dropInstrument(wrongSide);
        await tester.pump();

        expect(state.dragFeedback, DragFeedback.retry);
        expect(state.correctCount, 0);
        expect(state.currentPromptIndex, 0);
        expect(state.instrumentation, isEmpty);

        // Retry delay, then a fresh listen replays automatically.
        await tester.pump(const Duration(milliseconds: 1500));
        expect(state.status, GameStatus.playing);
        await tester.pump(const Duration(milliseconds: 4700));

        expect(state.status, GameStatus.awaitingInput);
        expect(state.dragFeedback, DragFeedback.none);
        expect(state.canDrop, isTrue, reason: 'a real retry, not stuck');
        // Disposed explicitly (this second awaitingInput scheduled its
        // own fresh 6-second nudge timer, still pending here) rather than
        // via addTearDown — see the matching comment on the Observe "a
        // tap never cuts the intro" test.
        state.dispose();
      },
    );

    testWidgets('a drop always overrides — a new drop cancels a pending retry '
        'instead of being swallowed while its replay/voice line finishes '
        '(Trello card jmuMDPcT)', (tester) async {
      final state = HighLowGameState(
        totalPrompts: 2,
        agencyStage: AgencyStage.trigger,
        conceptTier: ConceptTier.t1,
      );
      // Disposed explicitly at the end (the overriding correct drop below
      // starts a fresh advance timer of its own) rather than via
      // addTearDown — see the matching comment on "a correct drop..."
      // above.
      state.startGame();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4700));

      final prompt = state.currentPrompt!;
      final wrongSide = 1 - prompt.targetSide;

      state.dropInstrument(wrongSide);
      await tester.pump();
      expect(state.dragFeedback, DragFeedback.retry);

      // Well before the retry's own 1400ms feedback pause (let alone its
      // replay) would naturally let a drop through again — a child's
      // drop right now must still be accepted immediately, not queued
      // behind the animation/sound that's still playing.
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        state.canDrop,
        isTrue,
        reason: 'a drop must always override, never be locked out',
      );

      state.dropInstrument(prompt.targetSide);
      await tester.pump();

      expect(
        state.dragFeedback,
        DragFeedback.correct,
        reason: 'the overriding drop is processed immediately',
      );
      expect(state.correctCount, 1);

      // Let the correct drop's own advance-to-next-round timer (and that
      // next round's fresh intro) run so nothing's left pending.
      await tester.pump(const Duration(milliseconds: 1300));
      state.dispose();
    });

    testWidgets('tapping an instrument explores but never commits an answer', (
      tester,
    ) async {
      final state = HighLowGameState(
        totalPrompts: 1,
        agencyStage: AgencyStage.trigger,
      );
      // Disposed explicitly at the end — see the matching comment on the
      // Observe "a tap never cuts the intro" test above.
      state.startGame();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4700));

      final prompt = state.currentPrompt!;
      state.tapInstrument(prompt.targetSide);
      await tester.pump();

      expect(
        state.status,
        GameStatus.awaitingInput,
        reason: 'a tap must never commit an answer, even the right side',
      );
      expect(state.correctCount, 0);
      state.dispose();
    });

    testWidgets(
      'the centered target character follows the target pole — Clef for '
      'high, Piper for low (Trello card 101)',
      (tester) async {
        final state = HighLowGameState(
          totalPrompts: 5,
          agencyStage: AgencyStage.trigger,
        );
        // Disposed explicitly at the end (escape below starts a new
        // round's intro along the way) rather than via addTearDown — see
        // the matching comment on the "escape always advances" test.
        state.startGame();
        await tester.pump();

        // Blocked round order (the default) always puts a "higher" target
        // first — see RoundSequencer.sequence.
        expect(state.currentPrompt!.targetDirection, PitchDirection.higher);
        expect(
          state.targetCharacterIsPiper,
          isFalse,
          reason: 'Clef owns the high pole, so she is the one centered',
        );
        expect(
          state.captionText,
          contains('Clef'),
          reason: 'the caption names whichever character owns this pole',
        );

        // ...then a "lower" target — this is the branch the reported bug
        // (Trello card 101) was actually in: Piper spoke while Clef stayed
        // centered.
        state.escape();
        await tester.pump();

        expect(state.currentPrompt!.targetDirection, PitchDirection.lower);
        expect(
          state.targetCharacterIsPiper,
          isTrue,
          reason: 'Piper owns the low pole, so she is the one centered',
        );
        expect(state.captionText, contains('Piper'));
        state.dispose();
      },
    );
  });

  group('HighLowGameState — shared controls', () {
    testWidgets('escape always advances immediately, mid-intro, unscored', (
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

      state.escape();
      await tester.pump();

      expect(state.currentPromptIndex, 1);
      expect(state.correctCount, 0);
      // The next round's own intro has already started — see the
      // matching comment above.
      state.dispose();
    });

    testWidgets('escape on the last prompt completes the session', (
      tester,
    ) async {
      final state = HighLowGameState(
        totalPrompts: 1,
        agencyStage: AgencyStage.observe,
      );
      addTearDown(state.dispose);
      state.startGame();
      await tester.pump();

      state.escape();
      await tester.pump();

      expect(state.status, GameStatus.completed);
    });

    testWidgets(
      'the move-on control is invisible for the first 6 seconds, then '
      'appears for Observe/Trigger but never Participate (Trello cards '
      '5tdMOMh3/xpAkja5b)',
      (tester) async {
        for (final stage in AgencyStage.values) {
          final state = HighLowGameState(
            totalPrompts: 2,
            agencyStage: stage,
          );
          addTearDown(state.dispose);
          state.startGame();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 4700));

          expect(
            state.showMoveOnControl,
            isFalse,
            reason: '$stage: never visible immediately',
          );

          await tester.pump(const Duration(seconds: 6));

          expect(
            state.showMoveOnControl,
            stage != AgencyStage.participate,
            reason:
                '$stage: visible ~6s in for Observe/Trigger, never for '
                'Participate (which has its own auto-advance instead)',
          );
        }
      },
    );

    testWidgets(
      'moveOn resolves the round — plays/sparkles the correct instrument '
      'and advances, unlike escape (Trello card xpAkja5b)',
      (tester) async {
        final state = HighLowGameState(
          totalPrompts: 2,
          agencyStage: AgencyStage.observe,
        );
        state.startGame();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4700));
        await tester.pump(const Duration(seconds: 6));
        expect(state.showMoveOnControl, isTrue);

        final targetSide = state.currentPrompt!.targetSide;
        state.moveOn();
        await tester.pump();

        expect(state.dragFeedback, DragFeedback.correct);
        expect(state.lastDropSide, targetSide);
        expect(state.instrumentSparkleSide, targetSide);
        expect(
          state.correctCount,
          1,
          reason: 'unlike escape, moveOn resolves the round as answered',
        );

        await tester.pump(const Duration(milliseconds: 1300));
        expect(state.currentPromptIndex, 1);
        state.dispose();
      },
    );

    testWidgets('moveOn does nothing before showMoveOnControl is true', (
      tester,
    ) async {
      final state = HighLowGameState(
        totalPrompts: 2,
        agencyStage: AgencyStage.observe,
      );
      // Disposed explicitly at the end — the intro's own note-gap timer
      // is still pending this early (see the matching comment on the
      // Observe "a tap never cuts the intro" test above).
      state.startGame();
      await tester.pump();
      expect(state.showMoveOnControl, isFalse);

      state.moveOn();
      await tester.pump();

      expect(
        state.correctCount,
        0,
        reason: 'the control is not built yet at this point, and the '
            'method guards against being called anyway',
      );
      state.dispose();
    });
  });

  group('HighLowGameState — captions (Trello card 5tdMOMh3)', () {
    testWidgets(
      'Observe shares one caption for both poles — it must not name which '
      'character owns which pole',
      (tester) async {
        final state = HighLowGameState(
          totalPrompts: 3,
          agencyStage: AgencyStage.observe,
          roundOrder: RoundOrder.blocked,
        );
        // Disposed explicitly at the end (escape below starts a second
        // round whose own intro is still mid-flight, and the first
        // round's own timers may not have finished either) rather than
        // via addTearDown — see the matching comment on the Observe "a
        // tap never cuts the intro" test.
        state.startGame();
        await tester.pump();

        expect(state.captionText, 'Let them explore freely.');
        expect(state.captionText, isNot(contains('Clef')));
        expect(state.captionText, isNot(contains('Piper')));

        state.escape();
        await tester.pump();
        expect(
          state.captionText,
          'Let them explore freely.',
          reason: 'the low-pole round gets the identical caption',
        );
        state.dispose();
      },
    );

    testWidgets('Participate names the pole (higher/lower)', (
      tester,
    ) async {
      final state = HighLowGameState(
        totalPrompts: 3,
        agencyStage: AgencyStage.participate,
        roundOrder: RoundOrder.blocked,
      );
      // Disposed explicitly at the end — see the matching comment on the
      // Observe caption test above.
      state.startGame();
      await tester.pump();

      expect(state.currentPrompt!.targetDirection, PitchDirection.higher);
      expect(state.captionText, contains('higher one'));

      state.escape();
      await tester.pump();
      expect(state.currentPrompt!.targetDirection, PitchDirection.lower);
      expect(state.captionText, contains('lower one'));
      state.dispose();
    });

    testWidgets(
      'the secondary Participate caption only appears ~6s in, and only '
      'for Participate',
      (tester) async {
        final state = HighLowGameState(
          totalPrompts: 1,
          agencyStage: AgencyStage.participate,
        );
        addTearDown(state.dispose);
        state.startGame();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4700));

        expect(state.secondaryCaptionText, isNull);

        await tester.pump(const Duration(seconds: 6));
        expect(state.secondaryCaptionText, isNotNull);
        expect(state.secondaryCaptionText, contains('Encourage them'));
      },
    );
  });

  group('HighLowGameState — A0/A1 repeated taps (Trello card RqdPFKLf)', () {
    testWidgets(
      'a correct tap sparkles the owning character; a wrong tap resets '
      'the streak with nothing negative',
      (tester) async {
        final state = HighLowGameState(
          totalPrompts: 1,
          agencyStage: AgencyStage.participate,
        );
        // Disposed explicitly at the end — see the matching comment on
        // the Observe "a tap never cuts the intro" test above.
        state.startGame();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4700));

        final targetSide = state.currentPrompt!.targetSide;
        final wrongSide = 1 - targetSide;

        state.tapInstrument(targetSide);
        await tester.pump();
        expect(
          state.characterSparkleIsPiper,
          state.targetCharacterIsPiper,
          reason: 'the owning character sparkles on a correct tap',
        );

        state.tapInstrument(wrongSide);
        await tester.pump();
        expect(state.status, GameStatus.awaitingInput);
        expect(state.correctCount, 0, reason: 'a wrong tap is never a failure');
        state.dispose();
      },
    );

    testWidgets(
      'five correct taps in a row celebrate and auto-advance, at both '
      'Observe and Participate',
      (tester) async {
        for (final stage in [AgencyStage.observe, AgencyStage.participate]) {
          final state = HighLowGameState(
            totalPrompts: 2,
            agencyStage: stage,
          );
          state.startGame();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 4700));

          final targetSide = state.currentPrompt!.targetSide;
          for (var i = 0; i < 5; i++) {
            state.tapInstrument(targetSide);
            await tester.pump();
          }

          expect(
            state.correctCount,
            1,
            reason: '$stage: five correct taps resolve the round',
          );
          expect(state.dragFeedback, DragFeedback.correct);

          await tester.pump(const Duration(milliseconds: 1300));
          expect(state.currentPromptIndex, 1);
          state.dispose();
        }
      },
    );

    testWidgets('never advances at Trigger — tapping stays pure exploration', (
      tester,
    ) async {
      final state = HighLowGameState(
        totalPrompts: 1,
        agencyStage: AgencyStage.trigger,
      );
      // Disposed explicitly at the end — see the matching comment on the
      // Observe "a tap never cuts the intro" test above.
      state.startGame();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4700));

      final targetSide = state.currentPrompt!.targetSide;
      for (var i = 0; i < 5; i++) {
        state.tapInstrument(targetSide);
        await tester.pump();
      }

      expect(state.correctCount, 0);
      expect(state.status, GameStatus.awaitingInput);
      state.dispose();
    });
  });

  group('HighLowGameState — speaking indicator (Trello card PIm7xE6n)', () {
    testWidgets(
      'nobody speaks before the game starts; the correct character speaks '
      'once a Trigger round prompt begins',
      (tester) async {
        final state = HighLowGameState(
          totalPrompts: 1,
          agencyStage: AgencyStage.trigger,
          roundOrder: RoundOrder.blocked,
        );
        // Disposed explicitly at the end — see the matching comment on
        // the Observe "a tap never cuts the intro" test above.
        expect(state.speakingIsPiper, isNull);

        state.startGame();
        // Checked synchronously, with no `await` in between: [_speak]
        // sets [speakingIsPiper] before its own first `await`, and with
        // AudioController uninitialized in this test environment (see
        // this file's class doc), that `await` resolves on the very next
        // microtask — a `tester.pump()` here would already see it
        // cleared back to null.
        expect(
          state.speakingIsPiper,
          isFalse,
          reason: 'Round 1 (blocked order) targets "higher", Clef\'s pole, '
              'so Clef speaks the "give me the high one" prompt',
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4700));
        expect(
          state.speakingIsPiper,
          isNull,
          reason: 'nobody is speaking once the line has finished playing',
        );
        state.dispose();
      },
    );
  });
}

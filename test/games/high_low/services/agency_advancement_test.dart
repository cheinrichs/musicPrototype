import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/round_instrumentation.dart';
import 'package:ear_trainer/games/high_low/services/agency_advancement.dart';
import 'package:ear_trainer/models/agency_stage.dart';

void main() {
  RoundInstrumentation observeRound({int n = 1, bool skipped = false}) =>
      RoundInstrumentation(
        promptNumber: n,
        waitedForPlaythrough: true,
        firstResponseCorrect: null,
        listenAgainCount: 0,
        skipped: skipped,
      );

  RoundInstrumentation exploreRound({int wrongTapCount = 0}) =>
      RoundInstrumentation(
        promptNumber: 1,
        waitedForPlaythrough: true,
        firstResponseCorrect: true,
        listenAgainCount: 0,
        correctTapCount: 5,
        wrongTapCount: wrongTapCount,
      );

  RoundInstrumentation dragRound({
    bool notesHeard = true,
    int wrongTapCount = 0,
  }) => RoundInstrumentation(
    promptNumber: 1,
    waitedForPlaythrough: true,
    firstResponseCorrect: true,
    notesHeardBeforeFirstResponse: notesHeard,
    listenAgainCount: 0,
    wrongTapCount: wrongTapCount,
  );

  group('AgencyAdvancement (Trello card 172)', () {
    test('one round alone never moves a child, however short the set', () {
      expect(AgencyAdvancement.promotionNeeds(1), 2);
      final result = AgencyAdvancement.evaluate(
        current: AgencyStage.observe,
        instrumentation: [observeRound()],
      );
      expect(result.change, AgencyChange.hold);
    });

    test(
      'PROMOTION IS A SHARE OF THE SET, not a bare count (Trello card '
      '213): 60% — what three of five was — so a three-round Observe set '
      'needs two, a four-round Explore set three, a five-round set three',
      () {
        expect(AgencyAdvancement.promotionNeeds(3), 2);
        expect(AgencyAdvancement.promotionNeeds(4), 3);
        expect(AgencyAdvancement.promotionNeeds(5), 3);
      },
    );

    test('Observe advances to Explore once enough rounds were completed '
        'without being skipped — completion at Observe already means both '
        'instruments were tapped, so there is nothing further to check', () {
      final result = AgencyAdvancement.evaluate(
        current: AgencyStage.observe,
        instrumentation: List.generate(
          AgencyAdvancement.roundsRequired,
          (i) => observeRound(n: i),
        ),
      );
      expect(result.change, AgencyChange.advance);
      expect(result.reason, isNotEmpty);
    });

    group('skipped rounds (logged since 2026-10-12, Trello card 173)', () {
      test('A SKIP IS NEUTRAL for promotion (Trello card 213): it is the '
          'adult\'s control, not evidence about the child — a three-round '
          'Observe set with one skip still promotes on the other two', () {
        final result = AgencyAdvancement.evaluate(
          current: AgencyStage.observe,
          instrumentation: [
            observeRound(n: 0),
            observeRound(n: 1, skipped: true),
            observeRound(n: 2),
          ],
        );
        expect(result.change, AgencyChange.advance);
        expect(result.reason, contains('skipped'));
      });

      test('…but neutral is not free: a skip does not count as a qualifying '
          'round, so a set the adult mostly skipped holds', () {
        final result = AgencyAdvancement.evaluate(
          current: AgencyStage.observe,
          instrumentation: [
            observeRound(n: 0, skipped: true),
            observeRound(n: 1, skipped: true),
            observeRound(n: 2),
          ],
        );
        expect(result.change, AgencyChange.hold);
      });

      test('…and the same at Explore: a skip in a four-round set does not '
          'block three clean rounds', () {
        final result = AgencyAdvancement.evaluate(
          current: AgencyStage.explore,
          instrumentation: [
            exploreRound(),
            RoundInstrumentation(
              promptNumber: 9,
              waitedForPlaythrough: true,
              firstResponseCorrect: null,
              listenAgainCount: 0,
              skipped: true,
            ),
            exploreRound(),
            exploreRound(),
          ],
        );
        expect(result.change, AgencyChange.advance);
      });

      test('Decide demotion reads completed rounds only, as before skips were '
          'logged — a skip neither triggers nor blocks it', () {
        final failing = List.generate(
          AgencyAdvancement.roundsRequired,
          (_) => dragRound(wrongTapCount: 99),
        );
        final withSkip = [
          ...failing.take(1),
          RoundInstrumentation(
            promptNumber: 9,
            waitedForPlaythrough: true,
            firstResponseCorrect: null,
            listenAgainCount: 0,
            skipped: true,
          ),
          ...failing.skip(1),
        ];
        expect(
          AgencyAdvancement.evaluate(
            current: AgencyStage.decide,
            instrumentation: withSkip,
          ).change,
          AgencyChange.demote,
        );
      });
    });

    group('Explore → Drag', () {
      test('advances when the recent rounds hit the sparkle consistently '
          '(within the noise tolerance)', () {
        final result = AgencyAdvancement.evaluate(
          current: AgencyStage.explore,
          instrumentation: List.generate(
            AgencyAdvancement.roundsRequired,
            (_) => exploreRound(wrongTapCount: 1),
          ),
        );
        expect(result.change, AgencyChange.advance);
      });

      test('holds when the rounds are noisy — never demotes FROM Explore '
          'for inaccuracy; a noisy child just isn\'t ready yet, which is a '
          'hold, not a punishment', () {
        final result = AgencyAdvancement.evaluate(
          current: AgencyStage.explore,
          instrumentation: List.generate(
            AgencyAdvancement.roundsRequired,
            (_) => exploreRound(wrongTapCount: 10),
          ),
        );
        expect(result.change, AgencyChange.hold);
      });

      test(
        'NO STREAK (Trello card 213): one noisy round in the middle of a '
        'four-round set does not hold back three clean ones — agency asks '
        'whether the child can do the gesture, and nobody lucks into one',
        () {
          final result = AgencyAdvancement.evaluate(
            current: AgencyStage.explore,
            instrumentation: [
              exploreRound(wrongTapCount: 0),
              exploreRound(wrongTapCount: 10),
              exploreRound(wrongTapCount: 0),
              exploreRound(wrongTapCount: 0),
            ],
          );
          expect(result.change, AgencyChange.advance);
        },
      );

      test('two noisy rounds in four leave too few qualifying, and hold', () {
        final result = AgencyAdvancement.evaluate(
          current: AgencyStage.explore,
          instrumentation: [
            exploreRound(wrongTapCount: 0),
            exploreRound(wrongTapCount: 10),
            exploreRound(wrongTapCount: 10),
            exploreRound(wrongTapCount: 0),
          ],
        );
        expect(result.change, AgencyChange.hold);
      });

      test('one noisy round at the start of a set does not block '
          'advancement either', () {
        final rounds = [
          exploreRound(wrongTapCount: 50),
          ...List.generate(
            AgencyAdvancement.roundsRequired,
            (_) => exploreRound(wrongTapCount: 0),
          ),
        ];
        final result = AgencyAdvancement.evaluate(
          current: AgencyStage.explore,
          instrumentation: rounds,
        );
        expect(result.change, AgencyChange.advance);
      });
    });

    group('Drag demotion', () {
      test('demotes to Explore after consecutive rounds with many failed '
          'drags — motor difficulty, not a wrong answer', () {
        final result = AgencyAdvancement.evaluate(
          current: AgencyStage.decide,
          instrumentation: List.generate(
            AgencyAdvancement.roundsRequired,
            (_) => dragRound(wrongTapCount: 5),
          ),
        );
        expect(result.change, AgencyChange.demote);
      });

      test('demotes to Explore after consecutive rounds answered before '
          'either note finished — no evidence pattern, distinct from the '
          'failed-drags signal', () {
        final result = AgencyAdvancement.evaluate(
          current: AgencyStage.decide,
          instrumentation: List.generate(
            AgencyAdvancement.roundsRequired,
            (_) => dragRound(notesHeard: false, wrongTapCount: 0),
          ),
        );
        expect(result.change, AgencyChange.demote);
      });

      test('holds for ordinary, evidenced Drag play — a correct answer, '
          'even a wrong one now and then, is not a demotion signal '
          '(agency moves on capability, never accuracy)', () {
        final result = AgencyAdvancement.evaluate(
          current: AgencyStage.decide,
          instrumentation: List.generate(
            AgencyAdvancement.roundsRequired,
            (_) => dragRound(notesHeard: true, wrongTapCount: 0),
          ),
        );
        expect(result.change, AgencyChange.hold);
      });

      test(
        'never advances further from Drag — it is the top of the ladder',
        () {
          final result = AgencyAdvancement.evaluate(
            current: AgencyStage.decide,
            instrumentation: List.generate(
              AgencyAdvancement.roundsRequired,
              (_) => dragRound(),
            ),
          );
          expect(result.change, isNot(AgencyChange.advance));
        },
      );
    });
  });
}

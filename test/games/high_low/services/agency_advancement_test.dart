import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/models/round_instrumentation.dart';
import 'package:ear_trainer/games/high_low/services/agency_advancement.dart';
import 'package:ear_trainer/models/agency_stage.dart';

void main() {
  RoundInstrumentation observeRound({int n = 1}) => RoundInstrumentation(
    promptNumber: n,
    waitedForPlaythrough: true,
    firstResponseCorrect: null,
    listenAgainCount: 0,
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
    test('holds with fewer than roundsRequired rounds recorded', () {
      final result = AgencyAdvancement.evaluate(
        current: AgencyStage.observe,
        instrumentation: [observeRound(), observeRound()],
      );
      expect(result.change, AgencyChange.hold);
    });

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

      test('a single noisy round among otherwise-clean ones holds — the '
          'window requires ALL recent rounds to agree', () {
        final rounds = [
          exploreRound(wrongTapCount: 0),
          exploreRound(wrongTapCount: 10),
          exploreRound(wrongTapCount: 0),
        ];
        expect(rounds.length, AgencyAdvancement.roundsRequired);
        final result = AgencyAdvancement.evaluate(
          current: AgencyStage.explore,
          instrumentation: rounds,
        );
        expect(result.change, AgencyChange.hold);
      });

      test('only the most recent roundsRequired rounds are considered — an '
          'old noisy round outside the window does not block advancement', () {
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
          current: AgencyStage.drag,
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
          current: AgencyStage.drag,
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
          current: AgencyStage.drag,
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
            current: AgencyStage.drag,
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

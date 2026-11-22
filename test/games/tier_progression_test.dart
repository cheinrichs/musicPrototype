import 'package:ear_trainer/games/high_low/models/round_instrumentation.dart';
import 'package:ear_trainer/games/tier_progression.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

RoundInstrumentation round({
  bool? correct,
  bool? heard = true,
  bool waited = true,
  bool skipped = false,
  bool leftSet = false,
}) => RoundInstrumentation(
  promptNumber: 1,
  waitedForPlaythrough: waited,
  firstResponseCorrect: correct,
  notesHeardBeforeFirstResponse: heard,
  listenAgainCount: 0,
  skipped: skipped,
  leftSet: leftSet,
);

void main() {
  tierAdvancementTests();
  group('which rounds are tier evidence', () {
    const decide = AgencyStage.decide;
    test('a valid first answer is right or wrong', () {
      expect(
        TierEvidence.slotFor(round(correct: true), decide),
        TierSlot.right,
      );
      expect(
        TierEvidence.slotFor(round(correct: false), decide),
        TierSlot.wrong,
      );
      expect(
        TierEvidence.slotFor(round(correct: true), AgencyStage.explore),
        TierSlot.right,
        reason: 'Explore\'s first tap counts (Cooper, 2026-11-22)',
      );
    });

    test('a skip is a neutral slot, never right', () {
      expect(
        TierEvidence.slotFor(round(skipped: true), decide),
        TierSlot.skipped,
      );
    });

    test('NOT evidence: Observe, no answer, an answer before the sounds '
        'finished, or leaving the set', () {
      expect(
        TierEvidence.slotFor(round(correct: true), AgencyStage.observe),
        isNull,
      );
      expect(TierEvidence.slotFor(round(correct: null), decide), isNull);
      expect(
        TierEvidence.slotFor(round(correct: true, heard: false), decide),
        isNull,
      );
      expect(
        TierEvidence.slotFor(
          round(correct: true, heard: null, waited: false),
          decide,
        ),
        isNull,
        reason: 'Loud or Quiet: a tap during the intro',
      );
      expect(
        TierEvidence.slotFor(round(correct: true, leftSet: true), decide),
        isNull,
      );
    });
  });

  group('the saved evidence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('keeps only the last ten slots, per game', () {
      final s = TierProgressState();
      for (var i = 0; i < 12; i++) {
        s.recordRounds(
          profileId: 'd',
          gameId: 'high_low',
          childLevel: 0,
          playedLevel: 0,
          agency: AgencyStage.decide,
          rounds: [round(correct: i >= 2)],
        );
      }
      final g = s.gameRecord('d', 'high_low')!;
      expect(g.slots, hasLength(10));
      expect(g.rights, 10, reason: 'the two early wrongs fell out');
      expect(s.gameRecord('d', 'loud_quiet'), isNull);
    });

    test('only rounds PLAYED at the child\'s level count, and a level '
        'change starts the window again', () {
      final s = TierProgressState();
      void add(int child, int played) => s.recordRounds(
        profileId: 'd',
        gameId: 'loud_quiet',
        childLevel: child,
        playedLevel: played,
        agency: AgencyStage.explore,
        rounds: [round(correct: true)],
      );
      add(3, 2);
      expect(s.gameRecord('d', 'loud_quiet')!.slots, isEmpty);
      add(3, 3);
      add(3, 3);
      expect(s.gameRecord('d', 'loud_quiet')!.slots, hasLength(2));
      add(4, 4);
      expect(s.gameRecord('d', 'loud_quiet')!.slots, hasLength(1));
    });

    test('survives the app closing', () async {
      final a = TierProgressState();
      a.recordRounds(
        profileId: 'd',
        gameId: 'high_low',
        childLevel: 1,
        playedLevel: 1,
        agency: AgencyStage.decide,
        rounds: [round(correct: true), round(skipped: true)],
      );
      a.finishSet('d', agencyChanged: true);
      a.recordOf('d').note('held: 1 right of 2');
      a.finishSet('d', agencyChanged: false);
      await a.saved;
      final b = TierProgressState();
      await b.load();
      final g = b.gameRecord('d', 'high_low')!;
      expect(g.level, 1);
      expect(g.slots, [TierSlot.right, TierSlot.skipped]);
      expect(b.recordOf('d').setsSinceAgencyChange, 1);
      expect(b.recordOf('d').log, ['held: 1 right of 2']);
    });
  });
}

GameTierRecord rec(String codes, {int level = 0}) => GameTierRecord(
  level: level,
  slots: [for (final c in codes.split('')) TierSlot.byCode(c)!],
);

TierEvaluation judge(
  String codes, {
  int level = 1,
  int ceiling = 3,
  int sets = 99,
}) => TierAdvancement.evaluate(
  record: rec(codes, level: level),
  level: level,
  ceiling: ceiling,
  setsSinceAgencyChange: sets,
  label: 'T${level + 1}',
);

void tierAdvancementTests() {
  group('TierAdvancement (Cooper, 2026-11-22: 8 of 10, A1 counts, one-set '
      'lockout, demotion, T4 ceiling)', () {
    test('promotes at 8 right of a full window of 10, in any order', () {
      expect(judge('rrwrrwrrrr').change, TierChange.promote);
      expect(judge('wrrrrrrrrw').change, TierChange.promote);
    });

    test('holds at 7 of 10, and before the window is full', () {
      expect(judge('rrwrrwrrwr').change, TierChange.hold);
      expect(judge('rrrrrrrrr').change, TierChange.hold, reason: '9 slots');
    });

    test('a skip is neutral, not free: it takes a slot but is never right', () {
      expect(
        judge('rrrrrrrsss').change,
        TierChange.hold,
        reason: '7 right and 3 skips',
      );
      expect(judge('rrrrrrrrss').change, TierChange.promote);
    });

    test('never past the ceiling (T4 for High vs Low)', () {
      expect(judge('rrrrrrrrrr', level: 3).change, TierChange.hold);
    });

    test('LOCKOUT: no promotion in the set agency changed, nor the next; '
        'allowed the set after', () {
      expect(judge('rrrrrrrrrr', sets: 0).change, TierChange.hold);
      expect(judge('rrrrrrrrrr', sets: 1).change, TierChange.hold);
      expect(judge('rrrrrrrrrr', sets: 2).change, TierChange.promote);
    });

    test('DEMOTES at or below half right over 8+ answered, with no lockout, '
        'and never below T1', () {
      expect(judge('rrrrwwww', sets: 0).change, TierChange.demote);
      expect(judge('rrrrwwwwss').change, TierChange.demote);
      expect(judge('rrrrrwww').change, TierChange.hold, reason: '5 of 8');
      expect(judge('rrrwwww').change, TierChange.hold, reason: 'only 7');
      expect(judge('wwwwwwwwww', level: 0).change, TierChange.hold);
    });
  });
}

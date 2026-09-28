import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ear_trainer/app/state/progress_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProgressState — profile scoping (Trello card 170)', () {
    test('two profiles never see each other\'s sessions', () async {
      final davisSide = ProgressState();
      await davisSide.loadForProfile('davis');
      davisSide.completeSession(
        gameType: 'high_low',
        correctCount: 3,
        totalCount: 5,
      );
      expect(davisSide.totalSessions, 1);

      final delaneySide = ProgressState();
      await delaneySide.loadForProfile('delaney');
      expect(
        delaneySide.totalSessions,
        0,
        reason: 'a fresh profile must not inherit another profile\'s count',
      );
    });

    test('reloading the same profile id sees the same data back', () async {
      final first = ProgressState();
      await first.loadForProfile('davis');
      first.completeSession(
        gameType: 'high_low',
        correctCount: 3,
        totalCount: 5,
      );
      // completeSession's own save is fire-and-forget (unawaited by
      // design); give it a microtask to actually land before a second,
      // independent instance re-reads the same key.
      await Future<void>.delayed(Duration.zero);

      final second = ProgressState();
      await second.loadForProfile('davis');
      expect(second.totalSessions, 1);
      expect(second.highLowSessions, 1);
    });

    test('switching a single instance from one profile to another via '
        'loadForProfile drops the previous profile\'s in-memory state — a '
        'child picking a different profile mid-session must never see the '
        'last child\'s counts linger', () async {
      final state = ProgressState();
      await state.loadForProfile('davis');
      state.completeSession(
        gameType: 'high_low',
        correctCount: 1,
        totalCount: 1,
      );
      expect(state.totalSessions, 1);
      await Future<void>.delayed(Duration.zero);

      await state.loadForProfile('delaney');
      expect(state.totalSessions, 0);
    });

    test('the legacy unscoped load() still works, for any caller with no '
        'profile context yet', () async {
      final state = ProgressState();
      await state.load();
      state.completeSession(
        gameType: 'high_low',
        correctCount: 1,
        totalCount: 1,
      );

      final reload = ProgressState();
      await reload.load();
      expect(reload.totalSessions, 1);
    });
  });
}

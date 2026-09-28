import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ear_trainer/app/config.dart';
import 'package:ear_trainer/app/state/profile_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileState (Trello card 170)', () {
    test('starts empty and unloaded', () {
      final state = ProfileState();
      expect(state.isLoaded, isFalse);
      expect(state.profiles, isEmpty);
      expect(state.activeProfile, isNull);
    });

    test('addProfile adds and persists, selectProfile sets the active one '
        'in memory only', () async {
      final state = ProfileState();
      await state.load();
      final davis = await state.addProfile('Davis');
      expect(state.profiles.map((p) => p.name), ['Davis']);
      expect(state.activeProfile, isNull, reason: 'adding does not select');

      state.selectProfile(davis);
      expect(state.activeProfile, davis);
    });

    test('profiles persist across a fresh ProfileState (a relaunch)', () async {
      final first = ProfileState();
      await first.load();
      await first.addProfile('Delaney');

      final second = ProfileState();
      await second.load();
      expect(second.profiles.map((p) => p.name), ['Delaney']);
    });

    test('the active profile does NOT persist across a fresh ProfileState — '
        '"pick a profile at launch" is a deliberate step every time on a '
        'shared device, never a remembered default', () async {
      final first = ProfileState();
      await first.load();
      final delaney = await first.addProfile('Delaney');
      first.selectProfile(delaney);

      final second = ProfileState();
      await second.load();
      expect(second.activeProfile, isNull);
    });

    test('at most one adult profile can exist — a second attempt returns '
        'the existing one instead of creating another', () async {
      final state = ProfileState();
      await state.load();
      final first = await state.addProfile('Cooper', isAdult: true);
      final second = await state.addProfile('Someone else', isAdult: true);
      expect(second.id, first.id);
      expect(state.profiles.where((p) => p.isAdult), hasLength(1));
    });

    test('setAgencyOverride updates the profile in the list and, if it is '
        'the active one, in activeProfile too — and can clear it back to '
        'null', () async {
      final state = ProfileState();
      await state.load();
      final davis = await state.addProfile('Davis');
      state.selectProfile(davis);

      await state.setAgencyOverride(davis, AgencyStage.explore);
      expect(state.activeProfile!.agencyOverride, AgencyStage.explore);
      expect(
        state.profiles.firstWhere((p) => p.id == davis.id).agencyOverride,
        AgencyStage.explore,
      );

      await state.setAgencyOverride(davis, null);
      expect(state.activeProfile!.agencyOverride, isNull);
    });

    group('canUseDevTools — gated to BOTH an internal build AND the adult '
        'profile (Trello card 170: an internal build a child is using must '
        'not show dev tools either)', () {
      tearDown(() => devToolsEnabled = false);

      test('false with no active profile, even on an internal build', () async {
        devToolsEnabled = true;
        final state = ProfileState();
        await state.load();
        expect(state.canUseDevTools, isFalse);
      });

      test('false for a child profile, even on an internal build', () async {
        devToolsEnabled = true;
        final state = ProfileState();
        await state.load();
        state.selectProfile(await state.addProfile('Davis'));
        expect(state.canUseDevTools, isFalse);
      });

      test('false for the adult profile on a non-internal build', () async {
        devToolsEnabled = false;
        final state = ProfileState();
        await state.load();
        state.selectProfile(await state.addProfile('Cooper', isAdult: true));
        expect(state.canUseDevTools, isFalse);
      });

      test('true only for the adult profile on an internal build', () async {
        devToolsEnabled = true;
        final state = ProfileState();
        await state.load();
        state.selectProfile(await state.addProfile('Cooper', isAdult: true));
        expect(state.canUseDevTools, isTrue);
      });
    });

    test('the one real migration: old, pre-profile flat keys are purged once '
        '(that data is all Cooper testing, not real play — see the class doc) '
        'without touching profile data created since', () async {
      SharedPreferences.setMockInitialValues({
        'total_sessions': 42,
        'skill_xp_pitchAwareness': 500,
      });
      final prefsBefore = await SharedPreferences.getInstance();
      expect(prefsBefore.getInt('total_sessions'), 42);

      final state = ProfileState();
      await state.load();

      final prefsAfter = await SharedPreferences.getInstance();
      expect(prefsAfter.getInt('total_sessions'), isNull);
      expect(prefsAfter.getInt('skill_xp_pitchAwareness'), isNull);

      // The purge runs once — a second ProfileState (a later launch)
      // must not go looking for those keys again or re-purge anything
      // a namesake key might hold for an unrelated reason.
      await state.addProfile('Davis');
      final second = ProfileState();
      await second.load();
      expect(second.profiles, hasLength(1));
    });
  });
}

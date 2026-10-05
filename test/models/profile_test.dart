import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/profile.dart';

void main() {
  group('Profile (Trello card 170)', () {
    test('round-trips through JSON, including a null agency override', () {
      const profile = Profile(id: 'abc', name: 'Delaney');
      final restored = Profile.fromJson(profile.toJson());
      expect(restored.id, 'abc');
      expect(restored.name, 'Delaney');
      expect(restored.isAdult, isFalse);
      expect(restored.agencyOverride, isNull);
    });

    test('round-trips a set agency override', () {
      const profile = Profile(
        id: 'abc',
        name: 'Davis',
        agencyOverride: AgencyStage.explore,
      );
      final restored = Profile.fromJson(profile.toJson());
      expect(restored.agencyOverride, AgencyStage.explore);
    });

    test('a stale/unrecognized agency override name falls back to null, '
        'never to a guessed real stage a parent never actually chose', () {
      final restored = Profile.fromJson({
        'id': 'abc',
        'name': 'Davis',
        'isAdult': false,
        'agencyOverride': 'someRetiredStageName',
      });
      expect(restored.agencyOverride, isNull);
    });

    group('copyWith', () {
      test('clearAgencyOverride actually clears it — a plain '
          '`agencyOverride: null` argument cannot, since Dart has no way to '
          'tell "pass null" from "pass nothing" for an optional parameter '
          '(a real bug caught before it shipped: ProfileState.setAgencyOverride '
          'silently kept the old value when clearing)', () {
        const profile = Profile(
          id: 'abc',
          name: 'Davis',
          agencyOverride: AgencyStage.decide,
        );
        final cleared = profile.copyWith(clearAgencyOverride: true);
        expect(cleared.agencyOverride, isNull);
      });

      test('omitting agencyOverride leaves it unchanged', () {
        const profile = Profile(
          id: 'abc',
          name: 'Davis',
          agencyOverride: AgencyStage.decide,
        );
        expect(profile.copyWith(name: 'D').agencyOverride, AgencyStage.decide);
      });

      test('passing a new agencyOverride replaces it', () {
        const profile = Profile(
          id: 'abc',
          name: 'Davis',
          agencyOverride: AgencyStage.observe,
        );
        expect(
          profile.copyWith(agencyOverride: AgencyStage.decide).agencyOverride,
          AgencyStage.decide,
        );
      });

      test('never changes id or isAdult', () {
        const profile = Profile(id: 'abc', name: 'Davis', isAdult: true);
        final updated = profile.copyWith(name: 'Someone else');
        expect(updated.id, 'abc');
        expect(updated.isAdult, isTrue);
      });
    });
  });

  group('a stored agency value from before the Drag → Decide rename '
      '(Trello card 181)', () {
    test('a saved "drag" still means the third stage, Decide — it must not '
        'silently fall back to "not set"', () {
      final profile = Profile.fromJson({
        'id': 'p1',
        'name': 'Davis',
        'isAdult': false,
        'agencyOverride': 'drag',
      });
      expect(profile.agencyOverride, AgencyStage.decide);
    });

    test('a current "decide" round-trips unchanged', () {
      final profile = Profile.fromJson({
        'id': 'p1',
        'name': 'Davis',
        'isAdult': false,
        'agencyOverride': 'decide',
      });
      expect(profile.agencyOverride, AgencyStage.decide);
    });
  });
}


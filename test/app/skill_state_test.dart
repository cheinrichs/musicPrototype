import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ear_trainer/app/state/skill_state.dart';
import 'package:ear_trainer/models/musical_skill.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SkillState — profile scoping (Trello card 170)', () {
    test('two profiles never see each other\'s XP', () async {
      final davisSide = SkillState();
      await davisSide.loadForProfile('davis');
      davisSide.awardXp(MusicalSkill.pitchAwareness, 100);
      expect(davisSide.xpFor(MusicalSkill.pitchAwareness), 100);

      final delaneySide = SkillState();
      await delaneySide.loadForProfile('delaney');
      expect(delaneySide.xpFor(MusicalSkill.pitchAwareness), 0);
    });

    test('reloading the same profile id sees the same XP back', () async {
      final first = SkillState();
      await first.loadForProfile('davis');
      first.awardXp(MusicalSkill.pitchAwareness, 150);
      await Future<void>.delayed(Duration.zero);

      final second = SkillState();
      await second.loadForProfile('davis');
      expect(second.xpFor(MusicalSkill.pitchAwareness), 150);
    });

    test('switching a single instance to another profile via loadForProfile '
        'clears the in-memory XP map — a stale skill from the previous '
        'child must not leak into the new one', () async {
      final state = SkillState();
      await state.loadForProfile('davis');
      state.awardXp(MusicalSkill.pitchAwareness, 200);
      expect(state.xpFor(MusicalSkill.pitchAwareness), 200);

      await state.loadForProfile('delaney');
      expect(state.xpFor(MusicalSkill.pitchAwareness), 0);
    });

    test('the legacy unscoped load() still works, for any caller with no '
        'profile context yet', () async {
      final state = SkillState();
      await state.load();
      state.awardXp(MusicalSkill.pitchAwareness, 50);

      final reload = SkillState();
      await reload.load();
      expect(reload.xpFor(MusicalSkill.pitchAwareness), 50);
    });
  });
}

import 'package:ear_trainer/games/game_levels.dart';
import 'package:ear_trainer/games/loud_quiet/models/dynamic_ladder.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  playableCeilingTests();
  test('High vs Low is capped at T4 until the three-note layout exists '
      '(Cooper, 2026-11-22); Loud or Quiet reaches its whole ladder', () {
    expect(GameLevels.ceilingOf(GameLevels.highLow), ConceptTier.t4.index);
    expect(GameLevels.clamp(GameLevels.highLow, 6), ConceptTier.t4.index);
    expect(
      GameLevels.ceilingOf(GameLevels.loudQuiet),
      DynamicLadder.standard.length - 1,
    );
    expect(GameLevels.clamp(GameLevels.loudQuiet, -2), 0);
  });

  test('labels read as an adult would say them', () {
    expect(GameLevels.label(GameLevels.highLow, 0), 'T1');
    expect(GameLevels.label(GameLevels.loudQuiet, 2), 'step 3');
  });
}

void playableCeilingTests() {
  test(
    'promotion stops at what the child\'s agency can PLAY: Loud or Quiet '
    'needs Decide for three instruments; High vs Low needs Explore past T1',
    () {
      expect(
        GameLevels.playableCeiling(GameLevels.loudQuiet, AgencyStage.explore),
        2,
      );
      expect(
        GameLevels.playableCeiling(GameLevels.loudQuiet, AgencyStage.decide),
        5,
      );
      expect(
        GameLevels.playableCeiling(GameLevels.highLow, AgencyStage.observe),
        0,
      );
      expect(
        GameLevels.playableCeiling(GameLevels.highLow, AgencyStage.explore),
        3,
      );
      expect(
        GameLevels.playableCeiling(GameLevels.highLow, AgencyStage.decide),
        3,
        reason: 'the T4 cap',
      );
    },
  );
}

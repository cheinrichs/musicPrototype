import 'package:ear_trainer/games/game_levels.dart';
import 'package:ear_trainer/games/loud_quiet/models/dynamic_ladder.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

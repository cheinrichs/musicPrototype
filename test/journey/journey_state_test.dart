import 'package:ear_trainer/app/rail_destination.dart';
import 'package:ear_trainer/journey/journey_state.dart';
import 'package:ear_trainer/journey/reward_catalogue.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('milestones and the chest', () {
    test('every fifth stone is a milestone', () {
      expect(
        [for (var i = 0; i < 12; i++) JourneyState.isMilestone(i)],
        [
          false,
          false,
          false,
          false,
          true,
          false,
          false,
          false,
          false,
          true,
          false,
          false,
        ],
      );
    });

    test('the one chest is always ahead, at the next milestone', () {
      final j = JourneyState();
      expect(j.chestStone, 4);
      for (var i = 0; i < 4; i++) {
        j.completeStone(j.rewardsForCurrent());
      }
      expect(j.current, 4);
      expect(j.chestStone, 4, reason: 'standing on it');
      j.completeStone(j.rewardsForCurrent());
      expect(j.chestStone, 9, reason: 'a new chest at the next milestone');
    });
  });

  group('rewards', () {
    test('a regular stone earns one rail reward, a milestone two and a '
        'decoration', () {
      final j = JourneyState();
      expect(j.rewardsForCurrent().map((r) => r.typeId), ['song']);
      for (var i = 0; i < 4; i++) {
        j.completeStone(j.rewardsForCurrent());
      }
      final m = j.rewardsForCurrent();
      expect(m.where((r) => !r.type.onMap), hasLength(2));
      expect(m.where((r) => r.type.onMap), hasLength(1));
      expect(m.every((r) => r.stone == 4), isTrue);
    });

    test('songs and new instruments both live in Playground; games and '
        'crafts in theirs; decorations on the map', () {
      RailDestination? to(String id) => rewardTypeOf(id).destination;
      expect(to('song'), RailDestination.playground);
      expect(to('instrument'), RailDestination.playground);
      expect(to('game_unlock'), RailDestination.games);
      expect(to('craft'), RailDestination.crafts);
      expect(rewardTypeOf('decoration').onMap, isTrue);
    });

    test('each reward of a kind is a different one (the next instrument)', () {
      final j = JourneyState();
      final instruments = <int>[];
      for (var i = 0; i < 12; i++) {
        for (final r in j.rewardsForCurrent()) {
          if (r.typeId == 'instrument') instruments.add(r.index);
        }
        j.completeStone(j.rewardsForCurrent());
      }
      expect(instruments, [for (var i = 0; i < instruments.length; i++) i]);
      expect(instruments.length, greaterThan(1));
    });

    test('decorations go to the map, not the rail', () {
      final j = JourneyState();
      for (var i = 0; i < 5; i++) {
        j.completeStone(j.rewardsForCurrent());
      }
      expect(j.decorations, hasLength(1));
      expect(railRewardRotation, isNot(contains(milestoneDecoration)));
    });
  });

  group('a stone', () {
    test('is 3, 4 or 5 rounds by agency', () {
      for (final (agency, n) in [
        (AgencyStage.observe, 3),
        (AgencyStage.explore, 4),
        (AgencyStage.decide, 5),
      ]) {
        final rounds = JourneyState.plan(
          0,
          JourneyState.stoneLength(agency),
        ).fold(0, (s, p) => s + p.rounds);
        expect(rounds, n);
      }
    });

    test('never plays the same game twice in a row', () {
      for (var stone = 0; stone < 6; stone++) {
        final plan = JourneyState.plan(stone, 5);
        for (var i = 1; i < plan.length; i++) {
          expect(plan[i].gameId, isNot(plan[i - 1].gameId));
        }
      }
    });

    test('keeps its plan and place across leaving, and records the date', () {
      final j = JourneyState();
      final plan = j.planFor(AgencyStage.explore);
      j.finishPart();
      expect(j.planFor(AgencyStage.explore), same(plan));
      expect(j.partsDone, 1);
      final when = DateTime(2026, 11, 12);
      j.completeStone(const [], at: when);
      expect(j.partsDone, 0);
      expect(j.completedAt, [when]);
    });

    test('each profile has its own journey', () {
      final j = JourneyState()..useProfile('a');
      j.completeStone(j.rewardsForCurrent());
      j.useProfile('b');
      expect(j.current, 0);
      j.useProfile('a');
      expect(j.current, 1);
    });
  });

  group('the reward catalogue is data', () {
    test('every type in the schedule exists, ids are unique', () {
      final ids = rewardTypes.map((t) => t.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final id in [...railRewardRotation, milestoneDecoration]) {
        expect(() => rewardTypeOf(id), returnsNormally, reason: id);
      }
      expect(() => rewardTypeOf('nope'), throwsArgumentError);
    });

    test("every token's region lies inside its image", () {
      for (final t in rewardTypes) {
        final token = t.token;
        if (token == null) continue;
        final bounds = Offset.zero & token.image;
        expect(bounds.contains(token.region.topLeft), isTrue, reason: t.id);
        expect(
          token.region.right <= bounds.right &&
              token.region.bottom <= bounds.bottom,
          isTrue,
          reason: t.id,
        );
      }
    });
  });
}

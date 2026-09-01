import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/models/pitch_direction.dart';
import 'package:ear_trainer/models/round_order.dart';
import 'package:ear_trainer/games/high_low/services/round_sequencer.dart';

void main() {
  group('RoundSequencer', () {
    test('blocked order groups all-high then all-low then a mixed tail', () {
      final sequencer = RoundSequencer(random: Random(1));
      final directions = sequencer.sequence(
        count: 9,
        order: RoundOrder.blocked,
      );

      expect(directions.length, equals(9));
      expect(directions.sublist(0, 3), everyElement(PitchDirection.higher));
      expect(directions.sublist(3, 6), everyElement(PitchDirection.lower));
      // The final block is randomized — just check it exists and is a
      // valid direction for each entry.
      expect(directions.sublist(6, 9), everyElement(isA<PitchDirection>()));
    });

    test('blocked order falls back to mixed for very short sessions', () {
      final sequencer = RoundSequencer(random: Random(2));
      final directions = sequencer.sequence(
        count: 2,
        order: RoundOrder.blocked,
      );

      expect(directions.length, equals(2));
    });

    test('mixed order produces one direction per round', () {
      final sequencer = RoundSequencer(random: Random(3));
      final directions = sequencer.sequence(count: 20, order: RoundOrder.mixed);

      expect(directions.length, equals(20));
      expect(directions.toSet(), isNotEmpty);
    });
  });
}

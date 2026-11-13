import 'dart:io';

import 'package:ear_trainer/curriculum/curriculum.dart';
import 'package:ear_trainer/curriculum/curriculum_data.g.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_curriculum.dart' as generator;

/// The curriculum is generated into Dart at build time — never a CSV parsed
/// on a device — so a malformed row fails the build, not a child's launch.
void main() {
  final progression = File(
    'docs/curriculum/skill_progression_working.csv',
  ).readAsStringSync();
  final nodes = File('docs/curriculum/nodes.csv').readAsStringSync();

  test('the generated Dart is current with docs/curriculum/', () {
    expect(
      File('lib/curriculum/curriculum_data.g.dart').readAsStringSync(),
      generator.generate(progression, nodes),
      reason: 'run: dart run tool/generate_curriculum.dart',
    );
  });

  group('a malformed sheet fails generation', () {
    const header = 'Node,Skill,Tier,MinAgency,MaxAgency,Prerequisite,Status\n';
    const nodeCsv = 'Node,LearningGoal,Explanation\nSound Awareness,g,e\n';
    for (final (name, row) in [
      ('an unknown agency code', 'Sound Awareness,X,1,A9,A2,,'),
      ('a tier that is not a number', 'Sound Awareness,X,one,A0,A2,,'),
      ('a node not in nodes.csv', 'Nowhere,X,1,A0,A2,,'),
      ('min agency above max', 'Sound Awareness,X,1,A2,A0,,'),
      ('a blank skill', 'Sound Awareness,,1,A0,A2,,'),
    ]) {
      test(name, () {
        expect(
          () => generator.generate('$header$row\n', nodeCsv),
          throwsA(anything),
        );
      });
    }

    test('the same game-tier twice', () {
      expect(
        () => generator.generate(
          '${header}Sound Awareness,X,1,A0,A2,,\nSound Awareness,X,1,A0,A2,,\n',
          nodeCsv,
        ),
        throwsA(anything),
      );
    });
  });

  test('every tier is generated as authored — tier 4 is never dropped by '
      'rule (Pitch Awareness keeps all four)', () {
    for (final node in skillNodes) {
      final tiers = {
        for (final r in sheetRequirements)
          if (r.skillNode == node) r.tier,
      };
      expect(tiers, contains(4), reason: node);
    }
  });

  test('at runtime, the built games run on their own ladders: High vs Low '
      'its eight tiers, Loud or Quiet its three steps', () {
    Set<int> tiersOf(String game) => {
      for (final r in requirements)
        if (r.game == game) r.tier,
    };
    expect(tiersOf('Higher vs Lower'), {1, 2, 3, 4, 5, 6, 7, 8});
    expect(tiersOf('Loud vs Soft'), {1, 2, 3});
  });
}

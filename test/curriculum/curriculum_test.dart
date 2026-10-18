import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/curriculum/csv_table.dart';
import 'package:ear_trainer/curriculum/curriculum.dart';
import 'package:ear_trainer/models/agency_stage.dart';

void main() {
  group('parseCsvTable', () {
    test('reads quoted commas, doubled quotes, newlines in quotes, CRLF and '
        'the byte-order mark Sheets writes', () {
      const csv = '﻿A,B\r\n1,"two, and ""three"""\r\n"multi\nline",x\r\n\r\n';
      final rows = parseCsvTable(csv);
      expect(rows, [
        {'A': '1', 'B': 'two, and "three"'},
        {'A': 'multi\nline', 'B': 'x'},
      ]);
    });
  });

  group('agencyFromSheet (card 219: the app has three levels, not five)', () {
    test('A0 Observe, A1 Explore, and A2, A3, A4 all Decide', () {
      expect(agencyFromSheet('A0'), AgencyStage.observe);
      expect(agencyFromSheet('A1 — Participate'), AgencyStage.explore);
      for (final code in ['A2', 'A3', 'A4 — Precision']) {
        expect(agencyFromSheet(code), AgencyStage.decide);
      }
    });

    test('anything else is an error, never a silent default', () {
      expect(() => agencyFromSheet('A5'), throwsFormatException);
    });
  });

  group('parseSkillProgression', () {
    const sheet =
        'Node,Skill,Tier,MinAgency,MaxAgency,Prerequisite\n'
        'Pitch Awareness,Higher vs Lower,3,A2,A4,Higher vs Lower_T2\n'
        'Pitch Awareness,Same Note Match,1,A1,A3,Higher vs Lower_T1\n';

    test('the BUILT games\' rows come from their own ladders, not the sheet: '
        'High vs Low has eight tiers, and its T3 is reachable at Explore', () {
      final rows = parseSkillProgression(sheet, games: builtGames);
      final hvl = rows.where((r) => r.game == 'Higher vs Lower').toList();
      expect(hvl.map((r) => r.tier), [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(hvl[0].minAgency, AgencyStage.observe);
      expect(hvl[2].minAgency, AgencyStage.explore);
      expect(hvl[4].minAgency, AgencyStage.decide);
    });

    test('other games are imported, remapped, with the sheet\'s '
        'prerequisite kept for reference', () {
      final rows = parseSkillProgression(sheet, games: builtGames);
      final snm = rows.singleWhere((r) => r.game == 'Same Note Match');
      expect(snm.minAgency, AgencyStage.explore);
      expect(snm.maxAgency, AgencyStage.decide);
      expect(snm.sheetPrerequisite, 'Higher vs Lower_T1');
    });
  });

  group('Eligibility (card 201)', () {
    final rows = parseSkillProgression(
      'Node,Skill,Tier,MinAgency,MaxAgency,Prerequisite\n',
      games: builtGames,
    );

    test('WORKS WITH NO PREREQUISITES AT ALL (card 219): both built games '
        'are eligible at every agency, at tier 1', () {
      const eligibility = Eligibility([]);
      final full = Eligibility(rows);
      expect(eligibility.prerequisites, isEmpty);
      for (final agency in AgencyStage.values) {
        expect(full.pool(games: builtGames, agency: agency).map((g) => g.id), [
          'high_low',
          'loud_quiet',
        ]);
      }
    });

    test('a tier above what the child\'s agency reaches is not eligible', () {
      final e = Eligibility(rows);
      expect(
        e.isEligible('Higher vs Lower', 5, agency: AgencyStage.explore),
        isFalse,
      );
      expect(
        e.isEligible('Higher vs Lower', 5, agency: AgencyStage.decide),
        isTrue,
      );
    });

    test('tier is per game: each game is filtered at the child\'s own tier '
        'for it', () {
      final e = Eligibility(rows);
      final pool = e.pool(
        games: builtGames,
        agency: AgencyStage.explore,
        tierOf: (g) => g.id == 'high_low' ? 5 : 1,
      );
      expect(pool.map((g) => g.id), ['loud_quiet']);
    });

    test('prerequisites, once someone adds one, gate on completed '
        'game-tiers', () {
      final e = Eligibility(
        rows,
        prerequisites: {
          'Loud vs Soft_T1': {'Higher vs Lower_T1'},
        },
      );
      expect(
        e.isEligible('Loud vs Soft', 1, agency: AgencyStage.observe),
        isFalse,
      );
      expect(
        e.isEligible(
          'Loud vs Soft',
          1,
          agency: AgencyStage.observe,
          completed: {'Higher vs Lower_T1'},
        ),
        isTrue,
      );
    });

    test('a game-tier with no row is not eligible', () {
      expect(
        Eligibility(
          rows,
        ).isEligible('Higher vs Lower', 9, agency: AgencyStage.decide),
        isFalse,
      );
    });
  });

  test('the repo\'s old snapshot still parses whole — every row, every '
      'agency code', () {
    final csv = File(
      'docs/curriculum/skill_progression_working.csv',
    ).readAsStringSync();
    final rows = parseSkillProgression(csv, games: builtGames);
    final sheetRows = parseCsvTable(csv).length;
    final replaced = parseCsvTable(
      csv,
    ).where((r) => builtGames.any((g) => g.name == r['Skill'])).length;
    expect(rows.length, sheetRows - replaced + 16);
  });
}

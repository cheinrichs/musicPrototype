import 'dart:io';

import 'package:ear_trainer/app/credits_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Attribution the LICENCE requires must never be tidied away with the
/// courtesies (2026-11-14).
void main() {
  final entries = [for (final s in creditSections) ...s.entries];

  test("the CC BY 4.0 handbells' credit is present and marked REQUIRED — "
      'removing it would breach the licence', () {
    final bells = entries.where((e) => e.creator == 'InspectorJ');
    expect(bells, hasLength(1));
    expect(bells.single.attributionRequired, isTrue);
    expect(bells.single.license, contains('CC BY 4.0'));
    expect(bells.single.sourceUrl, contains('freesound.org'));
  });

  test('Philharmonia and Iowa are courtesies, and never described as '
      'Creative Commons', () {
    for (final creator in [
      'Philharmonia Orchestra',
      'University of Iowa Electronic Music Studios',
    ]) {
      final e = entries.singleWhere((e) => e.creator == creator);
      expect(e.attributionRequired, isFalse, reason: creator);
      expect(e.license, isNot(contains('CC')), reason: creator);
    }
  });

  test('every note library has its provenance record on disk', () {
    for (final dir in Directory('assets/audio/notes').listSync()) {
      if (dir is! Directory) continue;
      final hasMp3 = dir.listSync().any((f) => f.path.endsWith('.mp3'));
      if (!hasMp3) continue;
      final name = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final record = name == 'bells' ? 'ATTRIBUTION.md' : 'PROVENANCE.md';
      expect(
        File('${dir.path}/$record').existsSync(),
        isTrue,
        reason: '$name has no $record',
      );
    }
  });
}

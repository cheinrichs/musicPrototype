import 'dart:math' as math;

import 'package:ear_trainer/ui/components/reading_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reading gate: a SIGNPOST, not a lock — and reusable.
void main() {
  group('the puzzle', () {
    test('three targets among nine distinct numerals', () {
      for (var seed = 0; seed < 200; seed++) {
        final p = ReadingGatePuzzle.generate(math.Random(seed));
        expect(p.grid.toSet(), hasLength(9));
        expect(p.targets.toSet(), hasLength(3));
        expect(p.grid, containsAll(p.targets));
      }
    });

    test('THE PROMPT SPELLS THE NUMBERS AS WORDS — never a numeral', () {
      expect(numberInWords(42), 'FORTY-TWO');
      expect(numberInWords(52), 'FIFTY-TWO');
      expect(numberInWords(96), 'NINETY-SIX');
      expect(numberInWords(70), 'SEVENTY');
      expect(numberInWords(13), 'THIRTEEN');
      for (var seed = 0; seed < 200; seed++) {
        for (final w in ReadingGatePuzzle.generate(math.Random(seed)).words) {
          expect(w, isNot(matches(RegExp(r'\d'))));
        }
      }
    });

    test('a fresh puzzle every time: nothing to remember, nothing kept', () {
      final seen = {
        for (var i = 0; i < 20; i++)
          ReadingGatePuzzle.generate().targets.join(),
      };
      expect(seen.length, greaterThan(1));
    });
  });

  Future<List<bool?>> open(WidgetTester tester, ReadingGatePuzzle p) async {
    tester.view.physicalSize = const Size(667, 375) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final results = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => ReadingGate(puzzle: p)),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  const puzzle = ReadingGatePuzzle(
    targets: [42, 52, 96],
    grid: [50, 42, 51, 96, 52, 92, 30, 61, 77],
  );

  testWidgets('the prompt shows words; the grid numerals; it fits an SE', (
    tester,
  ) async {
    await open(tester, puzzle);
    expect(tester.takeException(), isNull);
    for (final w in ['FORTY-TWO', 'FIFTY-TWO', 'NINETY-SIX']) {
      expect(find.text(w), findsOneWidget);
    }
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('tapped in order, it lets the grown-up through', (tester) async {
    final results = await open(tester, puzzle);
    for (final n in [42, 52, 96]) {
      await tester.tap(find.byKey(ValueKey('reading-gate-$n')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('a wrong tap QUIETLY resets — no message — and the order '
      'must start again', (tester) async {
    final results = await open(tester, puzzle);
    final textsBefore = find.byType(Text).evaluate().length;
    await tester.tap(find.byKey(const ValueKey('reading-gate-42')));
    await tester.tap(find.byKey(const ValueKey('reading-gate-50')));
    await tester.pump();
    expect(find.byType(Text).evaluate().length, textsBefore, reason: 'silent');
    // 52 then 96 now would not pass: the attempt was reset.
    await tester.tap(find.byKey(const ValueKey('reading-gate-52')));
    await tester.tap(find.byKey(const ValueKey('reading-gate-96')));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    for (final n in [42, 52, 96]) {
      await tester.tap(find.byKey(ValueKey('reading-gate-$n')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('THE EXIT: one large top-corner tap, straight back out', (
    tester,
  ) async {
    final results = await open(tester, puzzle);
    final exit = tester.getRect(
      find.byKey(const ValueKey('reading-gate-exit')),
    );
    expect(exit.width, greaterThanOrEqualTo(64), reason: 'large');
    expect(exit.top, lessThan(24), reason: 'top corner');
    expect(exit.left, lessThan(24));
    await tester.tap(find.byKey(const ValueKey('reading-gate-exit')));
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(find.byType(ReadingGate), findsNothing);
  });
}

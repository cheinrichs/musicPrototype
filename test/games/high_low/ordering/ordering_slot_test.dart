import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_slot.dart';
import 'package:ear_trainer/ui/theme/theme.dart';

Future<void> pumpSlot(
  WidgetTester tester,
  SlotState state, {
  SlotStyle? style,
}) => tester.pumpWidget(
  MaterialApp(
    home: Center(
      child: style == null
          ? OrderingSlot(state: state, size: const Size(80, 22))
          : OrderingSlot(state: state, size: const Size(80, 22), style: style),
    ),
  ),
);

void main() {
  group('slot states', () {
    test('there are exactly four — and none of them is a "wrong" state. '
        'A slot never marks a mistake: right placements are ticked, wrong '
        'ones simply go home ("describe the answer, not the attempt")', () {
      expect(SlotState.values.map((s) => s.name).toSet(), {
        'empty',
        'hovering',
        'filled',
        'confirmed',
      });
    });

    test('each state looks different from the others', () {
      const style = SoftDepressionSlotStyle();
      final looks = {for (final s in SlotState.values) s: style.look(s)};
      expect(looks.values.toSet().length, 4);
    });

    test('empty asks for something with a "?", and only empty does — a '
        'literacy symbol, acceptable here because nobody reaches A4 '
        'ordering at two or three', () {
      const style = SoftDepressionSlotStyle();
      expect(style.look(SlotState.empty).glyph, isTrue);
      for (final s in [
        SlotState.hovering,
        SlotState.filled,
        SlotState.confirmed,
      ]) {
        expect(style.look(s).glyph, isFalse, reason: '$s');
      }
    });

    test('an instrument passing over draws the slot up to meet it', () {
      const style = SoftDepressionSlotStyle();
      expect(style.look(SlotState.hovering).scale, greaterThan(1.0));
      expect(style.look(SlotState.empty).scale, 1.0);
    });

    test('only a confirmed slot is green; nothing on any slot is red', () {
      const style = SoftDepressionSlotStyle();
      expect(style.look(SlotState.confirmed).ringColor, AppColors.correct);
      for (final s in SlotState.values) {
        final look = style.look(s);
        for (final c in [look.color, look.ringColor, look.glyphColor]) {
          if (c == null) continue;
          expect(
            c.r > 0.6 && c.g < 0.35 && c.b < 0.35,
            isFalse,
            reason: '$s uses a red-ish colour $c',
          );
          expect(c, isNot(AppColors.incorrect), reason: '$s uses rose');
          expect(c, isNot(AppColors.incorrectLight), reason: '$s uses rose');
        }
      }
    });
  });

  group('OrderingSlot', () {
    testWidgets('shows a question mark while empty and not otherwise', (
      tester,
    ) async {
      await pumpSlot(tester, SlotState.empty);
      expect(find.text('?'), findsOneWidget);
      for (final s in [
        SlotState.hovering,
        SlotState.filled,
        SlotState.confirmed,
      ]) {
        await pumpSlot(tester, s);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('?'), findsNothing, reason: '$s');
      }
    });

    testWidgets('the whole treatment is one swappable decision: a different '
        'style changes the look without touching anything else', (
      tester,
    ) async {
      const soft = SoftDepressionSlotStyle();
      const grey = GreyQuestionSlotStyle();
      expect(
        soft.look(SlotState.empty).color,
        isNot(grey.look(SlotState.empty).color),
      );

      await pumpSlot(tester, SlotState.empty, style: grey);
      expect(
        find.text('?'),
        findsOneWidget,
        reason: 'same states, same glyph rule',
      );
      expect(orderingSlotStyle, isA<SlotStyle>());
    });

    testWidgets('occupies exactly the size it is given, so it lands on a '
        'platform', (tester) async {
      await pumpSlot(tester, SlotState.empty);
      expect(tester.getSize(find.byType(OrderingSlot)), const Size(80, 22));
    });
  });

  group('PlacementTick', () {
    testWidgets('is a green tick, labelled for assistive tech', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: PlacementTick(size: 28))),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Correct'), findsOneWidget);
      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(PlacementTick),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((decorated.decoration as BoxDecoration).color, AppColors.correct);
    });

    testWidgets('has no cross, and no red, in any form', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: PlacementTick(size: 28))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });
  });
}

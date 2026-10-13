import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_slot.dart';
import 'package:ear_trainer/ui/theme/theme.dart';

Future<void> pumpSlot(WidgetTester tester, SlotState state) =>
    tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: OrderingSlot(state: state, size: const Size(110, 90)),
        ),
      ),
    );

void main() {
  const style = DashedSlotStyle();

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

    test('an EMPTY slot is visible before any drag begins — a dashed '
        'outline with a note in it (Trello card 215): a slot only shown '
        'mid-drag teaches nothing to a child who has not found dragging', () {
      final empty = style.look(SlotState.empty);
      expect(empty.invisible, isFalse);
      expect(empty.outline, isNotNull);
      expect(empty.dashed, isTrue);
      expect(empty.glyph, isTrue);
    });

    test('a drag passing over STRENGTHENS it: heavier wash, thicker solid '
        'line, drawn up to meet the instrument', () {
      final empty = style.look(SlotState.empty);
      final hover = style.look(SlotState.hovering);
      expect(hover.fillOpacity, greaterThan(empty.fillOpacity));
      expect(hover.outlineWidth, greaterThan(empty.outlineWidth));
      expect(hover.scale, greaterThan(1.0));
      expect(empty.scale, 1.0);
    });

    test('filled or confirmed it draws nothing — the instrument standing '
        'there, and its tick, say it', () {
      expect(style.look(SlotState.filled).invisible, isTrue);
      expect(style.look(SlotState.confirmed).invisible, isTrue);
    });

    test('it is a layer ON the painting, not part of it: cool colours only, '
        'outside the dial\'s cream → gold → orange ramp, and never red', () {
      for (final s in SlotState.values) {
        final look = style.look(s);
        for (final c in [look.fill, look.outline]) {
          if (c == null) continue;
          expect(c.b, greaterThanOrEqualTo(c.r), reason: '$s: $c is warm');
          expect([
            AppColors.ivory,
            AppColors.gold,
            AppColors.fox,
          ], isNot(contains(c)));
          expect(c, isNot(AppColors.incorrect), reason: '$s uses rose');
        }
      }
    });
  });

  group('OrderingSlot', () {
    testWidgets('shows a note while empty or hovered, never a "?"', (
      tester,
    ) async {
      for (final s in [SlotState.empty, SlotState.hovering]) {
        await pumpSlot(tester, s);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
        expect(find.text('?'), findsNothing);
      }
      for (final s in [SlotState.filled, SlotState.confirmed]) {
        await pumpSlot(tester, s);
        expect(find.byIcon(Icons.music_note_rounded), findsNothing);
      }
    });

    test('the outline stands on the platform face and rises about an '
        'instrument\'s height, inside the drop target', () {
      const size = Size(110, 90);
      final box = OrderingSlot.outlineRect(size);
      final face = size.height * OrderingSlot.faceFraction;
      expect(box.bottom, greaterThan(face));
      expect(box.bottom, lessThanOrEqualTo(size.height));
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.height, greaterThan(box.width));
      expect(box.center.dx, closeTo(size.width / 2, 0.001));
    });

    testWidgets('occupies exactly the drop target it is given', (tester) async {
      await pumpSlot(tester, SlotState.empty);
      expect(tester.getSize(find.byType(OrderingSlot)), const Size(110, 90));
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

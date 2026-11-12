import 'dart:math';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_game_state.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_layout.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_screen.dart';
import 'package:ear_trainer/games/high_low/ordering/ordering_slot.dart';
import 'package:ear_trainer/games/high_low/services/prompt_generator.dart';
import 'package:ear_trainer/games/high_low/widgets/retry_settle.dart';
import 'package:ear_trainer/models/concept_tier.dart';
import 'package:ear_trainer/ui/components/drop_snap.dart';
import 'package:ear_trainer/ui/theme/theme.dart';

const viewport = Size(844, 390);

Future<OrderingGameState> pumpOrdering(
  WidgetTester tester, {
  ConceptTier tier = ConceptTier.t5,
  int seed = 1,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final state = OrderingGameState(
    tier: tier,
    totalPrompts: 3,
    generator: PromptGenerator(random: Random(seed)),
    playNote: (_) async {},
  );
  await tester.pumpWidget(
    MaterialApp(
      home: OrderingScreen(tier: tier, state: state),
    ),
  );
  await tester.pump();
  await tester.pump(OrderingGameState.noteGap * 4);
  await tester.pump(Duration.zero);
  return state;
}

Finder instrument(int note) => find.byKey(ValueKey('instrument-$note'));
Finder slot(int index) => find.byKey(ValueKey('slot-$index'));

Offset topLeftOf(WidgetTester tester, Finder f) => tester.getTopLeft(f);

Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  await tester.pump(const Duration(milliseconds: 20));
  const steps = 8;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump(const Duration(milliseconds: 20));
  }
  await gesture.up();
  await tester.pump();
  await tester.pump(Duration.zero);
}

Future<void> dragNoteToSlot(WidgetTester tester, int note, int index) => drag(
  tester,
  tester.getCenter(instrument(note)),
  tester.getCenter(slot(index)),
);

void main() {
  group('OrderingScreen', () {
    testWidgets('an instrument dragged onto a platform lands there, and every '
        'other instrument stays exactly where it was — nothing reflows', (
      tester,
    ) async {
      final state = await pumpOrdering(tester);
      final before = {
        for (final n in [1, 2]) n: topLeftOf(tester, instrument(n)),
      };
      final homeBefore = topLeftOf(tester, instrument(0));

      await dragNoteToSlot(tester, 0, 0);
      await tester.pump(const Duration(milliseconds: 400));

      expect(state.placements, {0: 0});
      expect(topLeftOf(tester, instrument(0)), isNot(homeBefore));
      for (final n in [1, 2]) {
        expect(
          topLeftOf(tester, instrument(n)),
          before[n],
          reason: 'stump $n must not move when note 0 leaves',
        );
      }
      state.dispose();
    });

    testWidgets('a vacated stump keeps a greyed ghost, so a child can '
        're-find where the instrument lives', (tester) async {
      final state = await pumpOrdering(tester);
      // What is actually painted, not the animation's target: an implicit
      // animation only starts on the first frame after the change.
      double ghost(int n) => tester
          .renderObject<RenderAnimatedOpacity>(find.byKey(ValueKey('ghost-$n')))
          .opacity
          .value;
      expect(ghost(0), 0);

      await dragNoteToSlot(tester, 0, 0);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 600));

      expect(ghost(0), OrderingScreen.ghostOpacity);
      expect(ghost(1), 0, reason: 'only the one that left');
      state.dispose();
    });

    testWidgets('an empty platform asks for something; a filled one does not', (
      tester,
    ) async {
      final state = await pumpOrdering(tester);
      expect(find.byIcon(Icons.music_note_rounded), findsNWidgets(3));

      await dragNoteToSlot(tester, 0, 1);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.music_note_rounded), findsNWidgets(2));
      state.dispose();
    });

    testWidgets('nothing is checked, ticked or sent back until every platform '
        'is filled', (tester) async {
      final state = await pumpOrdering(tester);
      final r = state.round!;

      await dragNoteToSlot(tester, 0, r.correctSlotOf(0));
      await dragNoteToSlot(tester, 1, r.correctSlotOf(1));
      await tester.pump(const Duration(seconds: 3));

      expect(find.byType(PlacementTick), findsNothing);
      expect(state.evaluations, 0);
      state.dispose();
    });

    testWidgets('right ones get a tick that stays; wrong ones go back to '
        'their stumps and carry NO mark of any kind', (tester) async {
      final state = await pumpOrdering(tester);
      final r = state.round!;
      final right = [for (var n = 0; n < 3; n++) r.correctSlotOf(n)];
      // The header's own Close button is an X; that's the baseline. What
      // must never happen is a check adding another.
      final closeIconsBefore = find
          .byIcon(Icons.close_rounded)
          .evaluate()
          .length;

      // Note 0 right; swap the other two.
      await dragNoteToSlot(tester, 0, right[0]);
      await dragNoteToSlot(tester, 1, right[2]);
      await dragNoteToSlot(tester, 2, right[1]);
      await tester.pump(OrderingGameState.evaluateDelay);
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.lockedNotes, {0});
      expect(find.byType(PlacementTick), findsOneWidget);
      expect(find.byKey(const ValueKey('tick-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('tick-1')), findsNothing);
      expect(find.byKey(const ValueKey('tick-2')), findsNothing);

      // The tick persists — still there well after the fact.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('tick-0')), findsOneWidget);

      // No cross, and no incorrect colour anywhere on screen.
      expect(
        find.byIcon(Icons.close_rounded).evaluate().length,
        closeIconsBefore,
        reason: 'a check must not add a cross',
      );
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);
      final rose = [AppColors.incorrect, AppColors.incorrectLight];
      final offenders = <String>[];
      void visit(Element e) {
        final w = e.widget;
        if (w is DecoratedBox && w.decoration is BoxDecoration) {
          final c = (w.decoration as BoxDecoration).color;
          if (c != null && rose.contains(c)) offenders.add('$w');
        }
        e.visitChildren(visit);
      }

      tester.element(find.byType(OrderingScreen)).visitChildren(visit);
      expect(offenders, isEmpty);

      // And they are home: at their own stump positions — allowing for
      // every instrument's own small float above the stump surface (Cooper,
      // on device: "they read as embedded in the wood" — see
      // [HighLowInstrument.floatFraction]), not just bells' larger one.
      final layout = OrderingLayout(viewport, noteCount: 3);
      for (final n in [1, 2]) {
        final feet = layout.stumpFeet(n);
        final instrumentInstance = r.notes[n].instrument;
        final size =
            layout.stumpInstrumentSize * instrumentInstance.displaySizeScale;
        final lift = size * instrumentInstance.floatFraction;
        final box = tester.getRect(instrument(n));
        expect(box.bottomCenter.dx, closeTo(feet.dx, 1.0), reason: 'note $n');
        expect(box.bottom, closeTo(feet.dy - lift, 1.0), reason: 'note $n');
      }
      state.dispose();
    });

    testWidgets('wrong placements return with the shared RetrySettle — the '
        'same spring a wrong drag uses at A2, not a second wobble', (
      tester,
    ) async {
      final state = await pumpOrdering(tester);
      final r = state.round!;
      final right = [for (var n = 0; n < 3; n++) r.correctSlotOf(n)];

      await dragNoteToSlot(tester, 0, right[0]);
      await dragNoteToSlot(tester, 1, right[2]);
      await dragNoteToSlot(tester, 2, right[1]);
      await tester.pump(OrderingGameState.evaluateDelay);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(RetrySettle), findsNWidgets(2));
      state.dispose();
    });

    testWidgets('a wrong placement leaves nothing on its platform: it is '
        'empty and asking again, not marked', (tester) async {
      final state = await pumpOrdering(tester);
      final r = state.round!;
      final right = [for (var n = 0; n < 3; n++) r.correctSlotOf(n)];

      await dragNoteToSlot(tester, 0, right[0]);
      await dragNoteToSlot(tester, 1, right[2]);
      await dragNoteToSlot(tester, 2, right[1]);
      await tester.pump(OrderingGameState.evaluateDelay);
      await tester.pump(const Duration(milliseconds: 500));

      // Two platforms went back to empty (a "?" each).
      expect(find.byIcon(Icons.music_note_rounded), findsNWidgets(2));
      state.dispose();
    });

    testWidgets('a drop that misses every platform goes home the same way', (
      tester,
    ) async {
      final state = await pumpOrdering(tester);

      await drag(
        tester,
        tester.getCenter(instrument(0)),
        const Offset(60, 120),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(state.placements, isEmpty);
      expect(find.byType(RetrySettle), findsOneWidget);
      state.dispose();
    });

    // Card 221: the drop is judged by where the instrument is, with the same
    // test lighting a platform as landing on it.
    group('card 221: where a drop on a platform lands', () {
      Rect slotRect(OrderingGameState state, int slot) {
        final layout = OrderingLayout(
          viewport,
          noteCount: state.round!.notes.length,
        );
        return layout.slotRect(layout.freePlatforms[slot]);
      }

      /// Drags [note] so the instrument's centre ends at [to] (the finger
      /// holds its middle here), and reports which platform was lit just
      /// before release.
      Future<int?> dragLit(WidgetTester tester, int note, Offset to) async {
        final from = tester.getCenter(instrument(note));
        final gesture = await tester.startGesture(from);
        await tester.pump(const Duration(milliseconds: 20));
        for (var i = 1; i <= 8; i++) {
          await gesture.moveTo(Offset.lerp(from, to, i / 8)!);
          await tester.pump(const Duration(milliseconds: 20));
        }
        int? lit;
        for (var s = 0; s < 3; s++) {
          final f = slot(s);
          if (f.evaluate().isEmpty) continue;
          if (tester.widget<OrderingSlot>(f).state == SlotState.hovering) {
            lit = s;
          }
        }
        await gesture.up();
        await tester.pump();
        await tester.pump(Duration.zero);
        return lit;
      }

      for (final s in [0, 1, 2]) {
        final near = <String, Offset Function(Rect, double)>{
          'on it': (r, _) => r.center,
          'just left of it': (r, rad) => r.centerLeft - Offset(rad * 0.9, 0),
          'just right of it': (r, rad) => r.centerRight + Offset(rad * 0.9, 0),
        };
        for (final MapEntry(key: name, value: at) in near.entries) {
          // The platforms zig-zag up the trunk, so beside one can be nearer
          // its neighbour: whichever is nearest is the one that lights, and
          // the one it lands on.
          testWidgets('platform $s, released $name: the nearest platform '
              'lights, and it lands there', (tester) async {
            final state = await pumpOrdering(tester);
            final size = tester.getSize(instrument(0)).width;
            final radius = DropSnap.radiusFor(size);
            final to = at(slotRect(state, s), radius);
            final expected = DropSnap.resolve(to, {
              for (final i in state.round!.activeSlots) i: slotRect(state, i),
            }, radius);
            expect(expected, isNotNull, reason: 'within reach of a platform');
            if (name == 'on it') expect(expected, s);
            final lit = await dragLit(tester, 0, to);
            expect(lit, expected);
            expect(state.placements, {0: expected});
            state.dispose();
          });
        }
      }

      testWidgets('released past the radius: never lit, and goes home', (
        tester,
      ) async {
        final state = await pumpOrdering(tester);
        final size = tester.getSize(instrument(0)).width;
        final r = slotRect(state, 1);
        final lit = await dragLit(
          tester,
          0,
          r.centerLeft - Offset(DropSnap.radiusFor(size) * 1.2, 0),
        );
        expect(lit, isNull);
        expect(state.placements, isEmpty);
        state.dispose();
      });

      testWidgets('between two platforms, it lands on the nearer one', (
        tester,
      ) async {
        final state = await pumpOrdering(tester);
        final a = slotRect(state, 0);
        final b = slotRect(state, 1);
        // A third of the way from platform 1's edge to platform 0's.
        final gapTop = math.min(a.bottom, b.bottom);
        final gapBottom = math.max(a.top, b.top);
        final nearB = b.top > a.top
            ? Offset(b.center.dx, gapTop + (gapBottom - gapTop) * 0.7)
            : Offset(b.center.dx, gapBottom - (gapBottom - gapTop) * 0.7);
        final lit = await dragLit(tester, 0, nearB);
        expect(lit, 1);
        expect(state.placements, {0: 1});
        state.dispose();
      });

      testWidgets('dropped on a taken platform, it is refused — never '
          'snapped onto a neighbour the child did not aim at', (tester) async {
        final state = await pumpOrdering(tester);
        await dragNoteToSlot(tester, 0, 0);
        expect(state.placements, {0: 0});
        final lit = await dragLit(tester, 1, slotRect(state, 0).center);
        expect(lit, isNull, reason: 'a taken platform never lights up');
        expect(state.placements, {0: 0});
        state.dispose();
      });
    });

    testWidgets('the hint for the grown-up is on screen from the start and '
        'stays through mistakes — not something a mistake triggers', (
      tester,
    ) async {
      final state = await pumpOrdering(tester);
      expect(find.text(OrderingScreen.caption), findsOneWidget);

      final r = state.round!;
      final right = [for (var n = 0; n < 3; n++) r.correctSlotOf(n)];
      await dragNoteToSlot(tester, 0, right[1]);
      await dragNoteToSlot(tester, 1, right[2]);
      await dragNoteToSlot(tester, 2, right[0]);
      await tester.pump(OrderingGameState.evaluateDelay);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(OrderingScreen.caption), findsOneWidget);
      state.dispose();
    });

    test('the hint stays inside the caption length budget the other '
        'captions are held to', () {
      expect(OrderingScreen.caption.length, lessThanOrEqualTo(50));
    });

    testWidgets('a two-note round shows two platforms and two stumps; the '
        'bottom step stays unoccupied', (tester) async {
      final state = await pumpOrdering(tester, tier: ConceptTier.t1);

      expect(slot(0), findsOneWidget);
      expect(slot(1), findsOneWidget);
      expect(slot(2), findsNothing);
      expect(instrument(0), findsOneWidget);
      expect(instrument(1), findsOneWidget);
      expect(instrument(2), findsNothing);
      state.dispose();
    });

    testWidgets('replay shows three offered, and fills them as they are used', (
      tester,
    ) async {
      final state = await pumpOrdering(tester);
      Color pip(int i) =>
          (tester
                      .widget<Container>(find.byKey(ValueKey('replay-pip-$i')))
                      .decoration
                  as BoxDecoration)
              .color!;
      final unused = pip(0);

      await tester.tap(find.bySemanticsLabel('Listen again'));
      await tester.pump(OrderingGameState.noteGap * 4);

      expect(state.replaysUsed, 1);
      expect(pip(0), isNot(unused));
      expect(pip(1), unused);
      state.dispose();
    });
  });
}

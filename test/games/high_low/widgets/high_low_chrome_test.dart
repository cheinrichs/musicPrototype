import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/widgets/high_low_caption.dart';
import 'package:ear_trainer/games/high_low/widgets/high_low_footer.dart';
import 'package:ear_trainer/ui/components/progress_dots.dart';
import 'package:ear_trainer/ui/theme/theme.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(alignment: Alignment.bottomCenter, child: child),
  ),
);

void main() {
  group('caption plaque', () {
    testWidgets('sits on the same cream plaque as the rest of the chrome '
        'instead of floating bare on the scenery — a caption over hills or '
        'a tree would otherwise vanish into the background', (tester) async {
      await tester.pumpWidget(
        host(const HighLowCaption(text: 'Let them explore freely.')),
      );
      await tester.pump(AppAnimations.medium);

      final plaque = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(HighLowCaption),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.gradient == AppColors.cardGradient);
      expect(plaque, isNotEmpty, reason: 'cream card gradient behind the text');
    });

    testWidgets('the text is a warm dark brown — there is no true black '
        'anywhere else in that scene', (tester) async {
      await tester.pumpWidget(
        host(const HighLowCaption(text: 'Let them explore freely.')),
      );
      await tester.pump(AppAnimations.medium);

      final text = tester.widget<Text>(find.text('Let them explore freely.'));
      final color = text.style!.color!;
      expect(color, AppColors.inkBrown);
      expect(color, isNot(Colors.black));
      expect(color.r > color.b, isTrue, reason: 'warm, not neutral');
      expect(color.r + color.g + color.b, lessThan(1.2), reason: 'still dark');
    });

    testWidgets('no caption means no plaque: nothing empty floating there', (
      tester,
    ) async {
      await tester.pumpWidget(host(const HighLowCaption(text: null)));
      await tester.pump(AppAnimations.medium);
      expect(
        find.descendant(
          of: find.byType(HighLowCaption),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });
  });

  group('footer', () {
    Widget footer({VoidCallback? onSkip, bool skipEnabled = true}) => host(
      HighLowFooter(
        leading: const Text('LISTEN'),
        totalDots: 5,
        currentIndex: 1,
        completedCount: 1,
        skipEnabled: skipEnabled,
        onSkip: onSkip,
      ),
    );

    testWidgets('Listen Again sits at the left; progress and Skip share the '
        'bottom-right corner, in that order, flush to the right edge', (
      tester,
    ) async {
      await tester.pumpWidget(footer());
      await tester.pump(Duration.zero);
      final row = tester.getRect(find.byType(HighLowFooter));
      final listen = tester.getRect(find.text('LISTEN'));
      final dots = tester.getRect(find.byType(ProgressDots));
      final skip = tester.getRect(find.byTooltip('Skip'));

      expect(listen.left, closeTo(row.left, 1.0), reason: 'left corner');
      expect(listen.right, lessThanOrEqualTo(dots.left));
      expect(dots.right, lessThanOrEqualTo(skip.left));
      expect(skip.right, closeTo(row.right, 1.0), reason: 'right corner');
    });

    testWidgets('progress and Skip are two separate objects — progress is '
        'passive and never merged into the adult\'s control', (tester) async {
      await tester.pumpWidget(footer());
      await tester.pump(Duration.zero);
      final dots = tester.getRect(find.byType(ProgressDots));
      final skip = tester.getRect(find.byTooltip('Skip'));
      expect(dots.overlaps(skip), isFalse);
      expect(
        find.descendant(
          of: find.byTooltip('Skip'),
          matching: find.byType(ProgressDots),
        ),
        findsNothing,
      );
    });

    testWidgets('a child poking the progress dots does nothing: they are '
        'non-interactive, and only Skip skips', (tester) async {
      var skips = 0;
      await tester.pumpWidget(footer(onSkip: () => skips++));
      await tester.pump(Duration.zero);

      await tester.tap(find.byType(ProgressDots), warnIfMissed: false);
      await tester.pump();
      expect(skips, 0);

      // The dots are wrapped so they cannot even take a touch.
      expect(
        find.ancestor(
          of: find.byType(ProgressDots),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );

      await tester.tap(find.byTooltip('Skip'));
      await tester.pump();
      expect(skips, 1);
    });

    testWidgets('progress is small, next to a Skip that is not smaller than '
        'it is quiet — the dots must not outweigh the control', (tester) async {
      await tester.pumpWidget(footer());
      await tester.pump(Duration.zero);
      final dots = tester.getSize(find.byType(ProgressDots));
      expect(dots.height, lessThanOrEqualTo(30));
    });

    testWidgets('the compact dots hold still — nothing loops on the corner of '
        'the screen', (tester) async {
      await tester.pumpWidget(footer());
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('a crowded row never overflows: the left side scales down to '
      'the room the corner leaves', (tester) async {
    tester.view.physicalSize = const Size(640, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      host(
        HighLowFooter(
          leading: const SizedBox(width: 600, height: 40, child: Text('WIDE')),
          totalDots: 5,
          currentIndex: 0,
          completedCount: 0,
          skipEnabled: true,
          onSkip: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

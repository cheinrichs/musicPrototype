import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/high_low/widgets/high_low_caption.dart';
import 'package:ear_trainer/games/high_low/widgets/high_low_header.dart';
import 'package:ear_trainer/ui/components/progress_dots.dart';
import 'package:ear_trainer/ui/theme/theme.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(alignment: Alignment.topCenter, child: child),
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

  group('plate is a switch, not a layout', () {
    testWidgets('turning the plate off changes nothing about size or '
        'position, only whether it is painted — so it can be flipped '
        'without relayout', (tester) async {
      Future<Rect> caption(bool plate) async {
        await tester.pumpWidget(
          host(HighLowCaption(text: 'Let them explore freely.', plate: plate)),
        );
        await tester.pump(AppAnimations.medium);
        return tester.getRect(find.byType(HighLowCaption));
      }

      final on = await caption(true);
      final textOn = tester.getRect(find.text('Let them explore freely.'));
      final off = await caption(false);
      final textOff = tester.getRect(find.text('Let them explore freely.'));
      expect(off, on);
      expect(textOff, textOn);
      expect(
        find.descendant(
          of: find.byType(HighLowCaption),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                (w.decoration as BoxDecoration).gradient != null,
          ),
        ),
        findsNothing,
        reason: 'no plate painted when off',
      );
    });

    testWidgets('a two-line caption is not clipped by its own plate', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        host(
          const HighLowCaption(
            text: 'Help them drag the higher instrument to Clef, please.',
          ),
        ),
      );
      await tester.pump(AppAnimations.medium);
      final box = tester.getRect(find.byType(HighLowCaption));
      final plate = tester.getRect(
        find
            .descendant(
              of: find.byType(HighLowCaption),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(plate.top, greaterThanOrEqualTo(box.top));
      expect(plate.bottom, lessThanOrEqualTo(box.bottom));
    });
  });

  group('header', () {
    Widget header({
      String? caption = 'Help them drag the higher instrument to Clef.',
      bool report = false,
      VoidCallback? onSkip,
      bool skipEnabled = true,
    }) => host(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: HighLowHeader(
          onClose: () {},
          captionText: caption,
          skipEnabled: skipEnabled,
          onSkip: onSkip,
          reportButtonKey: report ? GlobalKey() : null,
          onReportTap: report ? () {} : null,
          below: const Text('LISTEN'),
        ),
      ),
    );

    for (final report in [false, true]) {
      testWidgets('the caption is centred on the SCREEN — with the dev '
          'report button ${report ? 'shown' : 'hidden'} (it used to sit '
          'well left of centre)', (tester) async {
        tester.view.physicalSize = const Size(844, 390);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(header(report: report));
        await tester.pump(AppAnimations.medium);
        final caption = tester.getRect(
          find
              .descendant(
                of: find.byType(HighLowCaption),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(caption.center.dx, closeTo(844 / 2, 1.0));
      });
    }

    testWidgets('close is top-left, Skip is top-right, and Listen Again sits '
        'directly beneath the caption, centred', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(header());
      await tester.pump(AppAnimations.medium);
      final close = tester.getRect(find.byTooltip('Close'));
      final skip = tester.getRect(find.byTooltip('Skip'));
      final caption = tester.getRect(find.byType(HighLowCaption));
      final listen = tester.getRect(find.text('LISTEN'));
      expect(close.left, lessThan(80));
      expect(skip.right, greaterThan(844 - 80));
      expect(listen.center.dx, closeTo(844 / 2, 1.0));
      expect(listen.top, greaterThanOrEqualTo(caption.bottom - 0.5));
    });

    testWidgets('Skip is a small pill: the icon and the word, no subtitle — '
        'and there is no progress indicator anywhere in the header', (
      tester,
    ) async {
      await tester.pumpWidget(header());
      await tester.pump(AppAnimations.medium);
      final skip = tester.getSize(find.byTooltip('Skip'));
      expect(skip.height, lessThanOrEqualTo(44), reason: 'was far too big');
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('I want something new'), findsNothing);
      expect(find.byType(ProgressDots), findsNothing);
    });

    testWidgets('Skip looks like a quiet cream pill, nothing like the '
        'child\'s big bright arrow — the two must not converge into a '
        'matched pair', (tester) async {
      await tester.pumpWidget(header());
      await tester.pump(AppAnimations.medium);
      final skipBox = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byTooltip('Skip'),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .first;
      expect(skipBox.gradient, AppColors.cardGradient);
      expect(skipBox.gradient, isNot(AppColors.ctaGradient));
      expect(skipBox.shape, BoxShape.rectangle, reason: 'a pill, not a circle');
    });

    testWidgets('Skip works, and a disabled Skip does nothing', (tester) async {
      var skips = 0;
      await tester.pumpWidget(header(onSkip: () => skips++));
      await tester.pump(AppAnimations.medium);
      await tester.tap(find.byTooltip('Skip'));
      expect(skips, 1);

      await tester.pumpWidget(
        header(onSkip: () => skips++, skipEnabled: false),
      );
      await tester.pump(AppAnimations.medium);
      await tester.tap(find.byTooltip('Skip'), warnIfMissed: false);
      expect(skips, 1);
    });
  });
}

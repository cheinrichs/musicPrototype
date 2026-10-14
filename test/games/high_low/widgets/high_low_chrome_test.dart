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
  testWidgets('the plate is ON by default again (Trello card 187): with the '
      'tree\'s canopy behind the caption, plain text does not read — and it '
      'was already low-contrast against pale sky', (tester) async {
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
    expect(plaque, isNotEmpty);
  });

  group('caption with no plate (opt-out, plate: false — the 2026-09-28 '
      'look, kept switchable)', () {
    testWidgets('no plaque is painted behind the text — Cooper, on device: '
        '"no tan bubble — plain text, legibility via colour choice, not a '
        'plate"', (tester) async {
      await tester.pumpWidget(
        host(
          const HighLowCaption(text: 'Let them explore freely.', plate: false),
        ),
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
          .where((d) => d.gradient != null);
      expect(plaque, isEmpty, reason: 'no plate when switched off');
    });

    testWidgets('the text is white with a dark shadow instead — legibility '
        'over the meadow without a plaque behind it', (tester) async {
      await tester.pumpWidget(
        host(
          const HighLowCaption(text: 'Let them explore freely.', plate: false),
        ),
      );
      await tester.pump(AppAnimations.medium);

      final text = tester.widget<Text>(find.text('Let them explore freely.'));
      expect(text.style!.color, Colors.white);
      expect(text.style!.shadows, isNotEmpty);
    });

    testWidgets('there is no game name (Trello card 216): a non-reader '
        'cannot use it', (tester) async {
      await tester.pumpWidget(
        host(const HighLowCaption(text: null, plate: false)),
      );
      await tester.pump(AppAnimations.medium);
      expect(find.text('High vs Low'), findsNothing);
      expect(find.byType(Text), findsNothing);
    });
  });

  group('caption plaque (plate: true)', () {
    testWidgets('sits on a cream plaque instead of floating bare on the '
        'scenery — a caption over hills or a tree would otherwise vanish '
        'into the background', (tester) async {
      await tester.pumpWidget(
        host(
          const HighLowCaption(text: 'Let them explore freely.', plate: true),
        ),
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
        host(
          const HighLowCaption(text: 'Let them explore freely.', plate: true),
        ),
      );
      await tester.pump(AppAnimations.medium);

      final text = tester.widget<Text>(find.text('Let them explore freely.'));
      final color = text.style!.color!;
      expect(color, AppColors.inkBrown);
      expect(color, isNot(Colors.black));
      expect(color.r > color.b, isTrue, reason: 'warm, not neutral');
      expect(color.r + color.g + color.b, lessThan(1.2), reason: 'still dark');
    });

    testWidgets('with no instruction yet the plate still holds its line, so '
        'it never appears or resizes as the intro ends', (tester) async {
      await tester.pumpWidget(
        host(const HighLowCaption(text: null, plate: true)),
      );
      await tester.pump(AppAnimations.medium);
      final empty = tester.getSize(find.byType(HighLowCaption));
      await tester.pumpWidget(
        host(const HighLowCaption(text: 'The higher one goes on top.')),
      );
      await tester.pump(AppAnimations.medium);
      expect(tester.getSize(find.byType(HighLowCaption)).height, empty.height);
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

    testWidgets('the caption is ONE line: a long one is cut short, never '
        'wrapped — so the copy is written short (card 216)', (tester) async {
      tester.view.physicalSize = const Size(300, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          const HighLowCaption(
            text: 'Help them drag the higher instrument to Clef, please.',
          ),
        ),
      );
      await tester.pump(AppAnimations.medium);
      expect(
        tester.getSize(find.byType(HighLowCaption)).height,
        HighLowCaption.lineHeight,
      );
    });
  });

  group('header — the top row (Trello card 216)', () {
    Widget header({
      String? caption = 'The higher one goes on top.',
      String? guidance,
      VoidCallback? onSkip,
      VoidCallback? onClose,
      bool skipEnabled = true,
      double? progress = 0.4,
    }) => host(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: HighLowHeader(
          onClose: onClose ?? () {},
          captionText: caption,
          guidanceText: guidance,
          skipEnabled: skipEnabled,
          onSkip: onSkip,
          progress: progress,
        ),
      ),
    );

    void phone(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('close, a short bar, the caption, then Skip — one row', (
      tester,
    ) async {
      phone(tester, const Size(844, 390));
      await tester.pumpWidget(header());
      await tester.pump(AppAnimations.medium);
      final close = tester.getRect(find.byTooltip('Close'));
      final bar = tester.getRect(
        find.byKey(const ValueKey('round-set-progress')),
      );
      final caption = tester.getRect(find.byType(HighLowCaption));
      final skip = tester.getRect(find.byTooltip('Skip'));
      expect(close.right, lessThan(bar.left));
      expect(bar.right, lessThan(caption.left));
      expect(caption.right, lessThan(skip.left));
      for (final r in [bar, caption, skip]) {
        expect((r.center.dy - close.center.dy).abs(), lessThan(1));
      }
      // A third of what it was: the row between Close and Skip.
      expect(bar.width, closeTo((796 - 44 - 4 - 16 - 80) / 3, 1));
    });

    testWidgets('the guidance arriving grows the caption DOWNWARD and moves '
        'nothing else in the row', (tester) async {
      phone(tester, const Size(844, 390));
      await tester.pumpWidget(header());
      await tester.pump(AppAnimations.medium);
      Rect at(Finder f) => tester.getRect(f);
      final before = [
        at(find.byTooltip('Close')),
        at(find.byKey(const ValueKey('round-set-progress'))),
        at(find.byTooltip('Skip')),
      ];
      final captionBefore = at(find.byType(HighLowCaption));
      await tester.pumpWidget(header(guidance: 'Keep tapping the higher one.'));
      await tester.pump(AppAnimations.medium);
      expect([
        at(find.byTooltip('Close')),
        at(find.byKey(const ValueKey('round-set-progress'))),
        at(find.byTooltip('Skip')),
      ], before);
      final captionAfter = at(find.byType(HighLowCaption));
      expect(captionAfter.top, captionBefore.top);
      expect(captionAfter.bottom, greaterThan(captionBefore.bottom));
      expect(find.text('The higher one goes on top.'), findsOneWidget);
    });

    testWidgets('CLOSE SITS ON A SOLID CREAM PLATE, as Skip does, with a '
        'warm dark cross — a light glyph with no backing vanished into the '
        'art (card 216, the third time)', (tester) async {
      await tester.pumpWidget(header());
      final plate =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byKey(const ValueKey('close-plate')),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(plate.gradient, AppColors.cardGradient);
      expect(plate.border, isNotNull);
    });

    testWidgets('the WHOLE close plate takes the tap, edge to edge', (
      tester,
    ) async {
      var closes = 0;
      phone(tester, const Size(667, 375));
      await tester.pumpWidget(header(onClose: () => closes++));
      final r = tester.getRect(find.byKey(const ValueKey('close-plate')));
      expect(r.width, greaterThanOrEqualTo(44));
      for (final p in [
        r.center,
        r.topLeft + const Offset(4, 4),
        r.bottomRight - const Offset(4, 4),
        r.centerLeft + const Offset(2, 0),
        r.centerRight - const Offset(2, 0),
      ]) {
        await tester.tapAt(p);
      }
      expect(closes, 5);
    });

    testWidgets('no bar when there is no set', (tester) async {
      await tester.pumpWidget(header(progress: null));
      expect(find.byKey(const ValueKey('round-set-progress')), findsNothing);
    });

    testWidgets('Skip is a small pill: the icon and the word, no subtitle — '
        'and no pips anywhere in the header', (tester) async {
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

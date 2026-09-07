import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/ui/screens/credits_screen.dart';

void main() {
  group('CreditsScreen', () {
    testWidgets(
      'renders every credit source required for shipping the hand bells '
      '— Philharmonia, University of Iowa MIS, and the CC-BY hand bells '
      'line with its required title/creator/source/licence/modified note',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: CreditsScreen()));
        await tester.pump();

        expect(find.textContaining('Philharmonia Orchestra'), findsWidgets);
        expect(
          find.textContaining('University of Iowa'),
          findsWidgets,
          reason:
              'credited regardless of whether its licence requires it, '
              'same as Philharmonia',
        );

        expect(find.text('Hand Bells, Singles'), findsOneWidget);
        expect(
          find.textContaining('InspectorJ'),
          findsWidgets,
          reason: 'the creator name, and it also appears in the source URL',
        );
        expect(find.textContaining('CC BY 4.0'), findsOneWidget);
        expect(
          find.textContaining('freesound.org'),
          findsWidgets,
          reason: 'source URL is a legal requirement for CC-BY attribution',
        );
        expect(
          find.textContaining('Modified'),
          findsOneWidget,
          reason:
              'the audio was modified (normalized) — CC-BY requires '
              'saying so',
        );
      },
    );

    testWidgets('renders an art credit', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CreditsScreen()));
      await tester.pump();

      expect(find.text('Art'), findsOneWidget);
      expect(
        find.textContaining('Character and instrument illustrations'),
        findsOneWidget,
      );
    });

    testWidgets('never throws, even though BuildInfo.current() hits a platform '
        'channel a widget test can\'t satisfy — a missing version line is '
        'harmless, an uncaught exception on the credits screen isn\'t', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: CreditsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    testWidgets('is a plain scrollable list, not styled game chrome — no '
        'GameScreenLayout, no character art, matches the "nobody reads it, '
        'everybody expects it to exist" reference-page brief', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CreditsScreen()));
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}

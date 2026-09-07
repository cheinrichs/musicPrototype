import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/ui/components/adult_door.dart';

void main() {
  group('AdultDoor', () {
    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdultDoor(
              semanticLabel: 'About and credits',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AdultDoor));
      expect(tapped, isTrue);
    });

    testWidgets(
      'renders small and low-contrast rather than styled to invite a tap '
      '— the whole point of the door is that it doesn\'t compete with the '
      'rest of the screen for a child\'s attention',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdultDoor(semanticLabel: 'About and credits', onTap: () {}),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(
          icon.size,
          lessThan(24),
          reason:
              'should read as small next to the app\'s usual large '
              'tap targets',
        );
        expect(
          icon.color!.a,
          lessThan(1.0),
          reason:
              'should be low-contrast, not a solid, attention-grabbing '
              'color',
        );
      },
    );

    testWidgets('exposes a real semantic label for an adult using a '
        'screen reader to find it', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdultDoor(semanticLabel: 'About and credits', onTap: () {}),
          ),
        ),
      );

      expect(find.bySemanticsLabel('About and credits'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the tap target is still generous despite the small '
        'visible icon — small and hard-to-hit are not the same goal', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdultDoor(semanticLabel: 'About and credits', onTap: () {}),
          ),
        ),
      );

      final size = tester.getSize(find.byType(AdultDoor));
      expect(size.width, greaterThanOrEqualTo(32));
      expect(size.height, greaterThanOrEqualTo(32));
    });
  });
}

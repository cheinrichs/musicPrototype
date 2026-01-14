import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/app/app.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EarTrainerApp());
    await tester.pumpAndSettle();

    // Verify that home screen renders with game cards
    expect(find.text('Ear Trainer'), findsOneWidget);
    expect(find.text('High vs Low'), findsOneWidget);
  });
}

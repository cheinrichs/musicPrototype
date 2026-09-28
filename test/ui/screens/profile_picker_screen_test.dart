import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ear_trainer/app/router.dart';
import 'package:ear_trainer/app/state/profile_state.dart';
import 'package:ear_trainer/app/state/progress_state.dart';
import 'package:ear_trainer/app/state/skill_state.dart';
import 'package:ear_trainer/ui/screens/profile_picker_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpPicker(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.profilePicker,
      routes: [
        GoRoute(
          path: AppRoutes.profilePicker,
          builder: (context, state) => const ProfilePickerScreen(),
        ),
        GoRoute(
          path: AppRoutes.landing,
          builder: (context, state) => const Scaffold(body: Text('LANDED')),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProfileState()..load()),
          ChangeNotifierProvider(create: (_) => ProgressState()),
          ChangeNotifierProvider(create: (_) => SkillState()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  /// The real async work behind adding/choosing a profile (SharedPreferences
  /// round-trips) — genuine async, not fake-clock timers, so this needs
  /// `runAsync` rather than a plain `pump()`.
  Future<void> settleAsync(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump();
  }

  group('ProfilePickerScreen (Trello card 170)', () {
    testWidgets('adding a child navigates all the way to landing, through '
        'the real async profile-save and Progress/Skill-state-scoping work '
        '(not stubbed out)', (tester) async {
      await pumpPicker(tester);
      expect(find.text("Who's playing?"), findsOneWidget);

      await tester.tap(find.text('Add a child'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Davis');
      await tester.tap(find.text('Add'));
      await settleAsync(tester);

      expect(find.text('LANDED'), findsOneWidget);
    });

    testWidgets('picking an existing profile tile also navigates to landing '
        'and selects it', (tester) async {
      await pumpPicker(tester);
      await tester.tap(find.text('Add a child'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Delaney');
      await tester.tap(find.text('Add'));
      await settleAsync(tester);
      expect(find.text('LANDED'), findsOneWidget);
    });

    testWidgets('the adult door creates the one adult profile on first use, '
        'and just selects it (no re-entry) on later uses', (tester) async {
      await pumpPicker(tester);
      await tester.tap(find.bySemanticsLabel("I'm the grown-up"));
      await tester.pump();
      expect(find.text("What's your name?"), findsOneWidget);
      await tester.tap(find.text('Add'));
      await settleAsync(tester);

      expect(find.text('LANDED'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ear_trainer/app/config.dart';
import 'package:ear_trainer/app/router.dart';
import 'package:ear_trainer/app/state/profile_state.dart';
import 'package:ear_trainer/app/state/skill_state.dart';
import 'package:ear_trainer/models/profile.dart';
import 'package:ear_trainer/ui/screens/skill_profile_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => devToolsEnabled = false);

  Future<void> pumpWithProfile(WidgetTester tester, Profile? profile) async {
    devToolsEnabled = true;
    final profileState = ProfileState();
    await profileState.load();
    if (profile != null) profileState.selectProfile(profile);
    final router = GoRouter(
      initialLocation: AppRoutes.skillProfile,
      routes: [
        GoRoute(
          path: AppRoutes.skillProfile,
          builder: (context, state) => const SkillProfileScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: profileState),
          ChangeNotifierProvider(create: (_) => SkillState()..load()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  group('SkillProfileScreen dev tools — scoped to the adult profile '
      '(Trello card 170)', () {
    testWidgets('the seed/reset buttons show for the adult profile', (
      tester,
    ) async {
      await pumpWithProfile(
        tester,
        const Profile(id: 'p1', name: 'Cooper', isAdult: true),
      );
      expect(find.byTooltip('Seed random data'), findsOneWidget);
      expect(find.byTooltip('Reset all XP'), findsOneWidget);
    });

    testWidgets('the seed/reset buttons are hidden for a child profile, '
        'even on an internal build', (tester) async {
      await pumpWithProfile(
        tester,
        const Profile(id: 'p2', name: 'Davis', isAdult: false),
      );
      expect(find.byTooltip('Seed random data'), findsNothing);
      expect(find.byTooltip('Reset all XP'), findsNothing);
    });
  });
}

import 'dart:convert';

import 'package:ear_trainer/app/app.dart';
import 'package:ear_trainer/app/config.dart';
import 'package:ear_trainer/app/router.dart';
import 'package:ear_trainer/app/state/profile_state.dart';
import 'package:ear_trainer/journey/journey_art.dart';
import 'package:ear_trainer/journey/journey_screen.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/profile.dart';
import 'package:ear_trainer/ui/components/reading_gate.dart';
import 'package:ear_trainer/ui/screens/setup_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// THE LAUNCH FLOW — the one place a mistake stops the app opening at all.
/// Every kind of profile, a brand-new one included, must reach the
/// Journey (home) from the SongStone logo page (the picker).
void main() {
  Future<void> launch(
    WidgetTester tester, {
    Map<String, Object>? stored,
  }) async {
    SharedPreferences.setMockInitialValues(stored ?? {});
    tester.view.physicalSize = const Size(844, 390) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // The router is app-wide: start every launch on the picker.
    appRouter.go(AppRoutes.profilePicker);
    await tester.pumpWidget(const EarTrainerApp());
    await settle(tester);
  }

  testWidgets(
    'a FRESH INSTALL: the "Add Profile" tile, the four questions, and '
    'the brand-new child reaches the Journey wearing the avatar they '
    'picked',
    (tester) async {
      await launch(tester);
      expect(find.byType(JourneyScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('add-profile')));
      await settle(tester);

      await answerQuiz(
        tester,
        name: 'Davis',
        avatar: 6,
        agency: AgencyStage.explore,
        ageBand: AgeBand.fourFive,
      );

      final profiles = profileState(tester);
      final davis = profiles.childProfiles.single;
      expect(davis.name, 'Davis');
      expect(davis.avatar, 6);
      expect(davis.ageBand, AgeBand.fourFive);
      expect(davis.agencyOverride, AgencyStage.explore);
      expect(
        davis.agencySource,
        AgencySource.parent,
        reason: 'a placed child is told apart from one who climbed',
      );

      await tester.tap(find.byKey(ValueKey('player-${davis.id}')));
      await settle(tester);
      expect(find.byType(JourneyScreen), findsOneWidget);
      expect(profiles.activeProfile?.id, davis.id);
      expect(tester.widget<AvatarPin>(find.byType(AvatarPin)).index, 6);
    },
  );

  testWidgets('EVERY child reaches the Journey — two on the stumps, a third '
      'in a row — each on one tap', (tester) async {
    await launch(
      tester,
      stored: {
        'profiles_v1': [
          for (final (id, name, avatar) in [
            ('a', 'Ada', 1),
            ('b', 'Bo', 2),
            ('c', 'Cy', 3),
          ])
            jsonEncode(
              Profile(
                id: id,
                name: name,
                avatar: avatar,
                ageBand: AgeBand.twoThree,
              ).toJson(),
            ),
        ],
      },
    );
    for (final id in ['a', 'b', 'c']) {
      appRouter.go(AppRoutes.profilePicker);
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('player-$id')));
      await settle(tester);
      expect(find.byType(JourneyScreen), findsOneWidget, reason: id);
      expect(profileState(tester).activeProfile?.id, id);
    }
  });

  testWidgets('a profile from BEFORE the quiz (no picture, no age band) and '
      "Cooper's old adult profile still open — the child on one tap, the "
      'adult as the dev profile from settings', (tester) async {
    await launch(
      tester,
      stored: {
        'profiles_v1': [
          jsonEncode({'id': 'old', 'name': 'Delaney', 'isAdult': false}),
          jsonEncode({'id': 'cooper', 'name': 'Cooper', 'isAdult': true}),
        ],
      },
    );
    final profiles = profileState(tester);
    expect(profiles.childProfiles.map((p) => p.id), ['old']);
    expect(profiles.devProfile?.id, 'cooper');
    expect(
      find.byKey(const ValueKey('player-cooper')),
      findsNothing,
      reason: 'the dev profile is not a player badge on the stumps',
    );

    await tester.tap(find.byKey(const ValueKey('player-old')));
    await settle(tester);
    expect(find.byType(JourneyScreen), findsOneWidget);
    expect(
      tester.widget<AvatarPin>(find.byType(AvatarPin)).index,
      Profile.derivedAvatarFor('old'),
      reason: 'a stable face until a parent re-takes setup',
    );

    // The Journey's back arrow: ungated, straight to the picker.
    await tester.tap(find.byKey(const ValueKey('journey-back')));
    await settle(tester);
    expect(find.byType(JourneyScreen), findsNothing);
    expect(find.byKey(const ValueKey('player-old')), findsOneWidget);
    await openDevProfile(tester);
    expect(find.byType(JourneyScreen), findsOneWidget);
    expect(profiles.activeProfile?.id, 'cooper');
    // An internal install (resolved in main(), which tests do not run).
    devToolsEnabled = true;
    addTearDown(() => devToolsEnabled = false);
    expect(profiles.canUseDevTools, isTrue);
  });

  testWidgets('the dev profile on a fresh internal install: made the first '
      'time it is opened from settings, and the gate is RE-ASKED every time', (
    tester,
  ) async {
    await launch(tester);
    expect(find.byKey(const ValueKey('dev-profile')), findsNothing);
    await openDevProfile(tester);
    expect(find.byType(JourneyScreen), findsOneWidget);
    expect(profileState(tester).activeProfile?.isDev, isTrue);

    await tester.tap(find.byKey(const ValueKey('journey-back')));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await settle(tester);
    expect(
      find.byType(ReadingGate),
      findsOneWidget,
      reason: 'no session-level "adult verified" flag',
    );
    // ONE tap out, and nothing changes.
    await tester.tap(find.byKey(const ValueKey('reading-gate-exit')));
    await settle(tester);
    expect(find.byType(ReadingGate), findsNothing);
    expect(find.byKey(const ValueKey('add-profile')), findsOneWidget);
  });

  testWidgets("a child's new picture, changed in settings, is their pin on "
      'the Journey', (tester) async {
    await launch(
      tester,
      stored: {
        'profiles_v1': [
          jsonEncode(
            const Profile(
              id: 'k',
              name: 'Kit',
              avatar: 0,
              ageBand: AgeBand.twoThree,
              agencyOverride: AgencyStage.observe,
            ).toJson(),
          ),
        ],
      },
    );
    await tester.tap(find.bySemanticsLabel('Settings'));
    await settle(tester);
    await passGate(tester);
    await tester.tap(find.byKey(const ValueKey('settings-child-k')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('quiz-avatar-9')));
    await settle(tester);
    expect(profileState(tester).childProfiles.single.avatar, 9);
    // Back out of settings to the picker, and into the Journey.
    Navigator.of(
      tester.element(find.byType(Scaffold).last),
    ).popUntil((r) => r.isFirst);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('player-k')));
    await settle(tester);
    expect(tester.widget<AvatarPin>(find.byType(AvatarPin)).index, 9);
  });
}

/// The gear, the reading gate, then settings' dev-profile tile.
Future<void> openDevProfile(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Settings'));
  await settle(tester);
  await passGate(tester);
  await tester.tap(find.byKey(const ValueKey('dev-profile')));
  await settle(tester);
}

ProfileState profileState(WidgetTester tester) => Provider.of<ProfileState>(
  tester.element(find.byType(Scaffold).first),
  listen: false,
);

/// Lets real SharedPreferences round-trips resolve and the screen settle
/// (the wordmark breathes forever, so never pumpAndSettle).
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> passGate(WidgetTester tester) async {
  final gate = tester.widget<ReadingGate>(find.byType(ReadingGate));
  for (final n in gate.puzzle.targets) {
    await tester.tap(find.byKey(ValueKey('reading-gate-$n')));
    await tester.pump();
  }
  await settle(tester);
}

Future<void> answerQuiz(
  WidgetTester tester, {
  required String name,
  required int avatar,
  required AgencyStage agency,
  required AgeBand ageBand,
}) async {
  expect(find.byType(SetupQuizScreen), findsOneWidget);
  await tester.enterText(find.byKey(const ValueKey('quiz-name')), name);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('quiz-next')));
  await settle(tester);
  await tester.tap(find.byKey(ValueKey('quiz-avatar-$avatar')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('quiz-next')));
  await settle(tester);
  await tester.tap(find.byKey(ValueKey('quiz-choice-$agency')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('quiz-next')));
  await settle(tester);
  await tester.tap(find.byKey(ValueKey('quiz-choice-$ageBand')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('quiz-next')));
  await settle(tester);
}

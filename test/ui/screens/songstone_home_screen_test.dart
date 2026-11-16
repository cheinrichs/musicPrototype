import 'dart:convert';

import 'package:ear_trainer/app/router.dart';
import 'package:ear_trainer/app/state/profile_state.dart';
import 'package:ear_trainer/app/state/progress_state.dart';
import 'package:ear_trainer/app/state/skill_state.dart';
import 'package:ear_trainer/journey/journey_state.dart';
import 'package:ear_trainer/models/profile.dart';
import 'package:ear_trainer/ui/components/reading_gate.dart';
import 'package:ear_trainer/ui/screens/settings_screen.dart';
import 'package:ear_trainer/ui/screens/setup_quiz_screen.dart';
import 'package:ear_trainer/ui/screens/songstone_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The SongStone logo page as the choose-your-player screen
/// (docs/product/PROFILES.md, Cooper 2026-11-15).
void main() {
  Future<ProfileState> mount(
    WidgetTester tester, {
    List<Profile> stored = const [],
    bool internal = true,
    Size size = const Size(844, 390),
  }) async {
    SharedPreferences.setMockInitialValues({
      'profiles_v1': [for (final p in stored) jsonEncode(p.toJson())],
    });
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final profiles = ProfileState();
    await tester.runAsync(profiles.load);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: profiles),
          ChangeNotifierProvider(create: (_) => ProgressState()),
          ChangeNotifierProvider(create: (_) => SkillState()),
          ChangeNotifierProvider(create: (_) => JourneyState()),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: AppRoutes.profilePicker,
            routes: [
              GoRoute(
                path: AppRoutes.profilePicker,
                builder: (_, _) =>
                    SongStoneHomeScreen(showDevProfile: internal),
              ),
              GoRoute(
                path: AppRoutes.journey,
                builder: (_, _) => const Text('journey'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    return profiles;
  }

  const dev = Profile(id: 'dev', name: 'Cooper', isDev: true);
  List<Profile> kids(int n) => [
    for (var i = 0; i < n; i++)
      Profile(id: 'k$i', name: 'Kid $i', avatar: i, ageBand: AgeBand.fourFive),
  ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Settings'));
    await settle(tester);
    final gate = tester.widget<ReadingGate>(find.byType(ReadingGate));
    for (final n in gate.puzzle.targets) {
      await tester.tap(find.byKey(ValueKey('reading-gate-$n')));
      await tester.pump();
    }
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  testWidgets('CHILDREN ONLY on the picker — the dev profile is never on it, '
      'even with one stored', (tester) async {
    await mount(tester, stored: [...kids(2), dev]);
    expect(find.byKey(const ValueKey('player-dev')), findsNothing);
    expect(find.byKey(const ValueKey('dev-profile')), findsNothing);
    await finish(tester);
  });

  group('the dev profile lives in settings', () {
    testWidgets('an INTERNAL build: behind the gear and the reading gate, '
        'ONE gate', (tester) async {
      await mount(tester, stored: kids(1));
      await openSettings(tester);
      expect(find.byKey(const ValueKey('dev-profile')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a RELEASE-FLAVOURED build: not in settings either', (
      tester,
    ) async {
      await mount(tester, stored: [...kids(1), dev], internal: false);
      await openSettings(tester);
      expect(find.byKey(const ValueKey('dev-profile')), findsNothing);
      expect(find.bySemanticsLabel('Dev profile (internal)'), findsNothing);
      await finish(tester);
    });
  });

  group('the "Add Profile" tile', () {
    testWidgets('always the LAST tile, after the children', (tester) async {
      await mount(tester, stored: kids(2));
      final add = tester.getRect(find.byKey(const ValueKey('add-profile')));
      for (final k in kids(2)) {
        expect(
          tester.getRect(find.byKey(ValueKey('player-${k.id}'))).left,
          lessThan(add.left),
        );
      }
      await finish(tester);
    });

    testWidgets('a fresh install shows just the tile — a way in', (
      tester,
    ) async {
      await mount(tester);
      expect(find.byKey(const ValueKey('add-profile')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('HIDDEN at six — not disabled', (tester) async {
      await mount(tester, stored: kids(6));
      expect(find.byKey(const ValueKey('add-profile')), findsNothing);
      await finish(tester);
    });

    testWidgets('UNGATED, and the quiz ABANDONS IN ONE TAP from any question '
        'with NOTHING created', (tester) async {
      final profiles = await mount(tester, stored: kids(1));
      await tester.tap(find.byKey(const ValueKey('add-profile')));
      await settle(tester);
      expect(find.byType(ReadingGate), findsNothing);
      expect(find.byType(SetupQuizScreen), findsOneWidget);
      // Three questions in…
      await tester.enterText(find.byKey(const ValueKey('quiz-name')), 'Zed');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('quiz-next')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('quiz-avatar-7')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('quiz-next')));
      await settle(tester);
      expect(find.text('3 of 4'), findsOneWidget);
      // …ONE tap out.
      await tester.tap(find.byKey(const ValueKey('quiz-back')));
      await settle(tester);
      expect(find.byType(SetupQuizScreen), findsNothing);
      expect(profiles.childProfiles, hasLength(1), reason: 'no half profile');
      await finish(tester);
    });

    testWidgets("the quiz hides siblings' avatars", (tester) async {
      await mount(tester, stored: kids(2));
      await tester.tap(find.byKey(const ValueKey('add-profile')));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('quiz-name')), 'Zed');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('quiz-next')));
      await settle(tester);
      expect(find.byKey(const ValueKey('quiz-avatar-0')), findsNothing);
      expect(find.byKey(const ValueKey('quiz-avatar-1')), findsNothing);
      expect(find.byKey(const ValueKey('quiz-avatar-2')), findsOneWidget);
      await finish(tester);
    });
  });

  group('settings', () {
    testWidgets('changing a child\'s picture: siblings\' faces are hidden, '
        'and the picker badge follows', (tester) async {
      final profiles = await mount(tester, stored: kids(2));
      await openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('settings-child-k1')));
      await settle(tester);
      expect(find.byKey(const ValueKey('quiz-avatar-0')), findsNothing);
      expect(find.byKey(const ValueKey('quiz-avatar-1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quiz-avatar-9')));
      await settle(tester);
      expect(
        profiles.childProfiles.firstWhere((p) => p.id == 'k1').avatarIndex,
        9,
      );
      await finish(tester);
    });

    testWidgets('placement says plainly it is a STARTING POINT', (
      tester,
    ) async {
      await mount(tester, stored: kids(1));
      await openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('settings-child-k0')));
      await settle(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('placement-note'))).data,
        contains('starting point'),
      );
      await finish(tester);
    });

    testWidgets('deleting asks first, then removes the child', (tester) async {
      final profiles = await mount(tester, stored: kids(2));
      await openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('settings-child-k0')));
      await settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('delete-player')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('delete-player')));
      await settle(tester);
      expect(profiles.childProfiles, hasLength(2), reason: 'asks first');
      await tester.tap(find.byKey(const ValueKey('delete-confirm')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await settle(tester);
      expect(profiles.childProfiles.map((p) => p.id), ['k1']);
      await finish(tester);
    });
  });

  group('badges stand on the stumps', () {
    for (final size in [
      const Size(667, 375), // iPhone SE, landscape
      const Size(844, 390),
      const Size(1194, 834), // iPad Pro 11
    ]) {
      for (final n in [0, 1, 2, 5, 6]) {
        testWidgets('$n children (+ Add) on ${size.width.toInt()}×'
            '${size.height.toInt()}: every tile on screen, none '
            'overlapping, clear of the logo — and big enough to tap', (
          tester,
        ) async {
          await mount(tester, stored: kids(n), size: size);
          expect(tester.takeException(), isNull);
          final rects = [
            for (var i = 0; i < n; i++)
              tester.getRect(find.byKey(ValueKey('player-k$i'))),
            if (n < 6)
              tester.getRect(find.byKey(const ValueKey('add-profile'))),
          ];
          final screen = Offset.zero & size;
          final layout = PickerLayout(size, EdgeInsets.zero, rects.length);
          for (final r in rects) {
            expect(screen.intersect(r), r, reason: 'on screen');
            expect(r.width, greaterThanOrEqualTo(56), reason: 'tappable');
            expect(r.overlaps(layout.logo), isFalse, reason: 'clear of logo');
          }
          for (var i = 0; i < rects.length; i++) {
            for (var j = i + 1; j < rects.length; j++) {
              expect(rects[i].overlaps(rects[j]), isFalse, reason: '$i/$j');
            }
          }
          if (rects.length <= 2) {
            for (var i = 0; i < rects.length; i++) {
              expect(
                (rects[i].center.dx - layout.stumpTop(i).dx).abs(),
                lessThan(1),
                reason: 'centred on stump $i',
              );
            }
          }
          await finish(tester);
        });
      }
    }
  });
}

/// Unmounts, and lets any one-shot timers (font loading, entrances) fire.
Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

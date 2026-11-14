import 'dart:convert';

import 'package:ear_trainer/app/router.dart';
import 'package:ear_trainer/app/state/profile_state.dart';
import 'package:ear_trainer/app/state/progress_state.dart';
import 'package:ear_trainer/app/state/skill_state.dart';
import 'package:ear_trainer/journey/journey_state.dart';
import 'package:ear_trainer/models/profile.dart';
import 'package:ear_trainer/ui/components/reading_gate.dart';
import 'package:ear_trainer/ui/screens/credits_screen.dart';
import 'package:ear_trainer/ui/screens/songstone_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The SongStone logo page as the choose-your-player screen.
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

  group('the dev profile', () {
    testWidgets('a RELEASE-FLAVOURED build: no dev profile on the picker at '
        'all, even with one stored', (tester) async {
      await mount(tester, stored: [...kids(2), dev], internal: false);
      expect(find.byKey(const ValueKey('dev-profile')), findsNothing);
      expect(find.bySemanticsLabel('Dev profile (internal)'), findsNothing);
      expect(find.byKey(const ValueKey('player-dev')), findsNothing);
      await finish(tester);
    });

    testWidgets('an INTERNAL build: listed, apart from the children, and '
        'behind the reading gate — one tap backs out', (tester) async {
      final profiles = await mount(tester, stored: [...kids(2), dev]);
      expect(find.byKey(const ValueKey('dev-profile')), findsOneWidget);
      expect(find.byKey(const ValueKey('player-dev')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('dev-profile')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byType(ReadingGate), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reading-gate-exit')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(ReadingGate), findsNothing);
      expect(profiles.activeProfile, isNull);
      await finish(tester);
    });
  });

  group('badges stand on the stumps', () {
    for (final size in [
      const Size(667, 375), // iPhone SE, landscape
      const Size(844, 390),
      const Size(1194, 834), // iPad Pro 11
    ]) {
      for (final n in [1, 2, 3, 5]) {
        testWidgets('$n children on ${size.width.toInt()}×'
            '${size.height.toInt()}: every badge on screen, none '
            'overlapping, clear of the logo — and big enough to tap', (
          tester,
        ) async {
          await mount(tester, stored: kids(n), size: size);
          expect(tester.takeException(), isNull);
          final rects = [
            for (var i = 0; i < n; i++)
              tester.getRect(find.byKey(ValueKey('player-k$i'))),
          ];
          final screen = Offset.zero & size;
          final layout = PickerLayout(size, EdgeInsets.zero, n);
          for (final r in rects) {
            expect(screen.intersect(r), r, reason: 'on screen');
            expect(r.width, greaterThanOrEqualTo(56), reason: 'tappable');
            expect(r.overlaps(layout.logo), isFalse, reason: 'clear of logo');
          }
          for (var i = 0; i < n; i++) {
            for (var j = i + 1; j < n; j++) {
              expect(rects[i].overlaps(rects[j]), isFalse, reason: '$i/$j');
            }
          }
          if (n <= 2) {
            for (var i = 0; i < n; i++) {
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

    testWidgets('no children yet: "Set up a player", between the stumps', (
      tester,
    ) async {
      await mount(tester);
      expect(find.byKey(const ValueKey('first-setup')), findsOneWidget);
      await finish(tester);
    });
  });

  testWidgets('the adult door is a door, not a player: the reading gate, '
      'then the parent area — add a child, redo setup, credits', (
    tester,
  ) async {
    await mount(tester, stored: kids(1));
    await tester.tap(find.bySemanticsLabel('For grown-ups'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    final gate = tester.widget<ReadingGate>(find.byType(ReadingGate));
    for (final n in gate.puzzle.targets) {
      await tester.tap(find.byKey(ValueKey('reading-gate-$n')));
      await tester.pump();
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('parent-add-child')), findsOneWidget);
    expect(find.byKey(const ValueKey('parent-retake-k0')), findsOneWidget);
    await tester.tap(find.text('About and credits'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(CreditsScreen), findsOneWidget);
    await finish(tester);
  });
}

/// Unmounts, and lets any one-shot timers (font loading, entrances) fire.
Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

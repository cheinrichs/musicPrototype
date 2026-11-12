import 'package:ear_trainer/app/state/profile_state.dart';
import 'package:ear_trainer/games/game_library.dart';
import 'package:ear_trainer/journey/journey_state.dart';
import 'package:ear_trainer/models/profile.dart';
import 'package:ear_trainer/ui/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Games library: one screen, gated by profile (Cooper, 2026-11).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(ProfileState, JourneyState)> mount(
    WidgetTester tester, {
    required bool adult,
  }) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final profiles = ProfileState();
    final journey = JourneyState();
    late Profile profile;
    await tester.runAsync(() async {
      profile = await profiles.addProfile('Kid', isAdult: adult);
    });
    profiles.selectProfile(profile);
    journey.useProfile(profile.id);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: profiles),
          ChangeNotifierProvider.value(value: journey),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    return (profiles, journey);
  }

  Finder tile(String id) => find.byKey(ValueKey('game-$id'));

  testWidgets('the adult profile sees every game, as the dev door', (
    tester,
  ) async {
    await mount(tester, adult: true);
    for (final id in [
      'high_low',
      'loud_quiet',
      'same_different',
      'pitch_name',
    ]) {
      expect(tile(id), findsOneWidget, reason: id);
    }
  });

  testWidgets("a child sees High vs Low only; locked games are HIDDEN, not "
      "shown locked; a game met in the Journey joins", (tester) async {
    final (_, journey) = await mount(tester, adult: false);
    expect(tile('high_low'), findsOneWidget);
    expect(tile('loud_quiet'), findsNothing);
    expect(tile('same_different'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    journey.meet('loud_quiet');
    await tester.pump();
    expect(tile('loud_quiet'), findsOneWidget);
    // The new tile's entrance animation.
    await tester.pump(const Duration(seconds: 2));
  });

  test("the library's gate never reaches the Journey's pool: a stone still "
      'mixes both built games for a child who has met neither', () {
    final journey = JourneyState();
    expect(
      GameLibrary.available(
        'loud_quiet',
        gated: true,
        metInJourney: journey.gamesMet,
      ),
      isFalse,
    );
    expect(JourneyState.games, containsAll(['high_low', 'loud_quiet']));
    final plan = JourneyState.plan(0, 4);
    expect(plan.map((p) => p.gameId).toSet(), {'high_low', 'loud_quiet'});
  });

  test('the unlock condition is swappable', () {
    final original = GameLibrary.unlock;
    addTearDown(() => GameLibrary.unlock = original);
    GameLibrary.unlock = (_, _) => true;
    expect(
      GameLibrary.available('chord_id', gated: true, metInJourney: const {}),
      isTrue,
    );
  });
}

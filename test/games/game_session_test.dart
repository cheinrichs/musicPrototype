import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ear_trainer/app/state/dev_settings_state.dart';
import 'package:ear_trainer/app/state/profile_state.dart';
import 'package:ear_trainer/app/state/progress_state.dart';
import 'package:ear_trainer/curriculum/curriculum.dart';
import 'package:ear_trainer/games/game_catalogue.dart';
import 'package:ear_trainer/games/game_session.dart';
import 'package:ear_trainer/games/high_low/models/round_instrumentation.dart';
import 'package:ear_trainer/games/high_low/services/agency_advancement.dart';
import 'package:ear_trainer/games/tier_progression.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/ui/components/round_set_progress_bar.dart';

RoundInstrumentation _round({bool skipped = false}) => RoundInstrumentation(
  promptNumber: 1,
  waitedForPlaythrough: true,
  firstResponseCorrect: null,
  listenAgainCount: 0,
  skipped: skipped,
);

/// Pumps a context under the app's providers and hands it to [body].
Future<void> _withContext(
  WidgetTester tester,
  ProfileState profiles,
  void Function(BuildContext) body, {
  TierProgressState? tiers,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: profiles),
        ChangeNotifierProvider.value(value: tiers ?? TierProgressState()),
        ChangeNotifierProvider(create: (_) => DevSettingsState()),
        ChangeNotifierProvider(create: (_) => ProgressState()),
      ],
      child: Builder(
        builder: (context) {
          body(context);
          return const SizedBox();
        },
      ),
    ),
  );
}

void main() {
  group('the progress bar counts what it was entered with', () {
    test("own set: the game's own fill, untouched", () {
      const own = ProgressSource.ownSet();
      expect(own.fill(ownFraction: 0.25, roundsDone: 1, rounds: 4), 0.25);
    });

    test('a stone of 2 + 2 + 1 rounds across games: one step per round of '
        'any game, never restarting at a new game', () {
      final fills = <double>[];
      var before = 0;
      for (final part in [2, 2, 1]) {
        final source = ProgressSource.stone(total: 5, doneBefore: before);
        for (var done = 0; done <= part; done++) {
          fills.add(
            source.fill(
              ownFraction: done / part,
              roundsDone: done,
              rounds: part,
            ),
          );
        }
        before += part;
      }
      expect(fills, [0, 0.2, 0.4, 0.4, 0.6, 0.8, 0.8, 1.0]);
    });
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('with no child chosen, a set opens at Observe with the '
      'Observe-length set — the least demanding level', (tester) async {
    late GameEntry entry;
    await _withContext(
      tester,
      ProfileState(),
      (c) => entry = GameEntry.forActiveChild(c, gameId: 'high_low'),
    );
    expect(entry.agency, AgencyStage.observe);
    expect(entry.rounds, 3);
    expect(entry.level, isNull);
  });

  testWidgets('the active child\'s set opens at THEIR agency, at that '
      'agency\'s length', (tester) async {
    final profiles = ProfileState();
    await tester.runAsync(() async {
      await profiles.load();
      final davis = await profiles.addProfile('Davis');
      profiles.selectProfile(davis);
      await profiles.setAgencyOverride(davis, AgencyStage.explore);
    });
    late GameEntry entry;
    await _withContext(
      tester,
      profiles,
      (c) => entry = GameEntry.forActiveChild(c, gameId: 'high_low'),
    );
    expect(entry.agency, AgencyStage.explore);
    expect(entry.rounds, 4);
    expect(entry.level, 0, reason: 'every child starts at T1');
  });

  testWidgets('a child\'s level is PER GAME (agency is global, tier is per '
      'game): each game\'s entry carries that game\'s own level, saved', (
    tester,
  ) async {
    final profiles = ProfileState();
    await tester.runAsync(() async {
      await profiles.load();
      final davis = await profiles.addProfile('Davis');
      profiles.selectProfile(davis);
      await profiles.setLevel(davis, 'high_low', 2);
      await profiles.setLevel(profiles.activeProfile!, 'loud_quiet', 1);
    });
    late GameEntry hl, lq;
    await _withContext(tester, profiles, (c) {
      hl = GameEntry.forActiveChild(c, gameId: 'high_low');
      lq = GameEntry.forActiveChild(c, gameId: 'loud_quiet');
    });
    expect(hl.level, 2);
    expect(lq.level, 1);
    final reloaded = ProfileState();
    await tester.runAsync(reloaded.load);
    final davis = reloaded.profiles.firstWhere((p) => p.name == 'Davis');
    expect(davis.levelOf('high_low'), 2);
    expect(davis.levelOf('loud_quiet'), 1);
  });

  testWidgets('a finished set moves the CHILD\'s agency, whichever game it '
      'was — Loud or Quiet now advances as High vs Low does', (tester) async {
    final profiles = ProfileState();
    await tester.runAsync(() async {
      await profiles.load();
      profiles.selectProfile(await profiles.addProfile('Davis'));
    });
    late BuildContext context;
    await _withContext(tester, profiles, (c) => context = c);
    AgencyEvaluation? result;
    await tester.runAsync(() async {
      result = GameSession.recordFinishedSet(
        context,
        SetReport(
          gameType: 'loud_quiet',
          agency: AgencyStage.observe,
          rounds: [_round(), _round(skipped: true), _round()],
          correctCount: 0,
        ),
      );
    });
    expect(result?.change, AgencyChange.advance);
    expect(profiles.activeProfile?.agencyOverride, AgencyStage.explore);
  });

  testWidgets('a STONE records tier evidence PER GAME from its parts, each '
      'at its own level, while agency reads the merged set', (tester) async {
    final profiles = ProfileState();
    final tiers = TierProgressState();
    await tester.runAsync(() async {
      await profiles.load();
      final d = await profiles.addProfile('Delaney');
      profiles.selectProfile(d);
      await profiles.setAgencyOverride(d, AgencyStage.decide);
    });
    late BuildContext context;
    await _withContext(tester, profiles, (c) => context = c, tiers: tiers);
    RoundInstrumentation answered(bool correct) => RoundInstrumentation(
      promptNumber: 1,
      waitedForPlaythrough: true,
      firstResponseCorrect: correct,
      notesHeardBeforeFirstResponse: true,
      listenAgainCount: 0,
    );
    final hl = SetReport(
      gameType: 'high_low',
      agency: AgencyStage.decide,
      rounds: [answered(true), answered(false)],
      correctCount: 1,
      level: 0,
    );
    final lq = SetReport(
      gameType: 'loud_quiet',
      agency: AgencyStage.decide,
      rounds: [answered(true)],
      correctCount: 1,
      level: 0,
    );
    await tester.runAsync(() async {
      GameSession.recordFinishedSet(
        context,
        SetReport(
          gameType: 'journey_stone',
          agency: AgencyStage.decide,
          rounds: [...hl.rounds, ...lq.rounds],
          correctCount: 2,
        ),
        parts: [hl, lq],
      );
    });
    final id = profiles.activeProfile!.id;
    expect(tiers.gameRecord(id, 'high_low')!.slots, [
      TierSlot.right,
      TierSlot.wrong,
    ]);
    expect(tiers.gameRecord(id, 'loud_quiet')!.slots, [TierSlot.right]);
    expect(tiers.gameRecord(id, 'journey_stone'), isNull);
  });

  test('a report counts what the child finished and what the adult '
      'skipped', () {
    final report = SetReport(
      gameType: 'high_low',
      agency: AgencyStage.observe,
      rounds: [_round(), _round(skipped: true), _round()],
      correctCount: 0,
    );
    expect(report.completed, 2);
    expect(report.skipped, 1);
  });

  for (final id in gameScreens.keys) {
    testWidgets("HOSTED in a stone, $id shows the stone's progress, not its "
        "own set's", (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: gameScreens[id]!(
            GameEntry(
              agency: AgencyStage.observe,
              rounds: 2,
              progress: const ProgressSource.stone(total: 5, doneBefore: 2),
              onFinished: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<RoundSetProgressBar>(find.byType(RoundSetProgressBar))
            .progress,
        0.4,
        reason: "two of the stone's five rounds already played",
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('HOSTED, $id hands its report back and neither records the '
        'set nor leaves — a stone decides what comes next', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final reports = <SetReport>[];
      await tester.pumpWidget(
        MaterialApp(
          home: gameScreens[id]!(
            GameEntry(
              agency: AgencyStage.observe,
              rounds: 1,
              progress: const ProgressSource.ownSet(),
              onFinished: reports.add,
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.byTooltip('Skip'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(reports, hasLength(1));
      expect(reports.single.gameType, id);
      expect(reports.single.rounds, hasLength(1));
      expect(reports.single.skipped, 1);
      expect(find.byType(MaterialApp), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }

  test('the catalogue opens exactly the built games', () {
    expect(gameScreens.keys.toSet(), {for (final g in builtGames) g.id});
  });
}

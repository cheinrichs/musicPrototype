import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ear_trainer/app/state/dev_settings_state.dart';
import 'package:ear_trainer/app/state/profile_state.dart';
import 'package:ear_trainer/app/state/progress_state.dart';
import 'package:ear_trainer/games/game_session.dart';
import 'package:ear_trainer/games/high_low/models/round_instrumentation.dart';
import 'package:ear_trainer/games/high_low/services/agency_advancement.dart';
import 'package:ear_trainer/models/agency_stage.dart';

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
  void Function(BuildContext) body,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: profiles),
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('with no child chosen, a set opens at Observe with the '
      'Observe-length set — the least demanding level', (tester) async {
    late GameEntry entry;
    await _withContext(
      tester,
      ProfileState(),
      (c) => entry = GameEntry.forActiveChild(c),
    );
    expect(entry.agency, AgencyStage.observe);
    expect(entry.rounds, 3);
    expect(entry.tier, isNull);
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
      (c) => entry = GameEntry.forActiveChild(c),
    );
    expect(entry.agency, AgencyStage.explore);
    expect(entry.rounds, 4);
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
}

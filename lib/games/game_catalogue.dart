import 'package:flutter/widgets.dart';

import 'game_session.dart';
import 'high_low/screens/high_low_screen.dart';
import 'loud_quiet/screens/loud_quiet_screen.dart';

/// How to open each built game at a given [GameEntry] — what a stone uses to
/// play whichever game it drew. Keyed by the same id as
/// `CurriculumGame.id` and every [SetReport.gameType].
final Map<String, Widget Function(GameEntry entry)> gameScreens = {
  'high_low': (entry) => HighLowScreen(entry: entry),
  'loud_quiet': (entry) => LoudQuietScreen(entry: entry),
};

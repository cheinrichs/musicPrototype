import 'package:go_router/go_router.dart';
import '../ui/screens/main_shell.dart';
import '../ui/screens/songstone_home_screen.dart';
import '../games/high_low/screens/high_low_screen.dart';
import '../games/scale_direction/screens/scale_direction_screen.dart';
import '../games/match_note/screens/match_note_screen.dart';
import '../games/interval_id/screens/interval_screen.dart';
import '../games/chord_id/screens/chord_screen.dart';
import '../games/same_different/screens/same_different_screen.dart';
import '../games/timbre_id/screens/timbre_screen.dart';
import '../games/rhythm_id/screens/rhythm_screen.dart';
import '../games/pitch_name/screens/pitch_name_screen.dart';
import '../rewards/screens/reward_screen.dart';
import '../ui/screens/skill_profile_screen.dart';

/// App routes configuration
class AppRoutes {
  static const String landing = '/welcome';
  static const String home = '/';
  static const String highLow = '/high-low';
  static const String scaleDirection = '/scale-direction';
  static const String matchNote = '/match-note';
  static const String intervalId = '/interval-id';
  static const String chordId = '/chord-id';
  static const String sameDifferent = '/same-different';
  static const String timbreId = '/timbre-id';
  static const String rhythmId = '/rhythm-id';
  static const String pitchName = '/pitch-name';
  static const String reward = '/reward';
  static const String skillProfile = '/skill-profile';
}

/// Create the app router
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.landing,
  routes: [
    GoRoute(
      path: AppRoutes.landing,
      builder: (context, state) => const SongStoneHomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return MainShell(initialTabIndex: extra?['initialTab'] as int? ?? 0);
      },
    ),
    GoRoute(
      path: AppRoutes.highLow,
      builder: (context, state) => const HighLowScreen(),
    ),
    GoRoute(
      path: AppRoutes.scaleDirection,
      builder: (context, state) => const ScaleDirectionScreen(),
    ),
    GoRoute(
      path: AppRoutes.matchNote,
      builder: (context, state) => const MatchNoteScreen(),
    ),
    GoRoute(
      path: AppRoutes.intervalId,
      builder: (context, state) => const IntervalScreen(),
    ),
    GoRoute(
      path: AppRoutes.chordId,
      builder: (context, state) => const ChordScreen(),
    ),
    GoRoute(
      path: AppRoutes.sameDifferent,
      builder: (context, state) => const SameDifferentScreen(),
    ),
    GoRoute(
      path: AppRoutes.timbreId,
      builder: (context, state) => const TimbreScreen(),
    ),
    GoRoute(
      path: AppRoutes.rhythmId,
      builder: (context, state) => const RhythmScreen(),
    ),
    GoRoute(
      path: AppRoutes.pitchName,
      builder: (context, state) => const PitchNameScreen(),
    ),
    GoRoute(
      path: AppRoutes.skillProfile,
      builder: (context, state) => const SkillProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.reward,
      builder: (context, state) {
        // Extract parameters from extra
        final extra = state.extra as Map<String, dynamic>?;
        return RewardScreen(
          correctCount: extra?['correctCount'] ?? 0,
          totalCount: extra?['totalCount'] ?? 0,
          gameType: extra?['gameType'] ?? 'high_low',
          fromPath: extra?['fromPath'] ?? false,
          nodeId: extra?['nodeId'] as String?,
        );
      },
    ),
  ],
);

import 'package:go_router/go_router.dart';
import '../ui/screens/home_screen.dart';
import '../games/high_low/screens/high_low_screen.dart';
import '../games/scale_direction/screens/scale_direction_screen.dart';
import '../games/match_note/screens/match_note_screen.dart';
import '../rewards/screens/reward_screen.dart';

/// App routes configuration
class AppRoutes {
  static const String home = '/';
  static const String highLow = '/high-low';
  static const String scaleDirection = '/scale-direction';
  static const String matchNote = '/match-note';
  static const String reward = '/reward';
}

/// Create the app router
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
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
      path: AppRoutes.reward,
      builder: (context, state) {
        // Extract parameters from extra
        final extra = state.extra as Map<String, dynamic>?;
        return RewardScreen(
          correctCount: extra?['correctCount'] ?? 0,
          totalCount: extra?['totalCount'] ?? 0,
          gameType: extra?['gameType'] ?? 'high_low',
        );
      },
    ),
  ],
);

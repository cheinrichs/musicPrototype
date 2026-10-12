import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/router.dart';
import '../../app/state/progress_state.dart';

/// How a round set ends (Trello card 196), shared by every game.
///
/// The progress bar is a promise that the set ends, so when it fills the
/// set really does end — it never silently restarts. For now that means
/// back to the games screen; once stones exist this becomes the stone's
/// celebration and the bar's denominator repoints to the stone.
abstract final class RoundSetEnd {
  /// How long the full bar shows before leaving, so the child sees it full.
  static const beat = Duration(milliseconds: 900);

  /// Leaves for the games screen. A set opened from the Learning Path marks
  /// its node done and returns to the path, as the reward screen used to.
  static void leave(BuildContext context, {Object? routeExtra}) {
    final extra = routeExtra is Map<String, dynamic> ? routeExtra : null;
    if (extra?['fromPath'] == true) {
      try {
        final progress = context.read<ProgressState>();
        final nodeId = extra?['nodeId'] as String?;
        if (nodeId != null) progress.completeNode(nodeId);
        progress.requestPathReturn();
      } on ProviderNotFoundException {
        // Tests without the app's providers.
      }
      // The shell opens on the path itself, as the reward screen's
      // "Back to Path" did.
      context.go(AppRoutes.home);
      return;
    }
    context.go(AppRoutes.home, extra: {'initialTab': 0});
  }
}

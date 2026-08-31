import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/state/progress_state.dart';
import 'home_screen.dart';
import 'learning_path_screen.dart';
import 'playground_screen.dart';

/// Top-level shell hosting the app's three sections.
///
/// Used to also show a bottom nav bar for switching between them (Trello
/// card 49 removed it: each section now has its own back arrow to the
/// SongStone landing screen instead, which is the only place all three are
/// reachable from — see [BackToLandingButton]). [IndexedStack] still keeps
/// all three alive so switching via [initialTabIndex] or a path-return
/// doesn't lose a screen's scroll position/state.
class MainShell extends StatefulWidget {
  /// Which tab to open on. Defaults to the games grid (index 0). The
  /// SongStone landing screen passes this via its route `extra` so its
  /// "Playground"/"Learning Path"/"Games" buttons land on the matching tab.
  final int initialTabIndex;

  const MainShell({super.key, this.initialTabIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _selectedIndex = widget.initialTabIndex.clamp(0, _pages.length - 1);

  static const _pages = [
    HomeScreen(),
    LearningPathScreen(),
    PlaygroundScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // React to reward screen requesting a return to the path tab.
    final progress = context.watch<ProgressState>();
    if (progress.pendingPathReturn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedIndex = 1);
          progress.clearPathReturn();
        }
      });
    }

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
    );
  }
}

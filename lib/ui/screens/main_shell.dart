import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/state/progress_state.dart';
import '../../ui/theme/theme.dart';
import 'home_screen.dart';
import 'learning_path_screen.dart';
import 'playground_screen.dart';

/// Top-level shell with bottom navigation between app sections
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: AppColors.surface,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note_rounded),
            label: 'Ear Training',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Learning Path',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.spatial_audio_rounded),
            label: 'Playground',
          ),
        ],
      ),
    );
  }
}

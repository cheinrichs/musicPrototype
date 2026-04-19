import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/state/progress_state.dart';
import '../../ui/theme/theme.dart';
import 'home_screen.dart';
import 'learning_path_screen.dart';
import 'playground_screen.dart';

/// Top-level shell with bottom navigation between app sections
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

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

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global progress state for tracking user achievements
class ProgressState extends ChangeNotifier {
  static const String _totalSessionsKey = 'total_sessions';
  static const String _highLowSessionsKey = 'high_low_sessions';
  static const String _completedNodesKey = 'completed_nodes';

  int _totalSessions = 0;
  int _highLowSessions = 0;
  bool _isLoaded = false;
  Set<String> _completedNodeIds = {};
  // In-memory only: signals MainShell to switch to the Learning Path tab.
  bool _pendingPathReturn = false;

  // Getters
  int get totalSessions => _totalSessions;
  int get highLowSessions => _highLowSessions;
  bool get isLoaded => _isLoaded;
  Set<String> get completedNodeIds => Set.unmodifiable(_completedNodeIds);
  bool get pendingPathReturn => _pendingPathReturn;

  /// Load progress from local storage
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _totalSessions = prefs.getInt(_totalSessionsKey) ?? 0;
      _highLowSessions = prefs.getInt(_highLowSessionsKey) ?? 0;
      final savedNodes = prefs.getString(_completedNodesKey) ?? '';
      _completedNodeIds = savedNodes.isEmpty
          ? {}
          : savedNodes.split(',').toSet();
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      // If loading fails, continue with defaults
      _isLoaded = true;
    }
  }

  /// Save progress to local storage
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_totalSessionsKey, _totalSessions);
      await prefs.setInt(_highLowSessionsKey, _highLowSessions);
      await prefs.setString(_completedNodesKey, _completedNodeIds.join(','));
    } catch (e) {
      // Silently fail - progress will be saved next time
    }
  }

  /// Record a completed game session
  void completeSession({
    required String gameType,
    required int correctCount,
    required int totalCount,
  }) {
    _totalSessions++;

    if (gameType == 'high_low') {
      _highLowSessions++;
    }

    notifyListeners();
    _save();
  }

  /// Mark a learning path node as completed and persist it.
  void completeNode(String nodeId) {
    if (_completedNodeIds.contains(nodeId)) return;
    _completedNodeIds = {..._completedNodeIds, nodeId};
    notifyListeners();
    _save();
  }

  /// Signal MainShell to switch to the Learning Path tab on next build.
  void requestPathReturn() {
    _pendingPathReturn = true;
    notifyListeners();
  }

  /// Consumed by MainShell after switching to the path tab.
  void clearPathReturn() {
    _pendingPathReturn = false;
    // No notifyListeners needed — MainShell calls this during its own setState.
  }

  /// Reset all progress (for testing or user request)
  Future<void> reset() async {
    _totalSessions = 0;
    _highLowSessions = 0;
    _completedNodeIds = {};
    notifyListeners();
    await _save();
  }
}

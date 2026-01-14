import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global progress state for tracking user achievements
class ProgressState extends ChangeNotifier {
  static const String _currentStreakKey = 'current_streak';
  static const String _longestStreakKey = 'longest_streak';
  static const String _totalSessionsKey = 'total_sessions';
  static const String _highLowSessionsKey = 'high_low_sessions';

  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalSessions = 0;
  int _highLowSessions = 0;
  bool _isLoaded = false;

  // Getters
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get totalSessions => _totalSessions;
  int get highLowSessions => _highLowSessions;
  bool get isLoaded => _isLoaded;

  /// Load progress from local storage
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
      _longestStreak = prefs.getInt(_longestStreakKey) ?? 0;
      _totalSessions = prefs.getInt(_totalSessionsKey) ?? 0;
      _highLowSessions = prefs.getInt(_highLowSessionsKey) ?? 0;
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
      await prefs.setInt(_currentStreakKey, _currentStreak);
      await prefs.setInt(_longestStreakKey, _longestStreak);
      await prefs.setInt(_totalSessionsKey, _totalSessions);
      await prefs.setInt(_highLowSessionsKey, _highLowSessions);
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

    // Calculate if session was successful (>= 70% correct)
    final accuracy = totalCount > 0 ? correctCount / totalCount : 0;
    if (accuracy >= 0.7) {
      _currentStreak++;
      if (_currentStreak > _longestStreak) {
        _longestStreak = _currentStreak;
      }
    } else {
      _currentStreak = 0;
    }

    notifyListeners();
    _save();
  }

  /// Reset all progress (for testing or user request)
  Future<void> reset() async {
    _currentStreak = 0;
    _longestStreak = 0;
    _totalSessions = 0;
    _highLowSessions = 0;
    notifyListeners();
    await _save();
  }
}

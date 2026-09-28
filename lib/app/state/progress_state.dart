import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Progress state for tracking user achievements — scoped to whichever
/// profile is active (Trello card 170, "local profiles"). [loadForProfile]
/// is the real entry point once profiles exist; the parameterless [load]
/// is a legacy/unscoped fallback kept only so a caller with no profile
/// context yet (or a test) still gets a working, if globally-shared, store.
class ProgressState extends ChangeNotifier {
  static const String _totalSessionsKeyBase = 'total_sessions';
  static const String _highLowSessionsKeyBase = 'high_low_sessions';
  static const String _completedNodesKeyBase = 'completed_nodes';

  /// Which profile's data this instance currently holds — null means the
  /// legacy, unscoped store. Included in every key via [_key] so switching
  /// profiles (a fresh [loadForProfile] call) can never read or write
  /// another child's data.
  String? _profileId;

  String _key(String base) =>
      _profileId == null ? base : 'profile_${_profileId}_$base';

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

  /// Load progress from local storage, unscoped. See the class doc — prefer
  /// [loadForProfile] once a profile is known.
  Future<void> load() async {
    if (_isLoaded) return;
    await _loadInternal();
  }

  /// Load (or reload) progress scoped to [profileId] — the child whose data
  /// this session should read and write from here on. Always re-reads, even
  /// if already loaded, since switching the active profile mid-session
  /// (picking a different child) must never leave the previous child's
  /// counts sitting in memory.
  Future<void> loadForProfile(String profileId) async {
    _profileId = profileId;
    _isLoaded = false;
    await _loadInternal();
  }

  Future<void> _loadInternal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalSessions = prefs.getInt(_key(_totalSessionsKeyBase)) ?? 0;
      _highLowSessions = prefs.getInt(_key(_highLowSessionsKeyBase)) ?? 0;
      final savedNodes = prefs.getString(_key(_completedNodesKeyBase)) ?? '';
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
      await prefs.setInt(_key(_totalSessionsKeyBase), _totalSessions);
      await prefs.setInt(_key(_highLowSessionsKeyBase), _highLowSessions);
      await prefs.setString(
        _key(_completedNodesKeyBase),
        _completedNodeIds.join(','),
      );
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

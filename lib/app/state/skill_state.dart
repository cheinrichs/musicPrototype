import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/musical_skill.dart';

/// XP thresholds for each level boundary (index = level number).
/// Level 0 = 0 XP (not started). Any XP at all puts you at Level 1
/// with visible bar progress, avoiding the "just leveled up, bar is empty" look.
const List<int> _levelThresholds = [0, 1, 100, 300, 600, 1000];

const int _maxLevel = 5;

/// Tracks per-skill XP and derived levels for all 11 musical skill nodes.
/// Intended for developer / parent visibility — not directly shown to kids.
class SkillState extends ChangeNotifier {
  final Map<MusicalSkill, int> _xp = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Total XP accumulated for [skill].
  int xpFor(MusicalSkill skill) => _xp[skill] ?? 0;

  /// Current level (0–5) for [skill].
  int levelFor(MusicalSkill skill) => _levelFromXp(xpFor(skill));

  /// XP progress within the current level (0.0–1.0), for the progress bar.
  double progressFor(MusicalSkill skill) {
    final xp = xpFor(skill);
    final level = _levelFromXp(xp);
    if (level >= _maxLevel) return 1.0;
    final start = _levelThresholds[level];
    final end = _levelThresholds[level + 1];
    return (xp - start) / (end - start);
  }

  /// XP remaining to reach the next level, for display.
  int xpToNextLevelFor(MusicalSkill skill) {
    final xp = xpFor(skill);
    final level = _levelFromXp(xp);
    if (level >= _maxLevel) return 0;
    return _levelThresholds[level + 1] - xp;
  }

  /// Award [xp] points to [skill] and persist.
  void awardXp(MusicalSkill skill, int xp) {
    if (xp <= 0) return;
    _xp[skill] = (_xp[skill] ?? 0) + xp;
    notifyListeners();
    _save();
  }

  /// Load XP values from local storage.
  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final skill in MusicalSkill.values) {
        final stored = prefs.getInt(_key(skill));
        if (stored != null) _xp[skill] = stored;
      }
      _isLoaded = true;
      notifyListeners();
    } catch (_) {
      _isLoaded = true;
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _xp.entries) {
        await prefs.setInt(_key(entry.key), entry.value);
      }
    } catch (_) {}
  }

  /// Populate all skills with random XP weighted toward a realistic spread
  /// (mix of not-started, mid-level, and high-level). Dev / testing only.
  Future<void> seedRandom() async {
    final rng = Random();
    // Pool of XP values that produce a natural-looking spread across levels.
    const pool = [0, 0, 25, 60, 120, 200, 380, 550, 800, 1100];
    for (final skill in MusicalSkill.values) {
      _xp[skill] = pool[rng.nextInt(pool.length)];
    }
    notifyListeners();
    await _save();
  }

  /// Reset all skill XP (for testing / dev use).
  Future<void> reset() async {
    _xp.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final skill in MusicalSkill.values) {
        await prefs.remove(_key(skill));
      }
    } catch (_) {}
  }

  static String _key(MusicalSkill skill) => 'skill_xp_${skill.name}';

  static int _levelFromXp(int xp) {
    for (var i = _maxLevel; i >= 1; i--) {
      if (xp >= _levelThresholds[i]) return i;
    }
    return 0;
  }
}

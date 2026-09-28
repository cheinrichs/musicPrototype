import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/agency_stage.dart';
import '../../models/musical_skill.dart';
import '../../models/profile.dart';
import '../config.dart';

/// Local, on-device profiles — one per child, plus at most one adult
/// profile that unlocks the dev screens (Trello card 170).
///
/// **Deliberately tiny.** A profile is picked at launch; the per-round
/// tracking log, tier state and agency state all scope to it (see
/// [ProgressState.loadForProfile]/[SkillState.loadForProfile]); the dev
/// gate is reachable only from the adult one ([canUseDevTools]). Local
/// only — no accounts, no network, no sync.
///
/// **The one real data migration in this whole architecture rework lives
/// here** (Trello card 168 needed none: nothing had ever persisted agency).
/// Introducing profile-scoped keys obsoletes the flat, unscoped keys
/// [ProgressState]/[SkillState] used before profiles existed. That old data
/// is entirely Cooper testing the app himself, not real play — so [load]
/// purges it outright, once, rather than trying to migrate it into
/// whichever profile happens to be created first.
class ProfileState extends ChangeNotifier {
  static const String _profilesKey = 'profiles_v1';
  static const String _purgedKey = 'profiles_v1_purged_pre_profile_data';

  /// The flat keys [ProgressState]/[SkillState] wrote before profiles
  /// existed — purged once, on this state's first ever [load]. Kept
  /// together here (rather than each class purging its own) so the one
  /// migration is one visible list, not scattered.
  static List<String> _preProfileKeysToPurge() => [
    'total_sessions',
    'high_low_sessions',
    'completed_nodes',
    for (final skill in MusicalSkill.values) 'skill_xp_${skill.name}',
  ];

  List<Profile> _profiles = [];
  Profile? _activeProfile;
  bool _isLoaded = false;

  List<Profile> get profiles => List.unmodifiable(_profiles);
  Profile? get activeProfile => _activeProfile;
  bool get isLoaded => _isLoaded;

  bool get hasAdultProfile => _profiles.any((p) => p.isAdult);

  /// Whether the dev screens (High/Low's agency/tier gate, the skill
  /// profile screen's seed/reset buttons) may be shown right now — both an
  /// internal build ([devToolsEnabled], never true on the public App
  /// Store) *and* the active profile being the adult's. Neither alone is
  /// enough: an internal build a child is using must not show dev tools,
  /// and a public build must never show them regardless of profile.
  bool get canUseDevTools =>
      devToolsEnabled && (_activeProfile?.isAdult ?? false);

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_purgedKey) != true) {
        for (final key in _preProfileKeysToPurge()) {
          await prefs.remove(key);
        }
        await prefs.setBool(_purgedKey, true);
      }
      final raw = prefs.getStringList(_profilesKey);
      _profiles = raw == null
          ? []
          : raw
                .map(
                  (s) =>
                      Profile.fromJson(jsonDecode(s) as Map<String, dynamic>),
                )
                .toList();
    } catch (_) {
      _profiles = [];
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_profilesKey, [
        for (final p in _profiles) jsonEncode(p.toJson()),
      ]);
    } catch (_) {
      // Local-only convenience data; a failed save just costs a re-pick
      // next launch, same posture as the other local state in this app.
    }
  }

  /// Adds a new profile and returns it. Ignored (returns the existing one)
  /// for a second `isAdult: true` — at most one adult profile can exist
  /// (see the class doc); the picker screen is expected to check
  /// [hasAdultProfile] itself and not offer this in that case, but the
  /// invariant is enforced here too rather than trusted to the UI alone.
  Future<Profile> addProfile(String name, {bool isAdult = false}) async {
    if (isAdult && hasAdultProfile) {
      return _profiles.firstWhere((p) => p.isAdult);
    }
    final profile = Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      isAdult: isAdult,
    );
    _profiles = [..._profiles, profile];
    notifyListeners();
    await _save();
    return profile;
  }

  /// Sets the active profile for this session. Not persisted across
  /// launches by design — "pick a profile at launch" (Trello card 170) is
  /// a deliberate step every time on a shared device, not a remembered
  /// default that could silently apply the wrong child's session.
  void selectProfile(Profile profile) {
    _activeProfile = profile;
    notifyListeners();
  }

  Future<void> setAgencyOverride(Profile profile, AgencyStage? stage) async {
    final updated = stage == null
        ? profile.copyWith(clearAgencyOverride: true)
        : profile.copyWith(agencyOverride: stage);
    _profiles = [for (final p in _profiles) p.id == profile.id ? updated : p];
    if (_activeProfile?.id == profile.id) _activeProfile = updated;
    notifyListeners();
    await _save();
  }
}

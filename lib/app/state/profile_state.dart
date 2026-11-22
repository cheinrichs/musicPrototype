import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/agency_stage.dart';
import '../../models/musical_skill.dart';
import '../../models/profile.dart';
import '../config.dart';

/// Local, on-device profiles — one per child, plus, on INTERNAL builds
/// only, Cooper's dev profile (Trello card 170; compiled out of a release
/// build, see [kDevProfileCompiledIn]). Not a general adult profile: a
/// parent needs a door, not a player.
///
/// **Deliberately tiny.** A profile is picked at launch; the per-round
/// tracking log, tier state and agency state all scope to it (see
/// [ProgressState.loadForProfile]/[SkillState.loadForProfile]); the dev
/// gate is reachable only from the dev one ([canUseDevTools]). Local
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

  /// The children, in the order they were added — the picker's players.
  List<Profile> get childProfiles =>
      List.unmodifiable(_profiles.where((p) => !p.isDev));

  /// The dev profile, if this binary has one and it exists yet. Always
  /// null in a release-flavoured build (see [kDevProfileCompiledIn]).
  Profile? get devProfile {
    if (!kDevProfileCompiledIn) return null;
    for (final p in _profiles) {
      if (p.isDev) return p;
    }
    return null;
  }

  /// Whether the dev screens (High/Low's agency/tier gate, the skill
  /// profile screen's seed/reset buttons) may be shown right now — both an
  /// internal install ([devToolsEnabled], never true on the public App
  /// Store) *and* the active profile being the dev profile. Neither alone
  /// is enough: an internal build a child is using must not show dev tools,
  /// and a public build must never show them regardless of profile.
  bool get canUseDevTools =>
      kDevProfileCompiledIn &&
      devToolsEnabled &&
      (_activeProfile?.isDev ?? false);

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
      // A release-flavoured binary has no dev profile, whatever is stored.
      if (!kDevProfileCompiledIn) {
        _profiles = _profiles.where((p) => !p.isDev).toList();
      }
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

  /// The most children one device holds (Cooper, 2026-11-15). At the cap
  /// the picker HIDES its "Add Profile" tile: a + that does nothing is
  /// worse than one that isn't there. The way back is deleting one in
  /// settings.
  static const int maxChildren = 6;

  bool get canAddChild => childProfiles.length < maxChildren;

  /// The avatars other children on this device already wear: hidden from
  /// the quiz and the chooser, so no two siblings share a face. The avatar
  /// is the only thing a non-reader can use to find themselves on the
  /// picker. [exceptId]'s own avatar stays available to them.
  Set<int> takenAvatars({String? exceptId}) => {
    for (final p in childProfiles)
      if (p.id != exceptId) p.avatarIndex,
  };

  /// Adds a child from the setup quiz's answers (card 202) and returns it,
  /// or null at the cap. Called ONLY when the quiz completes: the quiz holds
  /// its answers in memory, so backing out of it at any question leaves no
  /// half-made profile behind (Cooper, 2026-11-15). The agency is the
  /// PARENT's placement, recorded as such.
  Future<Profile?> addChild(SetupAnswers answers) async {
    if (!canAddChild) return null;
    final profile = Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: answers.name,
      avatar: answers.avatar,
      ageBand: answers.ageBand,
      agencyOverride: answers.agency,
      agencySource: AgencySource.parent,
    );
    _profiles = [..._profiles, profile];
    notifyListeners();
    await _save();
    return profile;
  }

  /// Settings: a new picture for [profile]. Ignored if another child wears
  /// it. Both the picker badge and the Journey pin read [Profile.avatarIndex],
  /// so both follow.
  Future<void> setAvatar(Profile profile, int avatar) async {
    if (takenAvatars(exceptId: profile.id).contains(avatar)) return;
    await _update(profile.copyWith(avatar: avatar));
  }

  /// Settings: where play starts. A STARTING POINT (Cooper, option (b)):
  /// play still promotes and demotes the child as card 199 says, and the
  /// settings screen says so, so a later change does not look like the
  /// setting failing to save.
  Future<void> setPlacement(Profile profile, AgencyStage stage) => _update(
    profile.copyWith(agencyOverride: stage, agencySource: AgencySource.parent),
  );

  Future<void> setAgeBand(Profile profile, AgeBand band) =>
      _update(profile.copyWith(ageBand: band));

  /// Settings: deletes [profile] and everything saved under it (its keys all
  /// begin `profile_<id>_`). Permanent; the settings screen asks first.
  Future<void> deleteProfile(Profile profile) async {
    _profiles = [
      for (final p in _profiles)
        if (p.id != profile.id) p,
    ];
    if (_activeProfile?.id == profile.id) _activeProfile = null;
    notifyListeners();
    await _save();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith('profile_${profile.id}_')) await prefs.remove(key);
      }
    } catch (_) {}
  }

  Future<void> _update(Profile updated) async {
    _replace(updated);
    notifyListeners();
    await _save();
  }

  /// The dev profile, made the first time it is opened. Internal builds
  /// only: in a release-flavoured build this is dead code and the dev
  /// profile can never be created.
  Future<Profile?> ensureDevProfile({String name = 'Dev'}) async {
    if (!kDevProfileCompiledIn) return null;
    final existing = devProfile;
    if (existing != null) return existing;
    final profile = Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      isDev: true,
    );
    _profiles = [..._profiles, profile];
    notifyListeners();
    await _save();
    return profile;
  }

  /// A bare profile with no setup answers — for tests. A dev one goes
  /// through [ensureDevProfile] (so there is still at most one, and none
  /// in a release-flavoured build).
  @visibleForTesting
  Future<Profile> addProfile(String name, {bool isDev = false}) async {
    if (isDev) return (await ensureDevProfile(name: name))!;
    final profile = Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
    );
    _profiles = [..._profiles, profile];
    notifyListeners();
    await _save();
    return profile;
  }

  void _replace(Profile updated) {
    _profiles = [for (final p in _profiles) p.id == updated.id ? updated : p];
    if (_activeProfile?.id == updated.id) _activeProfile = updated;
  }

  /// Sets the active profile for this session. Not persisted across
  /// launches by design — "pick a profile at launch" (Trello card 170) is
  /// a deliberate step every time on a shared device, not a remembered
  /// default that could silently apply the wrong child's session.
  void selectProfile(Profile profile) {
    _activeProfile = profile;
    notifyListeners();
  }

  /// Sets [profile]'s agency as PLAY moved it (advancement or demotion) —
  /// a parent's placement goes through [addChild]/[setPlacement].
  Future<void> setAgencyOverride(Profile profile, AgencyStage? stage) async {
    final updated = stage == null
        ? profile.copyWith(clearAgencyOverride: true)
        : profile.copyWith(
            agencyOverride: stage,
            agencySource: AgencySource.play,
          );
    _replace(updated);
    notifyListeners();
    await _save();
  }

  /// Sets [profile]'s level in [gameId] as PLAY moved it (tier promotion
  /// or demotion). See `GameLevels`.
  Future<void> setLevel(Profile profile, String gameId, int level) async {
    final current = _profiles.firstWhere(
      (p) => p.id == profile.id,
      orElse: () => profile,
    );
    _replace(current.copyWith(levels: {...current.levels, gameId: level}));
    notifyListeners();
    await _save();
  }
}

/// The setup quiz's four answers (card 202) — never more.
class SetupAnswers {
  final String name;
  final int avatar;
  final AgencyStage agency;
  final AgeBand ageBand;

  const SetupAnswers({
    required this.name,
    required this.avatar,
    required this.agency,
    required this.ageBand,
  });
}

import 'agency_stage.dart';

/// The child's age band (card 202): drives VOCABULARY only, never tone.
/// A band, never a birth date — we have no use for the exact date, and
/// children's data we do not hold cannot leak.
enum AgeBand {
  twoThree('2–3'),
  fourFive('4–5'),
  sixEight('6–8');

  const AgeBand(this.label);
  final String label;

  static AgeBand? byName(String? name) {
    for (final b in values) {
      if (b.name == name) return b;
    }
    return null;
  }
}

/// Where a profile's agency came from (card 202): a parent placed it at
/// setup, or play moved it. Every parent answer is a starting point, not a
/// verdict — so the tracking log must be able to tell a placed child from
/// one who climbed.
enum AgencySource {
  parent,
  play;

  static AgencySource? byName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// A local, on-device profile (Trello card 170): one per child, plus — on
/// internal builds only — Cooper's dev profile. Local only, no account, no
/// network identity (COPPA/GDPR-K, ages 2–8).
///
/// What the setup quiz (card 202) asks, and nothing more: a name, a
/// picture, the drag question (→ [agencyOverride]) and an age band.
class Profile {
  final String id;
  final String name;

  /// The dev profile: INTERNAL BUILDS ONLY, compiled out of a release
  /// build (see `kDevProfileCompiledIn`), behind the reading gate. Not a
  /// general adult profile — a parent needs a DOOR (settings, adding a
  /// child, credits), not a player. At most one exists.
  final bool isDev;

  /// Which of the sixteen avatars (avatars_badges_16 / avatars_pins_16,
  /// row-major), chosen at setup — the one thing a child who cannot read
  /// recognises as theirs. Null only for profiles made before the quiz
  /// existed; see [avatarIndex].
  final int? avatar;

  /// Null only for profiles made before the quiz existed.
  final AgeBand? ageBand;

  /// The child's agency: set by a parent at setup, or moved by play. Null
  /// means "not set yet" (the game starts at Observe).
  final AgencyStage? agencyOverride;

  /// Where [agencyOverride] came from.
  final AgencySource? agencySource;

  static const int avatarCount = 16;

  const Profile({
    required this.id,
    required this.name,
    this.isDev = false,
    this.avatar,
    this.ageBand,
    this.agencyOverride,
    this.agencySource,
  });

  /// The avatar to show: the chosen one, or — for a profile made before
  /// the quiz — a stable one derived from its id, so it keeps the same
  /// face on every screen until a parent re-takes setup.
  int get avatarIndex => avatar ?? derivedAvatarFor(id);

  static int derivedAvatarFor(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h % avatarCount;
  }

  /// [clearAgencyOverride] exists because a plain `agencyOverride: null`
  /// is indistinguishable from "leave it alone".
  Profile copyWith({
    String? name,
    int? avatar,
    AgeBand? ageBand,
    AgencyStage? agencyOverride,
    AgencySource? agencySource,
    bool clearAgencyOverride = false,
  }) => Profile(
    id: id,
    name: name ?? this.name,
    isDev: isDev,
    avatar: avatar ?? this.avatar,
    ageBand: ageBand ?? this.ageBand,
    agencyOverride: clearAgencyOverride
        ? null
        : (agencyOverride ?? this.agencyOverride),
    agencySource: clearAgencyOverride
        ? null
        : (agencySource ?? this.agencySource),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isDev': isDev,
    'avatar': avatar,
    'ageBand': ageBand?.name,
    'agencyOverride': agencyOverride?.name,
    'agencySource': agencySource?.name,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    name: json['name'] as String,
    // 'isAdult' before 2026-11-14: the one adult profile was Cooper's, and
    // it IS the dev profile now.
    isDev: json['isDev'] as bool? ?? json['isAdult'] as bool? ?? false,
    avatar: _avatarFrom(json['avatar']),
    ageBand: AgeBand.byName(json['ageBand'] as String?),
    agencyOverride: _agencyStageByName(json['agencyOverride'] as String?),
    agencySource: AgencySource.byName(json['agencySource'] as String?),
  );

  /// Out of range (a smaller sheet one day) falls back to the derived one,
  /// never a crash.
  static int? _avatarFrom(Object? raw) =>
      raw is int && raw >= 0 && raw < avatarCount ? raw : null;

  /// A stale or renamed [AgencyStage] value (see Trello card 168's own
  /// renumbering warning) must not crash a profile load — this falls back
  /// to *null* ("not set"), never to a real stage guessed on the profile's
  /// behalf; a parent never actually chose that value.
  static AgencyStage? _agencyStageByName(String? name) {
    if (name == null) return null;
    // Renamed 2026-10-05 (Trello card 181, Drag → Decide). A value saved
    // before the rename means the same stage, so it maps across explicitly
    // rather than silently falling back to "not set".
    if (name == 'drag') return AgencyStage.decide;
    for (final stage in AgencyStage.values) {
      if (stage.name == name) return stage;
    }
    return null;
  }
}

import 'agency_stage.dart';

/// A local, on-device profile (Trello card 170, "Local profiles: one per
/// child, plus an adult profile that sees the dev screens").
///
/// Deliberately tiny — a name, whether this is the one adult profile, and
/// an optional agency override a parent can set directly rather than
/// making a child prove their own capability across several rounds
/// ("a parent already knows whether their child can drag"). Nothing else:
/// no avatar (optional per the card, skipped here — an easy add later, not
/// worth the extra picker UI now), no account, no network identity. Local
/// only, same posture as the tracking log (COPPA/GDPR-K, ages 2-8).
class Profile {
  final String id;
  final String name;

  /// At most one profile in [ProfileState] may have this true — the
  /// adult's, gated to the dev screens (`ProfileState.canUseDevTools`).
  final bool isAdult;

  /// A parent-set capability floor/value, straight onto the profile rather
  /// than inferred — see the class doc. Null means "not set yet"; nothing
  /// in this card defines what null falls back to for an actual game
  /// session (that's the advancement/demotion card).
  final AgencyStage? agencyOverride;

  const Profile({
    required this.id,
    required this.name,
    this.isAdult = false,
    this.agencyOverride,
  });

  /// [setAgencyOverride] defaults to `false` because a plain
  /// `agencyOverride: null` argument is indistinguishable from "leave it
  /// alone" — Dart has no way to tell "pass null" from "pass nothing" for
  /// an optional parameter, so clearing the override needs its own
  /// explicit flag rather than overloading the value itself.
  Profile copyWith({
    String? name,
    AgencyStage? agencyOverride,
    bool clearAgencyOverride = false,
  }) => Profile(
    id: id,
    name: name ?? this.name,
    isAdult: isAdult,
    agencyOverride: clearAgencyOverride
        ? null
        : (agencyOverride ?? this.agencyOverride),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isAdult': isAdult,
    'agencyOverride': agencyOverride?.name,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    name: json['name'] as String,
    isAdult: json['isAdult'] as bool? ?? false,
    agencyOverride: _agencyStageByName(json['agencyOverride'] as String?),
  );

  /// A stale or renamed [AgencyStage] value (see Trello card 168's own
  /// renumbering warning) must not crash a profile load — this falls back
  /// to *null* ("not set"), never to a real stage guessed on the profile's
  /// behalf; a parent never actually chose that value.
  static AgencyStage? _agencyStageByName(String? name) {
    if (name == null) return null;
    for (final stage in AgencyStage.values) {
      if (stage.name == name) return stage;
    }
    return null;
  }
}

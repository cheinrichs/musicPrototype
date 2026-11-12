/// Which games a child's Games library shows — the rail's Games, which is
/// also the dev door (one screen, gated by profile).
///
/// ⚠️ This is LIBRARY AVAILABILITY, never JOURNEY ELIGIBILITY. The Journey
/// draws its rounds from every built game (`JourneyState.games`) from day
/// one, and must, or a stone could not mix games and the never-the-same-
/// game-twice rule would have nothing to alternate. Nothing here may be
/// read by the Journey.
abstract final class GameLibrary {
  /// In every child's library from the start.
  static const Set<String> defaults = {'high_low'};

  /// What else lets a game in. Cooper decided (2026-11): a game joins the
  /// library ONCE THE CHILD HAS MET IT IN THE JOURNEY — not via a reward.
  /// One function, so a different condition is a one-line swap.
  static bool Function(String gameId, Set<String> metInJourney) unlock =
      metInJourney;

  static bool metInJourney(String gameId, Set<String> met) =>
      met.contains(gameId);

  /// Whether [gameId] is in the library. [gated] is false on the adult
  /// profile (Cooper's dev door: every game, as before). On a child's
  /// profile a game not available is HIDDEN, never shown locked: a locked
  /// tile shows exactly which game is withheld (STANDING_RULES.md).
  static bool available(
    String gameId, {
    required bool gated,
    required Set<String> metInJourney,
  }) => !gated || defaults.contains(gameId) || unlock(gameId, metInJourney);
}

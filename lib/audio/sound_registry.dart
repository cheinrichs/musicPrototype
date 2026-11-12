/// Sounds referenced BY ID, mapped to their files — so a replacement set of
/// recordings is a change to this table (STANDING_RULES.md: art and voice
/// are provisional).
///
/// An id with no file is SILENT, never an error or a wait: wired-but-
/// unrecorded is a normal state, and the app must behave correctly in it.
abstract final class Sounds {
  /// Map decorations' pokes (`sfx.decoration.<name>`): Cooper is making
  /// them. NON-PITCHED ONLY — rustles, squeaks, plops, flutters; creatures
  /// make noises, instruments make notes. None recorded yet.
  static const Map<String, String> _table = {};

  /// The file for [id], or null where none is recorded yet.
  static String? pathOf(String id) => _table[id];
}

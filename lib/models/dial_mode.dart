/// When Loud or Quiet's needle moves (Trello card 208).
enum DialMode {
  /// The needle follows every sound: the round's own playback (its start
  /// and every replay) at every agency, Decide included, and every tap.
  /// Settles back to rest once the prompt has played, so it never sits on
  /// the answer for a child who wasn't watching. Cooper's call on build 90:
  /// the apparatus teaches its own meaning, and pairing sound with a visual
  /// magnitude is how the concept is built at this age. The default.
  everySound,

  /// Build 90's rule: only the child's own taps move it, and never at
  /// Decide — so at Decide the child has to listen, not watch. Kept behind
  /// the dev toggle so the two can be compared once discrimination is being
  /// measured rather than taught.
  childTapsOnly;

  String get label => switch (this) {
    DialMode.everySound => 'All',
    DialMode.childTapsOnly => 'Taps',
  };
}

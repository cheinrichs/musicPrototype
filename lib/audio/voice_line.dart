/// Spoken lines used by the agency-staged games (Trello card 91).
/// [AudioController.playVoiceLine] silently no-ops on a missing asset
/// (same fallback the Sound Playground uses for missing instrument
/// clips) — a real gap right now, not just a hypothetical one: several
/// 6-7-band lines below have no recording yet (see each one's doc
/// comment) and simply aren't referenced anywhere until they arrive. The
/// on-screen caption no longer transcribes these lines (see [isPiper]'s
/// doc comment), so a missing recording is otherwise silent.
///
/// **No age-band selector exists anywhere in the app yet** (see
/// `round_report.dart`'s `kCurrentAgeBand` doc comment) — every line
/// below is real, recorded and gain-normalized, but only the
/// original ten (the 2-3/4-5-shared set) are actually wired into
/// [HighLowGameState]'s round flow today. The rest exist so the *data*
/// is complete and correct ahead of a future age-band picker — that
/// picker is its own separate, unstarted epic (Trello card PqqgLOwF),
/// and the voice-lines card itself already treats which lines get
/// *played when* as someone else's job (a rotating nudge pool is a
/// separate card, whether 8+ exists at all is a separate open question)
/// — the same shape as `ConceptTier`'s T5-T8 landing ahead of a
/// three-note screen, which Cooper did confirm explicitly for that case
/// (see that enum's class doc).
///
/// Re-recorded 2026-09-04/05: nine lines replacing the original
/// placeholder takes, plus one ([listenForLow]) filled from an earlier,
/// separately-delivered take Cooper confirmed was already usable. A
/// 2026-09-07 batch (Trello card "Voice clips for the next age band of
/// High/Low") added the 4-5 and 6-7 bands, per Cooper's same-day script
/// review comment on that card:
///
/// - **4-5's A0 pair became canonical for 2-3 too**, replacing
///   [piperSaysLow]/[piperSaysLowSecond]/[clefSaysHigh]/
///   [clefSaysHighSecond]'s recordings in place rather than adding four
///   new near-duplicate members — the two scripts differed only by the
///   word "one" ("That sounds high" vs. "That one sounds high"), and
///   nothing in the app distinguishes those two bands yet anyway.
/// - **"Drag it to me" is gone from every A2 line** — it ran the ladder
///   backwards, putting the most hand-holding phrase in the least
///   hand-holding bands.
/// - **"Note", not "pitch"**, from 6-7 on — a note is a thing that just
///   played; pitch is one more abstraction at the moment a child is
///   trying to listen.
/// - **The wrong-drop nudges below ([tryAgainClef]/[tryAgainPiper] and
///   their band-suffixed siblings) are not wired into a rotating pool**
///   — that's a separate, not-yet-built card (Trello KmufGcge, "Shared
///   rotating nudge pool instead of one line per band"). [HighLowGameState]
///   still always plays the fixed 2-3/4-5-shared [tryAgainClef]/
///   [tryAgainPiper] today.
/// - **8+ has exactly one line below** ([tryAgainPiper8plus]), because
///   every other 8+ script collapsed into its 6-7 equivalent once the
///   above two changes applied — see Trello card X0CCvmVb, "Does
///   High/Low need an 8+ band at all?" (open, not this card's call).
///
/// All lines are gain-normalized together to their own target, separate
/// from the note library (see tool/build_voice_lines.py — cross-batch
/// consistency is a standing concern here, not a one-off: new lines
/// arrive in whatever session Cooper's next batch of recording credits
/// lands in, sometimes one at a time) and format-converted from the
/// 24kHz mono WAVs Cooper delivers to this project's standard
/// mono/44.1kHz/64kbps CBR mp3.
enum VoiceLine {
  /// Piper, narrating the lower instrument in Observe (A0) — spoken as
  /// the first note of the pair. Canonical for both the 2-3 and 4-5
  /// bands as of 2026-09-07 ("That one sounds low.") — see the class doc.
  piperSaysLow,

  /// Piper, narrating the lower instrument in Observe (A0) — spoken as
  /// the *second* note of the pair, continuing the sentence the first
  /// note's narration started ("...and that one sounds low."). Distinct
  /// recording from [piperSaysLow], not a reuse — the two are meant to
  /// join into one sentence across the pair, so whichever narration
  /// happens second needs the "and" continuation, not a repeat of the
  /// first-note line.
  piperSaysLowSecond,

  /// Clef, narrating the higher instrument in Observe (A0) — spoken as
  /// the first note of the pair. Canonical for both the 2-3 and 4-5
  /// bands as of 2026-09-07 ("Ooh! That one sounds high!") — see the
  /// class doc.
  clefSaysHigh,

  /// Clef, narrating the higher instrument in Observe (A0) — spoken as
  /// the *second* note of the pair ("...and ooh! That one sounds
  /// high!") — see [piperSaysLowSecond]'s doc comment for why this is a
  /// distinct recording rather than a reuse of [clefSaysHigh].
  clefSaysHighSecond,

  /// Participate (A1) round prompt when the target is the higher one —
  /// the 2-3-band phrasing ("Ooh! Listen for the high one!"). 4-5 asks
  /// the same thing differently — see [listenForHigh45].
  listenForHigh,

  /// Participate (A1) round prompt when the target is the lower one —
  /// Piper's equivalent of [listenForHigh]. The 2026-09 nine-line batch
  /// covered every other line but not this one; filled from an earlier,
  /// separately-delivered take instead (Cooper: "there's nothing wrong
  /// with the listen for the low one line ... that line is fine for
  /// use") rather than left silent — same 24kHz source format, and its
  /// measured fundamental (108Hz) sits inside the 2026-09 Piper lines'
  /// own range (106-142Hz).
  listenForLow,

  /// Trigger (A2) round prompt when the target is the higher one — the
  /// 2-3-band phrasing ("Give me the high one!"). Clef owns the high
  /// pole (Trello card 101), so this is Clef speaking in the first
  /// person, asking to be handed the correct instrument — Clef stays
  /// centered as the fixed drop target; the child drags an instrument to
  /// her, not the other way around (renamed 2026-09 from `putMeOnHigh`
  /// when the drag direction reversed). 4-5 asks rather than instructs —
  /// see [giveMeHigh45].
  giveMeHigh,

  /// Trigger (A2) round prompt when the target is the lower one — the
  /// 2-3-band phrasing ("Give me the low one."). Piper owns the low pole
  /// (Trello card 101) — see [giveMeHigh]'s doc comment (renamed 2026-09
  /// from `putMeOnLow`).
  giveMeLow,

  /// Trigger (A2) gentle retry after a wrong drop, when Clef is the
  /// dragged character (i.e. the target was the high pole) — the
  /// 2-3/4-5-shared line ("Ooh, nearly! Listen again."). One of the two
  /// characters' four-line rotating nudge pools once Trello card
  /// KmufGcge builds the rotation — see the class doc.
  tryAgainClef,

  /// Trigger (A2) gentle retry after a wrong drop, when Piper is the
  /// dragged character (i.e. the target was the low pole) — the
  /// 2-3/4-5-shared line ("Nearly! Have another listen."). See
  /// [tryAgainClef]'s doc comment.
  tryAgainPiper,

  // ---- 4-5 band: "asking rather than instructing" (genuinely new
  // wording from here down — the A0 pair above is shared, not repeated
  // per band; see the class doc) ----

  /// 4-5's Participate (A1) prompt for the higher one — a question
  /// rather than an instruction ("Which one sounds high?"), the one real
  /// change 4-5 makes over 2-3's [listenForHigh].
  listenForHigh45,

  /// 4-5's Participate (A1) prompt for the lower one — Piper's
  /// equivalent of [listenForHigh45] ("Which one sounds low?").
  listenForLow45,

  /// 4-5's Trigger (A2) prompt for the higher one — asks rather than
  /// instructs ("Can you give me the high one?"), unlike 2-3's
  /// [giveMeHigh].
  giveMeHigh45,

  /// 4-5's Trigger (A2) prompt for the lower one — Piper's equivalent of
  /// [giveMeHigh45] ("Can you give me the low one?").
  giveMeLow45,

  /// 4-5's wrong-drop retry, Clef ("Ooh, so close! Let's hear that
  /// again."). See [tryAgainClef]'s doc comment — one of Clef's four
  /// pool candidates, not yet wired into a rotation.
  tryAgainClef45,

  /// 4-5's wrong-drop retry, Piper ("So close! Let's hear it again.").
  /// See [tryAgainClef45].
  tryAgainPiper45,

  // ---- 6-7 band: comparative form ("higher"/"lower" rather than
  // "high"/"low") and "note" rather than "pitch". Clef's A1, A2, and
  // nudge are not recorded yet (see the checklist on Trello card
  // HxssyHLz) — only Clef's A0 first-note line exists so far. ----

  /// 6-7's Observe (A0) narration for the higher instrument, first note
  /// of the pair ("That note's higher."). The second-note "and..."
  /// continuation (see [piperSaysLowSecond]'s doc comment for the
  /// pattern) has no recording yet — [HighLowGameState]'s Observe intro
  /// always needs both a first- and second-note line for whichever
  /// character narrates second, so this alone isn't enough to wire 6-7's
  /// Observe stage in even once an age-band selector exists.
  clefSaysHigher67,

  /// 6-7's Observe (A0) narration for the lower instrument, first note
  /// of the pair ("That one's lower.").
  piperSaysLower67,

  /// 6-7's Observe (A0) narration for the lower instrument, second note
  /// of the pair ("And that one's lower.") — see [piperSaysLowSecond]'s
  /// doc comment for the first/second pattern.
  piperSaysLower67Second,

  /// 6-7's Participate (A1) prompt for the lower one ("Listen for the
  /// lower note.") — comparative form, and "note" rather than "pitch"
  /// (see the class doc). Clef's equivalent ("Listen for the higher
  /// note.") has no recording yet.
  listenForLower67,

  /// 6-7's Trigger (A2) prompt for the lower one — a question, not an
  /// imperative ("Which note is lower?"): 6-7 asks the child to judge
  /// rather than asking to be handed something, unlike [giveMeLow]/
  /// [giveMeLow45]'s "give me the low one" framing at the younger bands.
  /// Clef's equivalent ("Which note is higher?") has no recording yet.
  whichIsLower67,

  /// 6-7's wrong-drop retry, Piper ("Not that one — one more listen.").
  /// See [tryAgainClef]'s doc comment. Clef's 6-7 nudge has no recording
  /// yet.
  tryAgainPiper67,

  // ---- 8+: see the class doc for why this is the only 8+-specific
  // line — everything else collapsed into its 6-7 equivalent. ----

  /// 8+'s wrong-drop retry, Piper ("That's not it. Try again.") — one of
  /// Piper's four pool candidates once Trello card KmufGcge builds the
  /// rotation. No Clef 8+ nudge exists because Clef's 6-7 nudge itself
  /// isn't recorded yet.
  tryAgainPiper8plus,

  /// Observe (A0)'s first-time arrow cue ("Tap the arrow when you're
  /// ready.") — spoken once per session, the first time the earned arrow
  /// appears (Trello card xpAkja5b, "Two controls: the adult's persistent
  /// skip, and the child's earned arrow"). **No recording exists yet** —
  /// unlike every other line above, this one is a genuine hook: it plays
  /// through the same silent-no-op-on-missing-asset path every line here
  /// already has (see the class doc), so nothing breaks before a real
  /// take arrives. Not spoken by either character in the way the rest of
  /// this enum is — it's a system-level nudge, not in-character dialogue
  /// — so [isPiper]'s `true` here is arbitrary bookkeeping to satisfy the
  /// exhaustive switch, not a real assignment; [HighLowGameState] never
  /// routes this line through the speaking-indicator machinery that
  /// getter serves. Excluded from
  /// `test/audio/voice_line_test.dart`'s "every value resolves to a real,
  /// committed mp3" check for the same reason.
  tapTheArrowWhenReady;

  String get assetPath => 'assets/audio/voice/$name.mp3';

  /// True if Piper speaks this line, false if Clef does — every line
  /// belongs to exactly one of them (Trello card 101: Piper owns low,
  /// Clef owns high). Drives the "the talker moves" speaking indicator
  /// (Trello card PIm7xE6n) — [HighLowGameState] uses this to know which
  /// of Piper/Clef to animate for however long a given line actually
  /// takes to play, rather than re-deriving the speaker from round
  /// context (which round's [PitchDirection] happens to be centered has
  /// nothing to do with which note a per-note Observe narration is
  /// currently describing).
  ///
  /// The per-line caption this used to carry (a direct transcription,
  /// e.g. "Piper: that one sounds low!") is gone — Trello card 5tdMOMh3
  /// ("Captions become parent guidance, not a transcript of the voice
  /// line") replaced it with six fixed captions keyed by stage and pole
  /// only, not by band or by individual line; see
  /// [HighLowGameState.captionText].
  bool get isPiper => switch (this) {
    VoiceLine.piperSaysLow => true,
    VoiceLine.piperSaysLowSecond => true,
    VoiceLine.clefSaysHigh => false,
    VoiceLine.clefSaysHighSecond => false,
    VoiceLine.listenForHigh => false,
    VoiceLine.listenForLow => true,
    VoiceLine.giveMeHigh => false,
    VoiceLine.giveMeLow => true,
    VoiceLine.tryAgainClef => false,
    VoiceLine.tryAgainPiper => true,
    VoiceLine.listenForHigh45 => false,
    VoiceLine.listenForLow45 => true,
    VoiceLine.giveMeHigh45 => false,
    VoiceLine.giveMeLow45 => true,
    VoiceLine.tryAgainClef45 => false,
    VoiceLine.tryAgainPiper45 => true,
    VoiceLine.clefSaysHigher67 => false,
    VoiceLine.piperSaysLower67 => true,
    VoiceLine.piperSaysLower67Second => true,
    VoiceLine.listenForLower67 => true,
    VoiceLine.whichIsLower67 => true,
    VoiceLine.tryAgainPiper67 => true,
    VoiceLine.tryAgainPiper8plus => true,
    VoiceLine.tapTheArrowWhenReady => true, // arbitrary — see its doc comment
  };
}

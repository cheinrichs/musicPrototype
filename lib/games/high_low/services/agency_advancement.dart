import '../../../models/agency_stage.dart';
import '../models/round_instrumentation.dart';

/// What one evaluation recommends.
enum AgencyChange { advance, demote, hold }

/// The result of evaluating a just-completed session's instrumentation
/// against a child's current agency capability (Trello card 172,
/// "Advancement and demotion between Observe, Explore and Drag").
///
/// [reason] exists because the tracking log must record *why*, not just
/// what (a cross-cutting rule repeated across this whole architecture
/// rework, Trello cards 169/172) — an eased or demoted state looks
/// identical to a genuinely regressed one unless the reason travels with
/// it. No persisted tracking log exists yet to receive it (that
/// infrastructure is its own, separate undertaking); until it does, callers
/// should at minimum log [reason] rather than silently dropping it.
class AgencyEvaluation {
  final AgencyChange change;
  final String reason;
  const AgencyEvaluation(this.change, this.reason);

  static const AgencyEvaluation hold = AgencyEvaluation(
    AgencyChange.hold,
    'no qualifying pattern in the recent rounds',
  );
}

/// Evaluates whether a child's agency capability should move, from the
/// instrumentation of the session they just finished. Pure and stateless —
/// callers own reading the current stage and writing a change back (see
/// `HighLowScreen._onGameStateChanged`, which reads/writes it via
/// `ProfileState`).
///
/// **Agency moves on demonstrated capability, never on accuracy** (Cooper).
/// A child who drags confidently to the wrong answer has still demonstrated
/// they can drag — nothing here reads [RoundInstrumentation.firstResponseCorrect]
/// as evidence *for* Drag capability, only [RoundInstrumentation.wrongTapCount]
/// (a demotion signal: many failed attempts is motor difficulty) and
/// [RoundInstrumentation.notesHeardBeforeFirstResponse] (a demotion signal:
/// answering before there was anything to go on).
///
/// **The sparkle confounds Explore→Drag and must stay out of tier
/// evidence.** A child may follow Explore's sparkle rather than the sound —
/// fine, it proves engagement with the task structure, which is exactly
/// what agency measures, but it is not evidence of pitch discrimination.
/// This class only ever returns an [AgencyStage] recommendation; it must
/// never be wired to anything that also advances [ConceptTier] from the
/// same rounds.
///
/// **Explore→Observe demotion is deliberately not implemented.** The card
/// itself says to be cautious: Observe removes the ability to interact, so
/// making a bored, disengaged child *more* passive likely makes it worse.
/// The card's own suggested fix — vary instruments/notes at the same level
/// before ever considering a drop — is a prompt-generation concern this
/// stateless evaluator has no way to arrange or to know was already tried,
/// so it holds rather than guessing.
class AgencyAdvancement {
  /// How many of the session's most recent qualifying rounds must agree
  /// before a change is recommended. "A few rounds," per the card, without
  /// a specific number — 3 is a judgment call: enough that one unusual
  /// round can't flip a recommendation, short enough that a real pattern is
  /// still noticed within a single 5-round session.
  static const int roundsRequired = 3;

  /// Explore→Drag's "consistently" tolerance: up to this many wrong taps in
  /// a round still counts as hitting the sparkle consistently. Zero
  /// tolerance would demand a flawless round from a child whose wrong taps
  /// are explicitly harmless by design elsewhere in this game ("a flat
  /// sparkle is a reward"); this is a judgment call, not a value stated by
  /// the card.
  static const int _exploreNoiseTolerance = 2;

  /// Drag→Explore's "many failed drags" threshold, per round.
  static const int _manyFailedDrags = 3;

  const AgencyAdvancement._();

  static AgencyEvaluation evaluate({
    required AgencyStage current,
    required List<RoundInstrumentation> instrumentation,
  }) {
    if (instrumentation.length < roundsRequired) return AgencyEvaluation.hold;
    final recent = instrumentation.sublist(
      instrumentation.length - roundsRequired,
    );

    switch (current) {
      case AgencyStage.observe:
        return _observeToExplore(recent);
      case AgencyStage.explore:
        return _exploreToDecide(recent) ?? AgencyEvaluation.hold;
      case AgencyStage.decide:
        return _decideDemotion(recent) ?? AgencyEvaluation.hold;
    }
  }

  /// Observe's own completion criterion (tapping both instruments) is what
  /// gets a round recorded at all — [HighLowGameState.tapArrow] only ever
  /// fires once [HighLowGameState.showArrow] is true, and a skipped round
  /// records nothing (see [HighLowGameState.escape]'s doc comment). So the
  /// mere presence of [roundsRequired] recorded rounds already *is* "the
  /// child taps each instrument, across a few rounds" — there is nothing
  /// further to check per round.
  static AgencyEvaluation _observeToExplore(
    List<RoundInstrumentation> recent,
  ) => AgencyEvaluation(
    AgencyChange.advance,
    '$roundsRequired consecutive Observe rounds completed '
    '(both instruments tapped) without being skipped',
  );

  static AgencyEvaluation? _exploreToDecide(List<RoundInstrumentation> recent) {
    final consistent = recent.every(
      (r) => r.wrongTapCount <= _exploreNoiseTolerance,
    );
    if (!consistent) return null;
    return AgencyEvaluation(
      AgencyChange.advance,
      '$roundsRequired consecutive Explore rounds hit the correct '
      '(sparkling) instrument with $_exploreNoiseTolerance or fewer wrong '
      'taps each',
    );
  }

  static AgencyEvaluation? _decideDemotion(List<RoundInstrumentation> recent) {
    if (recent.every((r) => r.wrongTapCount >= _manyFailedDrags)) {
      return AgencyEvaluation(
        AgencyChange.demote,
        '$roundsRequired consecutive Decide rounds each had '
        '$_manyFailedDrags or more failed drags — motor difficulty, not a '
        'wrong answer',
      );
    }
    if (recent.every((r) => r.notesHeardBeforeFirstResponse == false)) {
      return AgencyEvaluation(
        AgencyChange.demote,
        '$roundsRequired consecutive Decide rounds were answered before '
        'either note had finished playing — no evidence existed to act on, '
        'a pattern consistent with guessing rather than dragging',
      );
    }
    return null;
  }
}

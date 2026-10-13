import 'dart:math' as math;

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
  /// How many of the most recent completed rounds must agree before a
  /// DEMOTION is recommended. "A few rounds," per the card, without a
  /// specific number — 3 is a judgment call: enough that one unusual round
  /// can't flip a recommendation. Demotion only happens at Decide, whose sets
  /// are the longest (5), so this still leaves slack.
  static const int roundsRequired = 3;

  /// The share of a set's rounds that must qualify for a PROMOTION (Trello
  /// card 213). A proportion, not a count: the old bare "three in a row" was
  /// chosen when every set was five rounds, and when sets became 3/4/5 by
  /// agency (card 196) it silently became "every round" at Observe. 60% is
  /// what three of five was; XP went the same way, to 80% of the set.
  static const double promotionShare = 0.6;

  /// Never fewer than this many qualifying rounds, however short a set is
  /// made on the dev screen: one round alone never moves a child.
  static const int _promotionFloor = 2;

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

  /// How many qualifying rounds a set of [setLength] rounds needs to promote.
  static int promotionNeeds(int setLength) =>
      math.max(_promotionFloor, (setLength * promotionShare - 1e-9).ceil());

  static AgencyEvaluation evaluate({
    required AgencyStage current,
    required List<RoundInstrumentation> instrumentation,
  }) {
    if (current != AgencyStage.decide) {
      return _promotion(current, instrumentation) ?? AgencyEvaluation.hold;
    }

    // Moving DOWN reads completed rounds only. Whether skips should count
    // toward demotion is a product question, not decided here.
    final completed = [
      for (final r in instrumentation)
        if (!r.skipped) r,
    ];
    if (completed.length < roundsRequired) return AgencyEvaluation.hold;
    final recent = completed.sublist(completed.length - roundsRequired);
    return _decideDemotion(recent) ?? AgencyEvaluation.hold;
  }

  /// Moving UP (Trello card 213): enough of the set's rounds qualify,
  /// [promotionShare] of them, **in any order**.
  ///
  /// - **A skip is neutral.** Skip is the ADULT's control (card xpAkja5b):
  ///   bored, dinner, a sibling grabbed the iPad. It is not evidence about the
  ///   child, so it neither counts as a qualifying round nor breaks anything.
  ///   It still counts in the set's length, so a set the adult mostly skipped
  ///   has too few qualifying rounds and holds — neutral, not free. (It stays
  ///   in the instrumentation as evidence of difficulty for the tracking
  ///   log.)
  /// - **No streak.** Consecutiveness guards against guessing, which is real
  ///   for a two-way choice — but agency asks whether the child can perform
  ///   the gesture, and you cannot luck your way into one. That argument
  ///   belongs to concept tier.
  static AgencyEvaluation? _promotion(
    AgencyStage current,
    List<RoundInstrumentation> set,
  ) {
    if (set.isEmpty) return null;
    final completed = [
      for (final r in set)
        if (!r.skipped) r,
    ];
    final qualifying = current == AgencyStage.observe
        ? completed
        : [
            for (final r in completed)
              if (r.wrongTapCount <= _exploreNoiseTolerance) r,
          ];
    final needed = promotionNeeds(set.length);
    if (qualifying.length < needed) return null;
    final skipped = set.length - completed.length;
    final skipNote = skipped == 0
        ? ''
        : ' ($skipped skipped by the adult, counted neither way)';
    return AgencyEvaluation(
      AgencyChange.advance,
      current == AgencyStage.observe
          ? '${qualifying.length} of ${set.length} Observe rounds completed '
                '(both instruments tapped), $needed needed$skipNote'
          : '${qualifying.length} of ${set.length} Explore rounds hit the '
                'correct (sparkling) instrument with $_exploreNoiseTolerance '
                'or fewer wrong taps, $needed needed$skipNote',
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

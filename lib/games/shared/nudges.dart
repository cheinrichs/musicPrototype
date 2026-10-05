import 'dart:math';

import '../../audio/shared_voice_line.dart';

/// Which character says a nudge: a nudge belongs to the character who is
/// asking, so the pool is kept per character (Trello card 151).
enum NudgeSpeaker { clef, piper }

/// The rotating pool of gentle nudges (Trello card 151, "Nudge pool: rotating
/// lines, and the five-tap rule for when they fire").
///
/// A child who gets several wrong in a row should not hear the same line each
/// time — that reads as nagging. So the pool rotates, and the line played last
/// for a character is excluded from the next pick for that character. Random
/// alone would still hand out the same line twice running often enough to
/// defeat the point, which is why the exclusion is explicit.
///
/// Only recorded lines live here, so a pool that is not yet full simply has
/// fewer members; nothing breaks on a missing recording.
class NudgePool {
  NudgePool({Random? random}) : _random = random ?? Random();

  static const clefLines = [
    SharedVoiceLine.tryAgainClef,
    SharedVoiceLine.tryAgainClef45,
  ];

  static const piperLines = [
    SharedVoiceLine.tryAgainPiper,
    SharedVoiceLine.tryAgainPiper45,
    SharedVoiceLine.tryAgainPiper67,
    SharedVoiceLine.tryAgainPiper8plus,
  ];

  final Random _random;
  final Map<NudgeSpeaker, SharedVoiceLine> _lastPlayed = {};

  /// The next nudge for [speaker], never the one played last for them unless
  /// the pool holds nothing else.
  SharedVoiceLine next(NudgeSpeaker speaker) {
    final pool = switch (speaker) {
      NudgeSpeaker.clef => clefLines,
      NudgeSpeaker.piper => piperLines,
    };
    final last = _lastPlayed[speaker];
    final candidates = pool.where((l) => l != last).toList();
    final choice = (candidates.isEmpty ? pool : candidates)[_random.nextInt(
      candidates.isEmpty ? pool.length : candidates.length,
    )];
    _lastPlayed[speaker] = choice;
    return choice;
  }
}

/// The five-tap rule (Trello card 151): five consistent taps on the same
/// option fire one nudge. The nudge answers persistence, not error. One wrong
/// tap gets nothing; five says "I really think it's this one", and that is what
/// the nudge is for.
///
/// **Counted per option.** A tap on a different option starts that option's
/// count from one, so bouncing between two answers is exploring, not deciding,
/// and never fires. Without this, random tapping would trip the threshold and
/// the nudge would reach a child who was not asking for help.
///
/// Every tap goes through [tap], including the correct one. A correct tap
/// resets the wrong option's run, so five wrong taps split by a correct one do
/// not count as five in a row. The caller decides what a fired run means: for
/// a wrong option it is a nudge; for the right option it is not this counter's
/// business.
///
/// After firing, the run resets, so five more taps on the same option fire
/// again. The no-repeat pool keeps those nudges fresh.
class FiveTapCounter {
  static const threshold = 5;

  int? _option;
  int _run = 0;

  /// Records a tap on [option]. Returns true when this tap completes a run of
  /// [threshold] consecutive taps on that option, and resets the run.
  bool tap(int option) {
    if (option == _option) {
      _run++;
    } else {
      _option = option;
      _run = 1;
    }
    if (_run >= threshold) {
      _run = 0;
      return true;
    }
    return false;
  }

  /// Forgets the current run — for a new round, a skip or a reset.
  void reset() {
    _option = null;
    _run = 0;
  }
}

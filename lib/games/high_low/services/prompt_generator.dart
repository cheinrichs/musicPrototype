import 'dart:math';
import '../../../models/concept_tier.dart';
import '../../../models/pitch_direction.dart';
import '../models/high_low_instrument.dart';
import '../models/high_low_prompt.dart';

/// One available (instrument, real MIDI pitch) combination a prompt's
/// notes can be drawn from — see [PromptGenerator]'s pool-based picking.
typedef _Note = ({HighLowInstrument instrument, int midi});

/// How many distinct cross-instrument pairs [PromptGenerator] will try
/// before giving up on finding one that can actually produce a valid
/// three-note combination that uses both instruments — see
/// [PromptGenerator._generateVaryingInstrumentPrompt]. Generous: there are
/// at most a few dozen legal pairs total, and this only exists as a
/// backstop against guitar/tuba-style declared-range gaps occasionally
/// invalidating an otherwise-legal pair, not because failure is expected
/// in the common case.
const _maxPairAttempts = 50;

/// Generates prompts (note sets) for the High/Low game, sized by
/// [ConceptTier] (Trello card 95, rebuilt to eight tiers by Trello card
/// "Rebuild the tier ladder as eight tiers (2x2x2)" — see
/// `docs/product/HIGH_LOW_TIERS.md`, the authoritative spec) rather than a
/// raw difficulty number — see [ConceptTier] for what each tier controls.
class PromptGenerator {
  final Random _random;

  PromptGenerator({Random? random}) : _random = random ?? Random();

  /// Generate a full session's worth of prompts. [targetDirections] must
  /// have length [count] — one target direction per round, typically from
  /// [RoundSequencer].
  List<HighLowPrompt> generatePrompts({
    required int count,
    required ConceptTier tier,
    required List<PitchDirection> targetDirections,
  }) {
    assert(targetDirections.length == count);
    return List.generate(
      count,
      (index) => generatePrompt(
        promptNumber: index + 1,
        tier: tier,
        targetDirection: targetDirections[index],
      ),
    );
  }

  /// Generate a single prompt for the given [tier] — [tier.instrumentsVary]
  /// picks same- vs. cross-instrument, [tier.noteCount] picks two vs.
  /// three notes; both are handled by the same pool-based picker below,
  /// just with a different note pool and a different [_pickNoteSet] count.
  HighLowPrompt generatePrompt({
    required int promptNumber,
    required ConceptTier tier,
    required PitchDirection targetDirection,
  }) {
    return tier.instrumentsVary
        ? _generateVaryingInstrumentPrompt(promptNumber, tier, targetDirection)
        : _generateSameInstrumentPrompt(promptNumber, tier, targetDirection);
  }

  /// Both sides of a same-instrument round share one instrument (Cooper:
  /// "i don't think we'll be pitting different instruments against each
  /// other ever and comparing pitch" — true for `instrumentsVary: false`
  /// tiers specifically; see [_generateVaryingInstrumentPrompt] for the
  /// tiers where it isn't) — timbre varies *between* rounds instead, by
  /// this pick happening fresh per prompt.
  ///
  /// Only instruments with enough real range for *this tier's* minimum
  /// interval are eligible — not every instrument qualifies for every
  /// tier (HighLowInstrument.hasRangeFor's doc comment has the full
  /// story: tuba's speaker-audibility range cut left it too narrow for
  /// every tier now that the narrowest band is 4 semitones, not 2). This
  /// used to silently cap the requested interval down to whatever an
  /// instrument's own span allowed instead of excluding it, which is
  /// exactly how a real T1 round ended up pairing two tuba notes barely a
  /// fifth apart that a phone speaker (and a child) couldn't tell apart —
  /// the tier promised 7+ semitones, the code quietly gave 7 anyway since
  /// that's what fit, but tuba's *audibility* problem meant even a
  /// technically-correct interval wasn't usable. Excluding the instrument
  /// outright, rather than degrading the interval, is the fix.
  HighLowPrompt _generateSameInstrumentPrompt(
    int promptNumber,
    ConceptTier tier,
    PitchDirection targetDirection,
  ) {
    // hasRangeFor(minSemitones) alone is only a single-gap check — enough
    // for a two-note tier, but not sufficient for a three-note one: it
    // takes *two* chained gaps to fit three notes, so an instrument can
    // clear the single-gap floor and still be too narrow for three (bells'
    // 12-semitone C6-C7 range clears T5's own 7-semitone floor, but can't
    // fit two chained 7-12 gaps — 7+7=14 already exceeds it). Actually
    // building each candidate's note set (rather than trusting the cheap
    // heuristic) is what makes this correct for both note counts —
    // [hasRangeFor] here is just a fast pre-filter before the real check.
    final eligible = <(HighLowInstrument, List<_Note>)>[
      for (final i in HighLowInstrument.values)
        if (i.hasRangeFor(tier.minSemitones))
          if (_pickNoteSet(
                [
                  for (final midi in i.availableMidis)
                    (instrument: i, midi: midi),
                ],
                count: tier.noteCount,
                tier: tier,
              )
              case final notes?)
            (i, notes),
    ];
    assert(
      eligible.isNotEmpty,
      'No HighLowInstrument can produce a valid $tier note set alone — '
      'check HighLowInstrument ranges.',
    );
    final (_, notes) = eligible[_random.nextInt(eligible.length)];
    return _buildPrompt(promptNumber, targetDirection, notes);
  }

  /// Cross-instrument round (Trello — "Cross-instrument rounds: per-
  /// instrument ranges and the overlap rule", `docs/product/
  /// HIGH_LOW_TIERS.md`). Picks a pair of distinct instruments whose
  /// declared ranges overlap by at least [ConceptTier.minSemitones] (see
  /// [HighLowInstrument.canPairWith] — that overlap is exactly enough
  /// room for either instrument to end up the higher one, so which
  /// instrument played never gives away the answer), then draws
  /// [ConceptTier.noteCount] notes from the *union* of both instruments'
  /// real available notes, requiring at least one note from each — a
  /// combined pool that happened to only draw from one instrument would
  /// silently produce a same-instrument-sounding round on a tier whose
  /// whole point (from T3 on) is teaching the child to listen past
  /// timbre.
  ///
  /// [canPairWith] checks the coarse declared span, not
  /// [HighLowInstrument.availableMidis] (documented there as "fine for
  /// now... guitar's two holes are single semitones, not enough to matter
  /// for a range-overlap estimate") — [_maxPairAttempts] retries with a
  /// different pair on the rare chance a specific pair's real available
  /// notes (gaps and all) can't actually produce a valid combination, so
  /// that documented approximation can't turn into a generation failure.
  HighLowPrompt _generateVaryingInstrumentPrompt(
    int promptNumber,
    ConceptTier tier,
    PitchDirection targetDirection,
  ) {
    final eligiblePairs = <(HighLowInstrument, HighLowInstrument)>[
      for (final a in HighLowInstrument.values)
        for (final b in HighLowInstrument.values)
          if (a.index < b.index &&
              a.canPairWith(b, minSemitones: tier.minSemitones))
            (a, b),
    ];
    assert(
      eligiblePairs.isNotEmpty,
      'No pair of HighLowInstruments overlaps by ${tier.minSemitones}+ '
      'semitones for $tier — check HighLowInstrument ranges.',
    );

    for (var attempt = 0; attempt < _maxPairAttempts; attempt++) {
      final (a, b) = eligiblePairs[_random.nextInt(eligiblePairs.length)];
      final pool = [
        for (final midi in a.availableMidis) (instrument: a, midi: midi),
        for (final midi in b.availableMidis) (instrument: b, midi: midi),
      ];
      final notes = _pickNoteSet(
        pool,
        count: tier.noteCount,
        tier: tier,
        requireBothOf: {a, b},
      );
      if (notes != null) {
        return _buildPrompt(promptNumber, targetDirection, notes);
      }
    }
    throw StateError(
      'Could not find a valid cross-instrument note set for $tier after '
      '$_maxPairAttempts attempts — check HighLowInstrument ranges/gaps.',
    );
  }

  /// Picks [count] (2 or 3) notes from [pool] with no repeated pitch, such
  /// that every *adjacent* gap in sorted pitch order falls within
  /// [tier]'s [ConceptTier.minSemitones]..[ConceptTier.maxSemitones] —
  /// the direct three-note generalization of the original two-note
  /// "enumerate every valid pair" approach (cheap: even a combined
  /// cross-instrument pool is at most ~50 notes, so enumerating every
  /// 2- or 3-element combination is trivially fast). If [requireBothOf]
  /// is given, only combinations using at least one note from each of
  /// those instruments qualify (see
  /// [_generateVaryingInstrumentPrompt] for why) — and `null` is returned
  /// (rather than throwing) when no such combination exists, so the
  /// caller can retry with a different instrument pair.
  ///
  /// The chosen notes are then shuffled into first/second(/third)
  /// position — a fixed assignment (e.g. always placing the lower note
  /// first) would let the child learn position instead of pitch, exactly
  /// the failure mode the original two-note coin flip already guarded
  /// against.
  List<_Note>? _pickNoteSet(
    List<_Note> pool, {
    required int count,
    required ConceptTier tier,
    Set<HighLowInstrument>? requireBothOf,
  }) {
    final byMidi = <int, _Note>{for (final note in pool) note.midi: note};
    final midis = byMidi.keys.toList()..sort();

    final combinations = count == 2
        ? _pairs(midis)
        : _triples(midis, tier.minSemitones, tier.maxSemitones);

    final valid = <List<int>>[
      for (final combo in combinations)
        if (_gapsInBounds(combo, tier.minSemitones, tier.maxSemitones) &&
            (requireBothOf == null ||
                requireBothOf.every(
                  (i) => combo.any((m) => byMidi[m]!.instrument == i),
                )))
          combo,
    ];
    if (valid.isEmpty) return null;

    final chosen =
        valid[_random.nextInt(valid.length)]
            .map((midi) => byMidi[midi]!)
            .toList()
          ..shuffle(_random);
    return chosen;
  }

  /// Every 2-element ascending combination of [midis] — the two-note
  /// case doesn't need [minSemitones]/[maxSemitones] pre-filtering here
  /// since [_gapsInBounds] checks the single gap directly.
  Iterable<List<int>> _pairs(List<int> midis) sync* {
    for (var i = 0; i < midis.length; i++) {
      for (var j = i + 1; j < midis.length; j++) {
        yield [midis[i], midis[j]];
      }
    }
  }

  /// Every 3-element ascending combination of [midis] whose two adjacent
  /// gaps could plausibly both fit [minSemitones]..[maxSemitones] —
  /// pruned during generation (not just filtered after) since an
  /// unpruned combined cross-instrument pool's full C(n,3) can run into
  /// the tens of thousands.
  Iterable<List<int>> _triples(
    List<int> midis,
    int minSemitones,
    int maxSemitones,
  ) sync* {
    for (var i = 0; i < midis.length; i++) {
      for (var j = i + 1; j < midis.length; j++) {
        final firstGap = midis[j] - midis[i];
        if (firstGap < minSemitones || firstGap > maxSemitones) continue;
        for (var k = j + 1; k < midis.length; k++) {
          yield [midis[i], midis[j], midis[k]];
        }
      }
    }
  }

  bool _gapsInBounds(
    List<int> sortedCombo,
    int minSemitones,
    int maxSemitones,
  ) {
    for (var i = 1; i < sortedCombo.length; i++) {
      final gap = sortedCombo[i] - sortedCombo[i - 1];
      if (gap < minSemitones || gap > maxSemitones) return false;
    }
    return true;
  }

  HighLowPrompt _buildPrompt(
    int promptNumber,
    PitchDirection targetDirection,
    List<_Note> notes,
  ) {
    return HighLowPrompt(
      firstMidi: notes[0].midi,
      secondMidi: notes[1].midi,
      firstInstrument: notes[0].instrument,
      secondInstrument: notes[1].instrument,
      thirdMidi: notes.length > 2 ? notes[2].midi : null,
      thirdInstrument: notes.length > 2 ? notes[2].instrument : null,
      promptNumber: promptNumber,
      targetDirection: targetDirection,
    );
  }
}

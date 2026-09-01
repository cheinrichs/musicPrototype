import 'dart:math';
import '../../../models/pitch_direction.dart';
import '../../../models/round_order.dart';

/// Produces the per-round target direction (ask for the high one, or the
/// low one?) for a session, according to a [RoundOrder] (Trello card 95).
/// This is deliberately separate from [PromptGenerator] — sequencing is a
/// property of the *session*, not of any one round's stimulus.
class RoundSequencer {
  final Random _random;

  RoundSequencer({Random? random}) : _random = random ?? Random();

  List<PitchDirection> sequence({
    required int count,
    required RoundOrder order,
  }) {
    // Too few rounds to form three meaningful blocks — fall back to mixed
    // rather than producing a degenerate/empty block.
    if (order == RoundOrder.mixed || count < 3) {
      return List.generate(count, (_) => _randomDirection());
    }

    // Blocked: all "high", then all "low", then a final interleaved block,
    // so the child meets each direction on its own before switching
    // between them without warning.
    final segment = count ~/ 3;
    final directions = <PitchDirection>[
      ...List.filled(segment, PitchDirection.higher),
      ...List.filled(segment, PitchDirection.lower),
    ];
    final remaining = count - directions.length;
    directions.addAll(List.generate(remaining, (_) => _randomDirection()));
    return directions;
  }

  PitchDirection _randomDirection() =>
      _random.nextBool() ? PitchDirection.higher : PitchDirection.lower;
}

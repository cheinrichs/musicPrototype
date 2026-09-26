import '../models/high_low_instrument.dart';
import '../models/high_low_prompt.dart';

/// One instrument playing one real pitch.
typedef OrderingNote = ({HighLowInstrument instrument, int midi});

/// How many platforms the ordering tree offers to drop instruments on —
/// the three below Clef, who occupies the top one and marks the high end.
const orderingSlotCount = 3;

/// The answer key for one A4 ordering round: which platform each
/// instrument belongs on, highest pitch on the top platform (nearest Clef)
/// down to the lowest at the bottom.
///
/// [notes] are in the order they play and sit on their stumps — that order
/// carries no meaning for the answer, so a child can't win by position.
class OrderingRound {
  final List<OrderingNote> notes;

  OrderingRound(this.notes)
    : assert(
        notes.length >= 2 && notes.length <= orderingSlotCount,
        'ordering needs 2 or 3 notes, got ${notes.length}',
      ),
      assert(
        notes.map((n) => n.midi).toSet().length == notes.length,
        'two notes share a pitch, so their order is undefined',
      );

  factory OrderingRound.fromPrompt(HighLowPrompt prompt) => OrderingRound([
    (instrument: prompt.firstInstrument, midi: prompt.firstMidi),
    (instrument: prompt.secondInstrument, midi: prompt.secondMidi),
    if (prompt.thirdMidi != null)
      (instrument: prompt.thirdInstrument!, midi: prompt.thirdMidi!),
  ]);

  int get slotCount => orderingSlotCount;

  /// The platforms in play this round, top first. A two-note round uses the
  /// top two and leaves the bottom step empty — the same tree with one step
  /// unoccupied (Trello card 11) — so the ordering still reads down from
  /// Clef.
  List<int> get activeSlots => [for (var i = 0; i < notes.length; i++) i];

  /// The platform (0 = top) that note [noteIndex] belongs on.
  int correctSlotOf(int noteIndex) {
    final pitch = notes[noteIndex].midi;
    return notes.where((n) => n.midi > pitch).length;
  }

  /// The notes in [placements] (note index → slot) that are on their
  /// correct platform.
  ///
  /// With every slot filled, the count is never exactly `notes.length - 1`:
  /// if all but one are right, the last has nowhere else to go. So three
  /// notes can only score 3, 1 or 0 — a two-correct state means a bug here.
  Set<int> correctNotes(Map<int, int> placements) => {
    for (final entry in placements.entries)
      if (correctSlotOf(entry.key) == entry.value) entry.key,
  };
}

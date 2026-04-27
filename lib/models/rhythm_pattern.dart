class RhythmPattern {
  final String name;
  final List<int> beatOffsets; // ms from start of pattern

  const RhythmPattern({required this.name, required this.beatOffsets});

  static const List<RhythmPattern> pool = [
    RhythmPattern(name: 'steady', beatOffsets: [0, 500, 1000, 1500]),
    RhythmPattern(name: 'fast_fast_slow', beatOffsets: [0, 250, 500, 1200]),
    RhythmPattern(name: 'slow_quick', beatOffsets: [0, 700, 1000, 1300]),
    RhythmPattern(name: 'dotted', beatOffsets: [0, 750, 1000, 1750]),
    RhythmPattern(name: 'skip', beatOffsets: [0, 400, 600, 1000]),
    RhythmPattern(name: 'sparse', beatOffsets: [0, 600, 1400, 2000]),
  ];
}

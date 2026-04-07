/// Types of musical intervals for ear training
/// Starting with a kid-friendly set of 4 easily distinguishable intervals
enum IntervalType {
  minorThird, // 3 semitones - "Greensleeves" start
  majorThird, // 4 semitones - "Kumbaya" start
  perfectFifth, // 7 semitones - "Star Wars" theme
  octave, // 12 semitones - "Somewhere Over the Rainbow"
}

extension IntervalTypeExtension on IntervalType {
  /// Number of semitones in this interval
  int get semitones {
    switch (this) {
      case IntervalType.minorThird:
        return 3;
      case IntervalType.majorThird:
        return 4;
      case IntervalType.perfectFifth:
        return 7;
      case IntervalType.octave:
        return 12;
    }
  }

  /// Short label for display (e.g., "m3", "M3")
  String get shortLabel {
    switch (this) {
      case IntervalType.minorThird:
        return 'm3';
      case IntervalType.majorThird:
        return 'M3';
      case IntervalType.perfectFifth:
        return 'P5';
      case IntervalType.octave:
        return 'Oct';
    }
  }

  /// Full display name
  String get displayName {
    switch (this) {
      case IntervalType.minorThird:
        return 'Minor 3rd';
      case IntervalType.majorThird:
        return 'Major 3rd';
      case IntervalType.perfectFifth:
        return 'Perfect 5th';
      case IntervalType.octave:
        return 'Octave';
    }
  }
}

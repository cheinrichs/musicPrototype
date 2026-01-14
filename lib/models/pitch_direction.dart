/// Represents the direction of pitch change between two notes
enum PitchDirection { higher, lower }

extension PitchDirectionExtension on PitchDirection {
  /// Display label for the direction
  String get label {
    switch (this) {
      case PitchDirection.higher:
        return 'Higher';
      case PitchDirection.lower:
        return 'Lower';
    }
  }

  /// Icon representation (arrow direction)
  String get icon {
    switch (this) {
      case PitchDirection.higher:
        return '↑';
      case PitchDirection.lower:
        return '↓';
    }
  }
}

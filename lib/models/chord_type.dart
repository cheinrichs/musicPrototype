/// Types of chords for ear training
/// Starting simple with just major and minor for kids
enum ChordType {
  major, // Happy sound - root, major 3rd, perfect 5th
  minor, // Sad sound - root, minor 3rd, perfect 5th
}

extension ChordTypeExtension on ChordType {
  /// Display label for this chord type
  String get label {
    switch (this) {
      case ChordType.major:
        return 'Major';
      case ChordType.minor:
        return 'Minor';
    }
  }

  /// Kid-friendly description
  String get description {
    switch (this) {
      case ChordType.major:
        return 'Happy';
      case ChordType.minor:
        return 'Sad';
    }
  }

  /// Intervals from root in semitones for this chord type
  /// Returns [third, fifth] intervals
  List<int> get intervals {
    switch (this) {
      case ChordType.major:
        return [4, 7]; // major 3rd, perfect 5th
      case ChordType.minor:
        return [3, 7]; // minor 3rd, perfect 5th
    }
  }
}

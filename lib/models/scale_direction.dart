/// Represents the direction of a musical scale
enum ScaleDirection { ascending, descending }

extension ScaleDirectionExtension on ScaleDirection {
  /// Display label for the direction
  String get label {
    switch (this) {
      case ScaleDirection.ascending:
        return 'Up';
      case ScaleDirection.descending:
        return 'Down';
    }
  }

  /// Icon representation (arrow direction)
  String get icon {
    switch (this) {
      case ScaleDirection.ascending:
        return '↑';
      case ScaleDirection.descending:
        return '↓';
    }
  }
}

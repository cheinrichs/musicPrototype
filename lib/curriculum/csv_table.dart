/// Reads the curriculum's CSV files (Trello card 219): exported from the
/// retired spreadsheet, now edited in the repo. Small on purpose — quoted
/// fields with commas, doubled quotes, newlines inside quotes, CRLF, and the
/// byte-order mark Sheets puts on the first header.
///
/// Returns one map per row, keyed by the header row. Blank lines are skipped.
List<Map<String, String>> parseCsvTable(String source) {
  final rows = _parseRows(source.replaceFirst('﻿', ''));
  if (rows.isEmpty) return const [];
  final header = rows.first.map((h) => h.trim()).toList();
  return [
    for (final row in rows.skip(1))
      if (row.any((cell) => cell.trim().isNotEmpty))
        {
          for (var i = 0; i < header.length; i++)
            header[i]: i < row.length ? row[i].trim() : '',
        },
  ];
}

List<List<String>> _parseRows(String s) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < s.length && s[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

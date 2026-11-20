import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ear_trainer/games/high_low/models/instrument_sheets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cooper's multi-variant sheets are cut where the manifest says, never in
/// equal parts: equal thirds cut through the art on 8 of 14 sheets
/// (2026-11-20). This re-measures everything from the PNGs.
///
/// THE POST-SLICE ASSERTION, for every sheet in the manifest that is in the
/// repo (instruments, characters, Matching Grove cards): no OPAQUE pixel
/// (alpha >= 128) on a cut, and none touching the left or right edge of its
/// variant's crop. A faint glow may cross a cut (the drum cards' shadow
/// runs the full height at alpha <= 33); solid art may not.
const _opaque = 128;
const _faint = 8;
const _manifestPath = 'assets/images/characters/instruments/SLICE_POINTS.json';

/// Where each manifest entry lives in this repo.
String? _repoPath(String key) {
  final name = key.split('/').last;
  for (final dir in [
    'assets/images/characters/instruments',
    'assets/images/journey',
    'assets/images/characters',
  ]) {
    if (File('$dir/$name').existsSync()) return '$dir/$name';
  }
  return null;
}

class _Alpha {
  final int width, height;
  final ByteData px;
  _Alpha(this.width, this.height, this.px);
  int at(int x, int y) => px.getUint8((y * width + x) * 4 + 3);
}

Future<_Alpha> _load(String path) async {
  final codec = await ui.instantiateImageCodec(
    Uint8List.fromList(File(path).readAsBytesSync()),
  );
  final image = (await codec.getNextFrame()).image;
  return _Alpha(image.width, image.height, (await image.toByteData())!);
}

void main() {
  final manifest =
      jsonDecode(File(_manifestPath).readAsStringSync())
          as Map<String, dynamic>;
  final sheets = {
    for (final e in manifest.entries)
      if (!e.key.startsWith('_')) e.key: e.value as Map<String, dynamic>,
  };

  test('every instrument sheet in the app is cut where the manifest says', () {
    for (final s in instrumentSheets.values) {
      final key = sheets.keys.firstWhere(
        (k) => k.split('/').last == s.asset.split('/').last,
      );
      expect(s.cuts, sheets[key]!['slices'], reason: s.asset);
      expect(s.width, sheets[key]!['width'], reason: s.asset);
      expect(s.boxes, hasLength(3), reason: s.asset);
    }
  });

  for (final MapEntry(key: key, value: entry) in sheets.entries) {
    final path = _repoPath(key);
    if (path == null) continue; // not in the app (yet)
    test('$key: no opaque art on a cut or at a crop edge', () async {
      final a = await _load(path);
      expect(a.width, entry['width']);
      final cuts = [0, ...(entry['slices'] as List).cast<int>(), a.width];
      for (var i = 0; i + 1 < cuts.length; i++) {
        for (final x in {cuts[i], cuts[i + 1] - 1}) {
          for (var y = 0; y < a.height; y++) {
            expect(
              a.at(x, y) < _opaque,
              isTrue,
              reason: '$key variant $i: opaque art at its edge ($x, $y)',
            );
          }
        }
      }
    });
  }

  for (final MapEntry(key: name, value: s) in instrumentSheets.entries) {
    test('$name: every variant box is its art, measured, inside its '
        'column', () async {
      final a = await _load(s.asset);
      expect((a.width, a.height), (s.width, s.height));
      final cuts = [0, ...s.cuts, s.width];
      for (var i = 0; i < 3; i++) {
        var (l, t, r, b) = (s.width, s.height, -1, -1);
        for (var y = 0; y < a.height; y++) {
          for (var x = cuts[i]; x < cuts[i + 1]; x++) {
            if (a.at(x, y) <= _faint) continue;
            if (x < l) l = x;
            if (x > r) r = x;
            if (y < t) t = y;
            if (y > b) b = y;
          }
        }
        expect(s.boxes[i], (l, t, r - l + 1, b - t + 1), reason: '$name $i');
        expect(l, greaterThanOrEqualTo(cuts[i]));
        expect(r, lessThan(cuts[i + 1]));
      }
    });
  }
}

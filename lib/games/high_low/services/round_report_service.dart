import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/round_report.dart';

/// Captures a [RoundReport] plus a screenshot of the current view, writes
/// both to a local temp dir, and hands them to the OS share sheet —
/// "Report this round" (Trello card on0EymSu). Deliberately no network
/// call anywhere in here: this is a children's app, and the whole point is
/// that round data never leaves the device except through the share sheet
/// a grown-up explicitly drives (to Dispatch, Mail, AirDrop, wherever).
class RoundReportService {
  RoundReportService._();

  /// Renders [boundaryKey]'s subtree to a PNG, writes it alongside
  /// [report]'s JSON into the app's temp directory, and opens the share
  /// sheet with both files. Returns false (and shares nothing) if the
  /// boundary isn't currently attached to a render object — the caller is
  /// responsible for only invoking this while the game screen is mounted.
  ///
  /// [sharePositionOrigin] should be the on-screen rect of whatever control
  /// triggered this (the report button) — required on iPad/Mac Catalyst:
  /// `share_plus`'s iOS implementation presents the share sheet as a
  /// popover there, and without a source rect to anchor it, the native
  /// side returns an error instead of showing anything at all (Cooper's
  /// "nothing appears to happen" report). Harmless to pass on iPhone,
  /// where it has no effect either way.
  static Future<bool> shareReport({
    required RoundReport report,
    required GlobalKey boundaryKey,
    ui.Rect? sharePositionOrigin,
  }) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return false;

    final pngBytes = await _capturePng(boundary);
    final dir = await getTemporaryDirectory();
    final stamp = report.capturedAt.millisecondsSinceEpoch;

    final jsonFile = File('${dir.path}/round_report_$stamp.json');
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );

    final pngFile = File('${dir.path}/round_report_$stamp.png');
    await pngFile.writeAsBytes(pngBytes);

    await Share.shareXFiles(
      [XFile(jsonFile.path), XFile(pngFile.path)],
      text: 'High/Low round report (round ${report.roundNumber})',
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  static Future<Uint8List> _capturePng(RenderRepaintBoundary boundary) async {
    // devicePixelRatio-scaled: a 1x capture of a phone screen reads as
    // blurry once Cooper actually looks at it zoomed in on a report.
    // Timeout is a defensive backstop, not a known failure mode: a stuck
    // `toImage()` would otherwise hang this whole flow with an `await` that
    // never resolves and no exception for the caller to catch or show.
    final image = await boundary
        .toImage(pixelRatio: 2.0)
        .timeout(const Duration(seconds: 5));
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

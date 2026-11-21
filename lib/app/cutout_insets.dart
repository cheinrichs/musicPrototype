import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Which way the interface is turned, as the WINDOW SCENE reports it
/// (Trello 226). Not the device's physical attitude (`UIDevice`), which
/// includes face-up and face-down and can disagree with how the interface
/// is actually laid out, e.g. with rotation lock on.
enum InterfaceOrientation { unknown, portrait, landscapeLeft, landscapeRight }

/// WHY THIS EXISTS (Trello 226): in landscape, iOS reports the Dynamic
/// Island's inset on BOTH side edges, by design (measured on an iPhone 17:
/// left 62, top 0, right 62, bottom 20, with the island on the left only).
/// So `MediaQuery.padding` can say a side cutout exists but never which
/// side, and the side without one got a 62 pt dead margin against nothing.
/// The side comes from the interface orientation, since the cutout turns
/// with the device:
///
/// - `landscapeRight`: the home button side is on the right, so the top of
///   the phone, with the island, is on the LEFT.
/// - `landscapeLeft`: the island is on the RIGHT.
///
/// ⚠️ When the orientation is unknown (launching, or not iOS), the
/// symmetric inset is kept. A wrong guess looks worse than the old buffer.
///
/// ⚠️ WHO RESPECTS THE INSET (Cooper, 2026-11-21). INTERACTIVE CHROME does:
/// the rail, buttons, anything a child must read or tap. DECORATIVE
/// CHARACTERS do not, and may bleed under the island: Piper stands at the
/// true left edge (`SceneLayout.piperLeftInset`, `LoudQuietLayout`), and
/// A0's big Clef is held only to the screen (`SceneLayout.observeClefHeight`).
/// Both are deliberate. A sweep must not move them back inside the inset.
class CutoutInsets {
  CutoutInsets._();

  /// What the side WITHOUT the cutout keeps: clearance for the screen's
  /// rounded corner, not the island's 62 pt.
  static const double cornerMargin = 16;

  /// [padding] with the cutout's inset kept on the island's side only.
  /// Unchanged unless the side insets are equal and non-zero (a cutout
  /// reported on both sides) and the orientation says which side it is.
  static EdgeInsets correct(EdgeInsets padding, InterfaceOrientation o) {
    if (padding.left <= 0 || padding.left != padding.right) return padding;
    final trimmed = padding.left < cornerMargin ? padding.left : cornerMargin;
    return switch (o) {
      InterfaceOrientation.landscapeRight => padding.copyWith(right: trimmed),
      InterfaceOrientation.landscapeLeft => padding.copyWith(left: trimmed),
      _ => padding,
    };
  }
}

/// The current [InterfaceOrientation], read over a method channel handled
/// in ios/Runner/AppDelegate.swift, and updated when the interface turns.
class InterfaceOrientationSource extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel(
    'ear_trainer/interface_orientation',
  );

  InterfaceOrientation _value = InterfaceOrientation.unknown;
  InterfaceOrientation get value => _value;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Starts listening. Anywhere but iOS (and in widget tests) it stays
  /// [InterfaceOrientation.unknown], so nothing changes.
  void start() {
    if (!_isIOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') _set(_parse(call.arguments));
    });
    unawaited(refresh());
  }

  /// Asks for the orientation now (on start, and when the app resumes).
  Future<void> refresh() async {
    if (!_isIOS) return;
    try {
      _set(_parse(await _channel.invokeMethod<String>('current')));
    } on PlatformException catch (e) {
      debugPrint('Interface orientation unavailable: ${e.message}');
    } on MissingPluginException {
      // No handler (an older native build): stay unknown, symmetric.
    }
  }

  void _set(InterfaceOrientation o) {
    if (o == _value) return;
    _value = o;
    notifyListeners();
  }

  static InterfaceOrientation _parse(Object? raw) => switch (raw) {
    'landscapeLeft' => InterfaceOrientation.landscapeLeft,
    'landscapeRight' => InterfaceOrientation.landscapeRight,
    'portrait' || 'portraitUpsideDown' => InterfaceOrientation.portrait,
    _ => InterfaceOrientation.unknown,
  };
}

/// Rewrites the app's safe-area insets so every edge-anchored element
/// insets only the side that actually has the cutout. Placed once, at the
/// root, so every `MediaQuery.paddingOf` and every `SafeArea` below gets
/// the corrected value without each having to know about this.
///
/// ⚠️ THE PANEL PAINTS TO THE EDGE, THE CONTENT IS INSET. This changes only
/// the inset content is positioned by; backgrounds and panels still paint
/// under the unsafe region, as before.
class CutoutMediaQuery extends StatefulWidget {
  final Widget child;
  final InterfaceOrientationSource? source;
  const CutoutMediaQuery({super.key, required this.child, this.source});

  @override
  State<CutoutMediaQuery> createState() => _CutoutMediaQueryState();
}

class _CutoutMediaQueryState extends State<CutoutMediaQuery>
    with WidgetsBindingObserver {
  late final InterfaceOrientationSource _source =
      widget.source ?? (InterfaceOrientationSource()..start());

  @override
  void initState() {
    super.initState();
    _source.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
  }

  void _changed() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_source.refresh());
  }

  @override
  void didChangeMetrics() => unawaited(_source.refresh());

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _source.removeListener(_changed);
    if (widget.source == null) _source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final o = _source.value;
    return MediaQuery(
      data: mq.copyWith(
        padding: CutoutInsets.correct(mq.padding, o),
        viewPadding: CutoutInsets.correct(mq.viewPadding, o),
      ),
      child: widget.child,
    );
  }
}

import 'package:ear_trainer/app/cutout_insets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Trello 226: iOS reports a landscape cutout on BOTH sides; only the
/// interface orientation says which side it is really on.
void main() {
  // Measured on an iPhone 17 in landscape, island on the left only.
  const iphone17 = EdgeInsets.fromLTRB(62, 0, 62, 20);

  test('landscapeRight: the island is on the LEFT, so the right side drops '
      'to a corner margin', () {
    expect(
      CutoutInsets.correct(iphone17, InterfaceOrientation.landscapeRight),
      const EdgeInsets.fromLTRB(62, 0, CutoutInsets.cornerMargin, 20),
    );
  });

  test('landscapeLeft: the island is on the RIGHT', () {
    expect(
      CutoutInsets.correct(iphone17, InterfaceOrientation.landscapeLeft),
      const EdgeInsets.fromLTRB(CutoutInsets.cornerMargin, 0, 62, 20),
    );
  });

  test('UNKNOWN (launching, not iOS): the symmetric inset is kept — a wrong '
      'guess looks worse than the buffer', () {
    for (final o in [
      InterfaceOrientation.unknown,
      InterfaceOrientation.portrait,
    ]) {
      expect(CutoutInsets.correct(iphone17, o), iphone17, reason: o.name);
    }
  });

  test('no cutout (an SE, an iPad) or unequal sides: unchanged', () {
    const none = EdgeInsets.only(bottom: 20);
    const uneven = EdgeInsets.fromLTRB(40, 0, 10, 0);
    for (final o in InterfaceOrientation.values) {
      expect(CutoutInsets.correct(none, o), none);
      expect(CutoutInsets.correct(uneven, o), uneven);
    }
  });

  test('a side inset smaller than the corner margin is never enlarged', () {
    const small = EdgeInsets.symmetric(horizontal: 8);
    expect(
      CutoutInsets.correct(small, InterfaceOrientation.landscapeRight),
      small,
    );
  });

  testWidgets('placed at the root, every MediaQuery below sees the corrected '
      'padding', (tester) async {
    final source = _FakeSource();
    EdgeInsets? seen;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(874, 402),
          padding: iphone17,
          viewPadding: iphone17,
        ),
        child: CutoutMediaQuery(
          source: source,
          child: Builder(
            builder: (context) {
              seen = MediaQuery.paddingOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(seen, iphone17, reason: 'unknown at launch: symmetric');
    source.set(InterfaceOrientation.landscapeRight);
    await tester.pump();
    expect(seen!.right, CutoutInsets.cornerMargin);
    expect(seen!.left, 62);
    source.set(InterfaceOrientation.landscapeLeft);
    await tester.pump();
    expect(seen!.left, CutoutInsets.cornerMargin);
    expect(seen!.right, 62);
  });
}

class _FakeSource extends InterfaceOrientationSource {
  InterfaceOrientation _v = InterfaceOrientation.unknown;
  @override
  InterfaceOrientation get value => _v;
  void set(InterfaceOrientation o) {
    _v = o;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {}
}

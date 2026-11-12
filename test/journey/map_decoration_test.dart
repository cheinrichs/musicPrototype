import 'package:ear_trainer/app/art_registry.dart';
import 'package:ear_trainer/audio/sound_registry.dart';
import 'package:ear_trainer/journey/map_decoration.dart';
import 'package:ear_trainer/journey/reward_catalogue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _creatures = {
  'frog',
  'chipmunk',
  'bluebird',
  'ladybird',
  'snail',
  'butterfly',
  'dragonfly',
};

void main() {
  test(
    'every decoration a milestone can give has a motion and both frames',
    () {
      for (final artId in rewardTypeOf('decoration').items) {
        final name = MapDecoration.nameOf(artId);
        expect(decorationMotions.containsKey(name), isTrue, reason: name);
        expect(Art.has('decoration.$name.rest'), isTrue, reason: name);
        expect(Art.has('decoration.$name.hit'), isTrue, reason: name);
      }
    },
  );

  test('creatures get behaviours and are never mirrored; objects get '
      'physical reactions', () {
    for (final MapEntry(key: name, value: motion)
        in decorationMotions.entries) {
      final physical = {
        DecorationMotion.tiltWobble,
        DecorationMotion.squash,
        DecorationMotion.rotateWobble,
      }.contains(motion);
      expect(physical, !_creatures.contains(name), reason: name);
    }
  });

  test('pokes are silent until their non-pitched sounds are recorded', () {
    expect(Sounds.pathOf(decorationSoundId('frog')), isNull);
  });

  Future<void> mount(WidgetTester tester, List<String> names) =>
      tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              for (final n in names)
                MapDecoration(key: ValueKey(n), name: n, size: 80),
            ],
          ),
        ),
      );

  // STANDING_RULES.md: correct when tapped as fast as a child can tap.
  testWidgets('tapped far faster than its reaction: it restarts rather than '
      'stacking, and returns to rest', (tester) async {
    await mount(tester, ['frog']);
    for (var i = 0; i < 30; i++) {
      await tester.tap(find.byKey(const ValueKey('frog')));
      await tester.pump(const Duration(milliseconds: 10));
      expect(MapDecoration.reactingCount, 1);
    }
    await tester.pump(const Duration(seconds: 2));
    expect(MapDecoration.reactingCount, 0);
    final art = tester.widget<ArtImage>(find.byType(ArtImage));
    expect(art.id, 'decoration.frog.rest', reason: 'never latched');
  });

  testWidgets('at most ${MapDecoration.maxReacting} react at once; a new one '
      'stops the oldest', (tester) async {
    final names = ['acorn', 'frog', 'snail', 'daisy', 'pine_cone', 'mushroom'];
    await mount(tester, names);
    for (final n in names) {
      await tester.tap(find.byKey(ValueKey(n)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(MapDecoration.reactingCount, MapDecoration.maxReacting);
    await tester.pump(const Duration(seconds: 2));
    expect(MapDecoration.reactingCount, 0);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/games/loud_quiet/models/loud_quiet_layout.dart';
import 'package:ear_trainer/games/loud_quiet/models/loud_quiet_round.dart';
import 'package:ear_trainer/games/loud_quiet/widgets/dial_needle.dart';

/// The needle's complete gesture (Trello card 208): swing out, wobble on
/// arrival, home to rest at the quiet end as the sound ends.
void main() {
  const rest = LoudQuietLayout.restDegrees;
  final loud = LoudQuietLayout.needleDegrees(1);
  final quiet = LoudQuietLayout.needleDegrees(
    LoudQuietRound.needlePosition(LoudQuietRound.wideQuietGain),
  );
  const length = Duration(milliseconds: 1700);

  double at(int ms, {double start = rest, double? target, Duration? of}) =>
      DialNeedle.angleAt(
        start: start,
        target: target ?? loud,
        elapsed: Duration(milliseconds: ms),
        length: of ?? length,
      );

  test('rest is out at the quiet end, below the quietest sound; loud is the '
      'longest throw', () {
    expect(rest, lessThan(quiet));
    expect(quiet - rest, lessThan(loud - rest));
  });

  test('each sound lands in its zone of the face — measured on the renders, '
      'the zone boundaries sit about 30° either side of straight up', () {
    final narrowQuiet = LoudQuietLayout.needleDegrees(
      LoudQuietRound.needlePosition(LoudQuietRound.narrowQuietGain),
    );
    expect(quiet, lessThan(-30 - 10), reason: 'wide quiet: the quiet zone');
    expect(narrowQuiet, inInclusiveRange(-30 + 10, 30 - 10), reason: 'middle');
    expect(loud, greaterThan(30 + 10), reason: 'loud: the loud zone');
  });

  test('starts where it is and reaches the sound\'s level by the end of the '
      'swing', () {
    expect(at(0), rest);
    expect(at(DialNeedle.swingTime.inMilliseconds), closeTo(loud, 0.01));
  });

  test('wobbles on arrival — past the level in the direction it was thrown '
      '— and a longer throw wobbles more', () {
    double peakOvershoot(double target) {
      var most = 0.0;
      for (
        var ms = DialNeedle.swingTime.inMilliseconds;
        ms < (DialNeedle.swingTime + DialNeedle.wobbleTime).inMilliseconds;
        ms += 5
      ) {
        final over = at(ms, target: target) - target;
        if (over > most) most = over;
      }
      return most;
    }

    expect(peakOvershoot(loud), greaterThan(1));
    expect(peakOvershoot(loud), greaterThan(peakOvershoot(quiet) * 2));
  });

  test('holds high, then falls home to rest exactly as the sound ends — never '
      'parked on the level', () {
    final settled =
        (DialNeedle.swingTime + DialNeedle.wobbleTime).inMilliseconds;
    expect(at(settled + 100), greaterThan(loud - 10), reason: 'still high');
    expect(at(length.inMilliseconds), closeTo(rest, 0.01));
    expect(at(length.inMilliseconds + 500), rest);
  });

  test('a sound shorter than the gesture still gets the whole of it', () {
    const short = Duration(milliseconds: 200);
    final total = DialNeedle.totalFor(short);
    expect(total, greaterThan(DialNeedle.swingTime + DialNeedle.wobbleTime));
    expect(at(total.inMilliseconds, of: short), closeTo(rest, 0.01));
  });

  test('a new gesture starts from wherever the needle is, not from rest', () {
    final midway = at(100);
    expect(at(0, start: midway), midway);
  });
}

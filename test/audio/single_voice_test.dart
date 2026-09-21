import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/audio/single_voice.dart';

/// A fake engine: every started voice is a numbered handle, `stopped`
/// records which ones were cut, and each start can be held open with a
/// Completer to reproduce an in-flight `play()`.
class FakeEngine {
  final stopped = <int>[];
  final log = <String>[];
  var _next = 1;

  int newHandle() => _next++;

  void stop(int handle) {
    stopped.add(handle);
    log.add('stop $handle');
  }

  Set<int> alive(Iterable<int> started) =>
      started.where((h) => !stopped.contains(h)).toSet();
}

void main() {
  test('a retap cuts the previous note immediately and starts the new one — '
      'it never waits out the note that is still playing', () async {
    final engine = FakeEngine();
    final voice = SingleVoice<int>(stop: engine.stop);

    final started = <int>[];
    Future<int?> start() async {
      final h = engine.newHandle();
      engine.log.add('play $h');
      started.add(h);
      return h;
    }

    await voice.retrigger(start);
    await voice.retrigger(start);

    expect(
      engine.log,
      ['play 1', 'stop 1', 'play 2'],
      reason: 'the old voice is cut before the new one starts, nothing awaited',
    );
    expect(engine.alive(started), {2});
  });

  test('the old voice is stopped even before the new note has finished '
      'starting (e.g. it is still loading)', () async {
    final engine = FakeEngine();
    final voice = SingleVoice<int>(stop: engine.stop);

    await voice.retrigger(() async => engine.newHandle()); // handle 1

    final slowStart = Completer<int?>();
    final pending = voice.retrigger(() => slowStart.future);

    expect(
      engine.stopped,
      [1],
      reason: 'cut at the tap, not after the new note arrives',
    );
    slowStart.complete(engine.newHandle());
    await pending;
  });

  test('two taps that overlap while the first is still starting leave exactly '
      'one voice — the superseded one is stopped, not orphaned', () async {
    final engine = FakeEngine();
    final voice = SingleVoice<int>(stop: engine.stop);

    final a = Completer<int?>();
    final b = Completer<int?>();
    final first = voice.retrigger(() => a.future);
    final second = voice.retrigger(() => b.future);

    // The engine answers out of order: the second tap's voice first.
    b.complete(engine.newHandle()); // handle 1
    await second;
    a.complete(engine.newHandle()); // handle 2, the superseded tap's
    await first;

    expect(
      engine.alive([1, 2]),
      {1},
      reason: 'only the latest tap keeps sounding; the older one was cut',
    );
  });

  test('spamming the button leaves only the last note alive, whatever order '
      'the engine answers in', () async {
    final engine = FakeEngine();
    final voice = SingleVoice<int>(stop: engine.stop);

    final completers = [for (var i = 0; i < 10; i++) Completer<int?>()];
    final futures = [
      for (final c in completers) voice.retrigger(() => c.future),
    ];

    final handles = <int>[];
    for (final i in [3, 0, 9, 5, 1, 8, 2, 7, 4, 6]) {
      final h = engine.newHandle();
      handles.add(h);
      completers[i].complete(h);
    }
    await Future.wait(futures);

    // completers[9] belongs to the latest tap; its handle is the third
    // one issued above.
    expect(engine.alive(handles), {handles[2]});
  });

  test('stopAll cuts the playing note and cancels one that has not started '
      'yet, so it cannot start after the stop', () async {
    final engine = FakeEngine();
    final voice = SingleVoice<int>(stop: engine.stop);

    await voice.retrigger(() async => engine.newHandle()); // 1
    voice.stopAll();
    expect(engine.stopped, [1]);

    final slow = Completer<int?>();
    final pending = voice.retrigger(() => slow.future);
    voice.stopAll();
    slow.complete(engine.newHandle()); // 2
    await pending;

    expect(engine.stopped, [1, 2], reason: 'the late starter is stopped');
  });

  test('a start that yields nothing (asset failed to load) leaves the '
      'previous note cut and does not throw', () async {
    final engine = FakeEngine();
    final voice = SingleVoice<int>(stop: engine.stop);

    await voice.retrigger(() async => engine.newHandle());
    await voice.retrigger(() async => null);

    expect(engine.stopped, [1]);
  });
}

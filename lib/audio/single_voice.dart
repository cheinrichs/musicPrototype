/// "Latest tap wins" for a single-voice sound source: a new trigger cuts
/// whatever is sounding and starts the new sound at once, and a trigger that
/// has been superseded before it finished starting is stopped rather than
/// left to play on.
///
/// Why this exists as its own piece: retriggering used to `await` the old
/// voice's stop before it could start the new one, and overlapping taps
/// could each start a voice while only one handle was kept — the other
/// played out uncut and could never be stopped. A child spamming an
/// instrument got stacked or late notes instead of "my tap made a sound
/// now". Kept generic over the engine's handle type so the race can be
/// tested with fakes, since the real audio engine can't run under
/// `flutter test`.
///
/// Note the engine's `play()` resolves when a voice *starts*, not when it
/// finishes, so nothing here (or in callers) may treat a resolved future as
/// "the sound is over" — this class never asks whether a voice is still
/// playing; a new trigger always just cuts and replaces.
class SingleVoice<H> {
  /// Cuts a voice. Fire-and-forget by design: it must not be awaited on the
  /// tap path.
  final void Function(H handle) stop;

  H? _current;
  int _generation = 0;

  SingleVoice({required this.stop});

  /// Cut the current voice now, then start a new one with [start] (which
  /// may load first; return null if nothing could be started). If another
  /// trigger or [stopAll] arrives before [start] resolves, the voice it
  /// produces is stopped instead of kept.
  Future<void> retrigger(Future<H?> Function() start) async {
    final generation = ++_generation;

    final previous = _current;
    _current = null;
    if (previous != null) stop(previous);

    final handle = await start();
    if (handle == null) return;

    if (generation != _generation) {
      stop(handle);
      return;
    }
    _current = handle;
  }

  /// Cut the current voice and cancel any start still in flight.
  void stopAll() {
    _generation++;
    final current = _current;
    _current = null;
    if (current != null) stop(current);
  }
}

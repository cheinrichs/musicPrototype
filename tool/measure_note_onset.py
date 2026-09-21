#!/usr/bin/env python3
"""Measure how long each note sample under assets/audio/notes/ takes to
actually start, from the beginning of the file to the note's onset.

Why this exists: a tap on an instrument plays its sample from the start of
the file, so any quiet lead-in is dead air the child hears as "nothing
happened" (found on device, 2026-09: guitar C#4 felt slow enough that
rapid tapping seemed silent). Perceived latency is the difference between
an instrument and a button, so this measures it directly instead of
guessing which files are to blame.

Per file it reports several numbers, because they diagnose different
problems (a pure silence threshold alone misses a quiet lead-in):

  first_sound_ms   first 10ms block whose RMS exceeds an absolute floor
                   (-60 dBFS). Catches true digital silence / a padded
                   start. A file with a large value here has a literal
                   silent pad.
  t20_ms           first block reaching -20 dB re the note's own RMS peak.
  t10_ms           first block reaching -10 dB re the note's RMS peak:
                   "something clearly audible has started".
  t6_ms            first block reaching -6 dB re the RMS peak: "the note
                   itself has arrived". Files are sorted by this.
  ghost_ms         t6 - t10. A big value with a small t10 is a faint early
                   event before the real note (guitar/c_sharp_4: a soft
                   blip at ~40ms, then the note at ~710ms) — a plain
                   threshold on t10 alone calls that file fast.
  peak_ms          where the RMS peak lands.
  ramp_ms          t6 - first_sound: how long the signal is present but
                   still quiet. Large ramp with small first_sound means a
                   quiet lead-in (room tone, fret noise, a bow starting, a
                   faint pre-pluck) rather than silence — it feels just as
                   laggy to a child but would never trip a "first non-zero
                   sample" test. It also flags legitimately slow attacks
                   (bowed strings), so read it alongside the instrument.

Levels are RMS over 10ms blocks, not sample peaks, on purpose: a first
version used a 1ms peak envelope and called Cooper's flagged file
(guitar/c_sharp_4) fast, because a single click inside its faint ~700ms
lead-in tripped the threshold. A click is one sample wide; a note isn't.

Decoder note: mp3 has encoder/decoder priming (typically ~25ms). Whether
the device decoder strips it depends on the file's header, so the
library-wide MINIMUM first_sound_ms is printed as the floor to compare
against; values at or near it are "no real padding."

Usage:
    python3 tool/measure_note_onset.py                  # whole library
    python3 tool/measure_note_onset.py assets/audio/notes/guitar
    python3 tool/measure_note_onset.py --csv onsets.csv # also write a CSV
    python3 tool/measure_note_onset.py --top 40         # rows of worst-first
    python3 tool/measure_note_onset.py --self-test

Requires macOS's built-in `afconvert` (same as measure_note_pitch.py) and
numpy. Scratch work goes to a temp dir outside the repo.
"""

from __future__ import annotations

import argparse
import csv
import statistics
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from measure_note_pitch import SAMPLE_RATE, decode_to_wav, read_pcm16_mono  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
NOTES_DIR = REPO_ROOT / "assets" / "audio" / "notes"

FLOOR_DBFS = -60.0
T20_REL_DB = -20.0
T10_REL_DB = -10.0
T6_REL_DB = -6.0
# 10ms RMS blocks: fine enough for a perceived-latency question (mp3
# priming alone is ~25ms) and immune to single-sample clicks.
BLOCK_MS = 10


@dataclass
class Onset:
    duration_ms: float
    peak: float
    first_sound_ms: float | None
    t20_ms: float | None
    t10_ms: float | None
    t6_ms: float | None
    peak_ms: float

    @property
    def ramp_ms(self) -> float | None:
        if self.first_sound_ms is None or self.t6_ms is None:
            return None
        return self.t6_ms - self.first_sound_ms

    @property
    def ghost_ms(self) -> float | None:
        """Gap between something clearly audible (t10) and the main note
        arriving (t6). Large with a small t10 is a faint early event
        followed by the real note (guitar/c_sharp_4); a few tens of ms is
        just an ordinary attack."""
        if self.t10_ms is None or self.t6_ms is None:
            return None
        return self.t6_ms - self.t10_ms


def measure_onset(samples: np.ndarray, sample_rate: int) -> Onset:
    """Onset metrics for a mono float signal in [-1, 1]. Pure function so it
    can be checked against synthetic signals with known answers."""
    block = max(1, int(sample_rate * BLOCK_MS / 1000))
    usable = (len(samples) // block) * block
    env = np.sqrt((samples[:usable].reshape(-1, block) ** 2).mean(axis=1))
    peak = float(env.max()) if len(env) else 0.0

    def first_at_or_above(level: float) -> float | None:
        if peak == 0.0 or level > peak:
            return None
        idx = np.flatnonzero(env >= level)
        return float(idx[0]) * BLOCK_MS if len(idx) else None

    return Onset(
        duration_ms=len(samples) / sample_rate * 1000,
        peak=peak,
        first_sound_ms=first_at_or_above(10 ** (FLOOR_DBFS / 20)),
        t20_ms=first_at_or_above(peak * 10 ** (T20_REL_DB / 20)),
        t10_ms=first_at_or_above(peak * 10 ** (T10_REL_DB / 20)),
        t6_ms=first_at_or_above(peak * 10 ** (T6_REL_DB / 20)),
        peak_ms=float(np.argmax(env)) * BLOCK_MS if len(env) else 0.0,
    )


def measure_file(mp3: Path, work_dir: Path) -> Onset:
    wav = work_dir / (mp3.stem + ".wav")
    decode_to_wav(mp3, wav)
    raw, sr = read_pcm16_mono(wav)
    wav.unlink()
    return measure_onset(np.asarray(raw, dtype=np.float64) / 32768.0, sr)


def self_test() -> None:
    sr = SAMPLE_RATE
    t = np.arange(int(sr * 1.0)) / sr
    tone = np.sin(2 * np.pi * 440 * t)
    tol = BLOCK_MS + 1  # results are quantized to one block

    def pad(ms: float) -> np.ndarray:
        return np.zeros(int(sr * ms / 1000))

    # 1. Immediate attack: everything ~0.
    o = measure_onset(tone * 0.8, sr)
    assert o.first_sound_ms is not None and o.first_sound_ms <= tol, o
    assert o.t10_ms is not None and o.t10_ms <= tol, o

    # 2. True silence pad of 200ms then an immediate attack.
    o = measure_onset(np.concatenate([pad(200), tone * 0.8]), sr)
    assert abs(o.first_sound_ms - 200) <= tol, o
    assert abs(o.t10_ms - 200) <= tol, o
    assert o.ramp_ms <= tol, o

    # 3. A quiet lead-in, no digital silence: ~-50 dB room tone from the
    # start, then the note at 300ms. A "first non-zero sample" / silence
    # test would call this 0ms; the note onset must still come out at
    # ~300ms, and ramp_ms must expose the difference.
    room = np.random.default_rng(1).normal(0, 10 ** (-50 / 20) / 3, int(sr * 0.3))
    o = measure_onset(np.concatenate([room, tone * 0.8]), sr)
    assert o.first_sound_ms is not None and o.first_sound_ms <= tol, o
    assert abs(o.t10_ms - 300) <= tol, o
    assert o.ramp_ms >= 290, o

    # 4. Regression for the bug found on guitar/c_sharp_4: a faint ~700ms
    # lead-in containing a single-sample click, then the note. A peak-based
    # envelope reported the click's position (~30ms); an RMS one must not.
    lead = np.random.default_rng(2).normal(0, 10 ** (-32 / 20) / 3, int(sr * 0.7))
    lead[int(sr * 0.03)] = 0.3  # one-sample click
    o = measure_onset(np.concatenate([lead, tone * 0.8]), sr)
    assert abs(o.t10_ms - 700) <= tol, o

    # 5. A slow swell (bow starting): linear 0 -> 1 over 400ms. -10 dB re
    # the RMS peak (~31% amplitude) is ~125ms in; -20 dB (10%) ~40ms.
    swell = tone[: int(sr * 0.4)] * np.linspace(0, 1, int(sr * 0.4))
    o = measure_onset(np.concatenate([swell, tone]), sr)
    assert 100 <= o.t10_ms <= 160, o
    assert 20 <= o.t20_ms <= 60, o

    # 6. The guitar/c_sharp_4 shape: a soft early event ~9 dB under the
    # main note at 30ms, faint noise, then the real note at 700ms. t10 sees
    # the blip (small); t6 must see the note (700ms); ghost_ms is the gap.
    early = np.random.default_rng(3).normal(0, 10 ** (-32 / 20) / 3, int(sr * 0.7))
    blip = tone[: int(sr * 0.05)] * 0.8 * 10 ** (-9 / 20)
    early[int(sr * 0.03): int(sr * 0.03) + len(blip)] += blip
    o = measure_onset(np.concatenate([early, tone * 0.8]), sr)
    assert o.t10_ms <= 60, o
    assert abs(o.t6_ms - 700) <= tol, o
    assert o.ghost_ms >= 600, o

    # 7. All-zero file: reports nothing rather than crashing.
    o = measure_onset(np.zeros(sr), sr)
    assert o.first_sound_ms is None and o.t10_ms is None, o

    print("self-test passed (7 synthetic signals with known onsets)")


def collect(paths: list[str]) -> list[Path]:
    roots = [Path(p) for p in paths] if paths else [NOTES_DIR]
    files: list[Path] = []
    for root in roots:
        files += [root] if root.is_file() else sorted(root.rglob("*.mp3"))
    return files


def instrument_of(mp3: Path) -> str:
    rel = mp3.resolve().relative_to(NOTES_DIR.resolve())
    return rel.parts[0] if len(rel.parts) > 1 else "(piano, top level)"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--csv")
    ap.add_argument("--top", type=int, default=30)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        self_test()
        return

    files = collect(args.paths)
    rows = []
    with tempfile.TemporaryDirectory(prefix="onset_") as tmp:
        for f in files:
            rows.append((f, measure_file(f, Path(tmp))))

    def key(r):
        v = r[1].t6_ms
        return -(v if v is not None else 1e9)

    rows.sort(key=key)

    floor = min((o.first_sound_ms for _, o in rows if o.first_sound_ms is not None), default=None)
    print(f"{len(rows)} files. Library-wide minimum first_sound_ms (decoder-priming floor): {floor}")
    print()
    print(f"{'file':<44} {'first':>6} {'t10':>6} {'t6':>6} {'ghost':>6} {'peak':>6} {'dur':>6}")
    print("-" * 90)
    for f, o in rows[: args.top]:
        rel = f.resolve().relative_to(NOTES_DIR.resolve())
        fmt = lambda v: " none" if v is None else f"{v:6.0f}"
        print(f"{str(rel):<44} {fmt(o.first_sound_ms)} {fmt(o.t10_ms)} {fmt(o.t6_ms)} {fmt(o.ghost_ms)} {o.peak_ms:6.0f} {o.duration_ms:6.0f}")

    print()
    print("Per instrument (t6 = ms until the note itself has arrived):")
    print(f"{'instrument':<22} {'n':>4} {'median':>8} {'max':>8} {'>50ms':>7} {'>100ms':>7} {'>200ms':>7}")
    by_inst: dict[str, list[float]] = {}
    for f, o in rows:
        by_inst.setdefault(instrument_of(f), []).append(o.t6_ms if o.t6_ms is not None else float("nan"))
    for inst, vals in sorted(by_inst.items(), key=lambda kv: -statistics.median(kv[1])):
        n = len(vals)
        print(f"{inst:<22} {n:4d} {statistics.median(vals):8.0f} {max(vals):8.0f} "
              f"{sum(v > 50 for v in vals):7d} {sum(v > 100 for v in vals):7d} {sum(v > 200 for v in vals):7d}")

    if args.csv:
        with open(args.csv, "w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["file", "instrument", "first_sound_ms", "t10_ms", "t6_ms", "ghost_ms", "peak_ms", "duration_ms"])
            for f, o in rows:
                w.writerow([f.resolve().relative_to(REPO_ROOT), instrument_of(f), o.first_sound_ms, o.t10_ms, o.t6_ms, o.ghost_ms, o.peak_ms, round(o.duration_ms, 1)])
        print(f"\nwrote {args.csv}")


if __name__ == "__main__":
    main()

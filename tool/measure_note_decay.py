#!/usr/bin/env python3
"""How long each note sample actually sounds: from the note's onset to the
point its 10 ms RMS envelope last sits within 20 dB of its peak.

Why: a very short note is hard to judge in one hearing, so the round's
introduction plays short notes three times (Cooper, 2026-11-20). Which
instruments count as short is decided from these measurements, not from
instrument names, so a new short instrument (the drum hits) is covered
by the same rule. The per-instrument MEDIAN is what the app reads
(`HighLowInstrument.measuredDecayMs`): every note of one instrument then
gets the same treatment, so the two sides of a same-instrument round
always play the same number of times.

Usage:
    python3 -E tool/measure_note_decay.py              # every instrument
    python3 -E tool/measure_note_decay.py --files      # and every file
"""
from __future__ import annotations

import argparse
import statistics
import sys
import tempfile
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from split_note_runs import SR, decode  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
NOTES_DIR = REPO_ROOT / "assets" / "audio" / "notes"
DROP_DB = 20.0


def decay_ms(x: np.ndarray) -> float:
    """Onset (first block within DROP_DB of the peak) to the last block
    still within DROP_DB of it."""
    hop = SR // 100
    n = len(x) // hop
    rms = np.sqrt(np.mean(x[: n * hop].reshape(n, hop) ** 2, axis=1))
    db = 20 * np.log10(np.maximum(rms, 1e-9))
    loud = np.flatnonzero(db >= db.max() - DROP_DB)
    return float(loud[-1] - loud[0] + 1) * 10


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--files", action="store_true")
    args = ap.parse_args()
    with tempfile.TemporaryDirectory(prefix="decay_") as tmp:
        for d in sorted(p for p in NOTES_DIR.iterdir() if p.is_dir()):
            files = sorted(d.glob("*.mp3"))
            if not files:
                continue
            vals = []
            for f in files:
                v = decay_ms(decode(f, Path(tmp)))
                vals.append(v)
                if args.files:
                    print(f"  {d.name}/{f.name:<18} {v:6.0f} ms")
            print(f"{d.name:<11} n={len(vals):3d}  median {statistics.median(vals):5.0f}"
                  f"  min {min(vals):5.0f}  max {max(vals):5.0f} ms")


if __name__ == "__main__":
    main()

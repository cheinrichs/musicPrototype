#!/usr/bin/env python3
"""Cut the dead lead-in off the start of note samples, keeping the
untrimmed original so the cut can be undone.

Why: a tap plays its sample from the first byte, so anything before the
note is lag the child hears as "nothing happened" (tool/measure_note_onset.py
finds these; Cooper approved trimming them on 2026-11-15, provided the
originals are kept and every cut is recorded).

Per file:
  1. The ORIGINAL is copied byte for byte to docs/audio_originals/notes/
     <instrument>/<file>.mp3, outside assets/, so it never ships. If a
     copy is already there it is left alone: a re-run must never replace
     the original with an already-trimmed file.
  2. The note's onset is found at the sample level: the first sample, near
     the 10 ms block where the note reaches -6 dB of its own RMS peak
     (measure_note_onset's t6), whose level reaches 25% of the strike's
     peak.
  3. The file is cut 10 ms before that onset, given a 5 ms fade-in (the
     same pre-roll and fade as tool/split_note_runs.py), padded with
     silence at the end back to its original length, and re-encoded in
     the library's format (mono, 44.1 kHz, 64 kbps CBR), with the level
     the re-encode loses made up so the note plays as loud as before.

USE IT ONLY WHERE THE LEAD-IN IS NOT THE NOTE. A bowed or blown note that
starts quietly and swells is a real attack, and this would cut it away:
check the lead-in's pitch first (on 2026-11-15 four cello files flagged by
t6 turned out to be the right note from 20 ms, and were not trimmed).

To undo a cut: copy the file from docs/audio_originals/notes/ back over
the asset.

Usage:
    python3 -E tool/trim_note_start.py --dry-run assets/audio/notes/bells/*.mp3
    python3 -E tool/trim_note_start.py assets/audio/notes/guitar/c3.mp3 ...

Requires afconvert (macOS), numpy, and ffmpeg (see
normalize_loudness.find_ffmpeg).
"""
from __future__ import annotations

import argparse
import shutil
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from measure_note_onset import measure_onset  # noqa: E402
from normalize_loudness import encode_to_mp3, find_ffmpeg  # noqa: E402
from split_note_runs import SR, decode, write_mono_wav  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
NOTES_DIR = REPO_ROOT / "assets" / "audio" / "notes"
ORIGINALS_DIR = REPO_ROOT / "docs" / "audio_originals" / "notes"

PRE_ROLL_S = 0.010
FADE_IN_S = 0.005
STRIKE_FRACTION = 0.25


def find_onset(x: np.ndarray) -> int:
    """The sample where the note itself starts. Pure, so it can be tested
    against synthetic signals."""
    t6 = measure_onset(x, SR).t6_ms
    if t6 is None:
        raise ValueError("no note found")
    block = int(SR * t6 / 1000)
    lo = max(0, block - int(0.03 * SR))
    ref = np.abs(x[lo: block + int(0.06 * SR)]).max()
    window = np.abs(x[lo: block + int(0.01 * SR)])
    hits = np.flatnonzero(window >= STRIKE_FRACTION * ref)
    return lo + int(hits[0]) if len(hits) else block


def trim(x: np.ndarray) -> tuple[np.ndarray, int]:
    """Returns the trimmed signal, the same length as [x], and the number of
    samples cut from its start."""
    cut = max(0, find_onset(x) - int(PRE_ROLL_S * SR))
    y = x[cut:].copy()
    n = min(int(FADE_IN_S * SR), len(y))
    y[:n] *= np.linspace(0, 1, n)
    return np.concatenate([y, np.zeros(cut)]), cut


def body_db(x: np.ndarray) -> float:
    """The note's level: RMS over its first 0.8 s from the onset."""
    s = find_onset(x)
    body = x[s: s + int(0.8 * SR)]
    return float(10 * np.log10((body ** 2).mean()))


def self_test() -> None:
    t = np.arange(SR) / SR
    pluck = np.sin(2 * np.pi * 220 * t) * np.exp(-3 * t) * 0.8
    # A 300 ms low rumble (the guitar lead-ins) then the note.
    rumble = 0.05 * np.sin(2 * np.pi * 20 * np.arange(int(0.3 * SR)) / SR)
    x = np.concatenate([rumble, pluck])
    y, cut = trim(x)
    assert len(y) == len(x)
    assert abs(cut / SR - 0.29) < 0.005, cut / SR
    # A silent pad (the bells) then the note.
    x = np.concatenate([np.zeros(int(0.4 * SR)), pluck])
    _, cut = trim(x)
    assert abs(cut / SR - 0.39) < 0.005, cut / SR
    # No lead-in: nothing (or next to nothing) is cut.
    _, cut = trim(pluck.copy())
    assert cut / SR < 0.002, cut / SR
    print("self-test passed")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*", type=Path)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        self_test()
        return

    ffmpeg = None if args.dry_run else find_ffmpeg()
    with tempfile.TemporaryDirectory(prefix="trim_note_start_") as tmp:
        work = Path(tmp)
        for mp3 in args.files:
            rel = mp3.resolve().relative_to(NOTES_DIR.resolve())
            original = ORIGINALS_DIR / rel
            # Always measure the ORIGINAL, so a re-run reports the true cut.
            source = original if original.exists() else mp3
            x = decode(source, work)
            y, cut = trim(x)
            print(f"{rel}: cut {cut / SR * 1000:.1f} ms ({cut} samples at {SR} Hz)")
            if args.dry_run:
                continue
            if not original.exists():
                original.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(mp3, original)
            # Re-encoding costs a flat ~0.45 dB (measured 2026-11-15, every
            # band alike), so the note would come out quieter than its
            # siblings. Encode once, measure the note against the
            # original's, and encode the same trimmed audio again with
            # that loss made up: one generation, the original's level.
            wav = work / "trimmed.wav"
            write_mono_wav(wav, y)
            encode_to_mp3(wav, mp3, ffmpeg)
            loss = body_db(x) - body_db(decode(mp3, work))
            write_mono_wav(wav, y * 10 ** (loss / 20))
            encode_to_mp3(wav, mp3, ffmpeg)
            residual = body_db(decode(mp3, work)) - body_db(x)
            print(f"    level: made up {loss:+.2f} dB, now {residual:+.2f} dB "
                  "from the original's")


if __name__ == "__main__":
    main()

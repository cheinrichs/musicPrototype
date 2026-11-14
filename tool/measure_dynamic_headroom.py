#!/usr/bin/env python3
"""How far above "full" can each instrument's Loud or Quiet note be played?

Loud or Quiet plays the loud sound up to some level above the sample's own
level (a playback gain above 1). Two different limits apply, and this
script measures both for each instrument:

1. CLIPPING (a hard limit): the note's true peak, less its Loud or Quiet
   trim, measured against a -1 dBTP ceiling. Boost it any further and it
   clips, which is audible on any speaker.

2. HARSHNESS (a perceptual limit, NOT measured here): peak room is not
   perceptual room. The samples sit at -18 LUFS, but LUFS is not perceived
   loudness, and Cooper's trims on build 90 (oboe -3, flute -1.5, guitar
   -1) are the proof: he heard those three as too loud at matched LUFS.
   This script prints three candidate proxies for that: presence-band
   (2-5 kHz) energy, spectral centroid and crest factor. Checked
   2026-11-14, NONE of them ranks oboe > flute > guitar > the rest. The
   guitar, for one, comes out the darkest and least dense, yet he trimmed
   it. A starting table built on them would therefore be invented, not
   measured. So START is the clipping room alone, rounded down to the half
   decibel. Each boosted instrument awaits Cooper's ear, and the dev gate's
   "Room" control tunes each one DOWN from it.

Only the note Loud or Quiet actually plays (the middle of each
instrument's available notes; see LoudQuietRound.generate) sets the
starting table. The rest of each range is printed too, because choosing
other notes is a lever for more variety.

Usage:
    python3 tool/measure_dynamic_headroom.py
"""
from __future__ import annotations

import argparse
import math
import sys
import tempfile
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from normalize_loudness import (  # noqa: E402
    decode_to_wav, read_pcm16_mono, sustain_end, measure_lufs, SAMPLE_RATE,
)

# Mirrors HighLowInstrument (lowest, highest, missing) and
# LoudQuietRound.perceptualTrimDb. Tuba is left out: Loud or Quiet never
# plays it.
INSTRUMENTS = {
    "bells": (84, 96, set()),
    "cello": (60, 83, set()),
    "flute": (60, 83, set()),
    "guitar": (48, 71, {57, 70}),
    "oboe": (60, 83, set()),
    "piano": (60, 83, set()),
    "trumpet": (60, 83, set()),
    "violin": (60, 83, set()),
}
TRIM_DB = {"oboe": -3.0, "flute": -1.5, "guitar": -1.0}
CEILING_DBTP = -1.0
NAMES = ["c", "c_sharp", "d", "d_sharp", "e", "f", "f_sharp", "g",
         "g_sharp", "a", "a_sharp", "b"]


def filename(midi: int) -> str:
    name = NAMES[midi % 12]
    octave = midi // 12 - 1
    return f"{name}_{octave}" if "_sharp" in name else f"{name}{octave}"


def available(inst: str) -> list[int]:
    lo, hi, missing = INSTRUMENTS[inst]
    return [m for m in range(lo, hi + 1) if m not in missing]


def played_midi(inst: str) -> int:
    notes = available(inst)
    return notes[len(notes) // 2]


def true_peak_dbtp(x: np.ndarray, oversample: int = 4) -> float:
    """4x linear-interpolated true peak, as in normalize_loudness.py."""
    t = np.arange(0, len(x) - 1, 1 / oversample)
    peak = np.max(np.abs(np.interp(t, np.arange(len(x)), x)))
    return 20 * math.log10(peak) if peak > 0 else -math.inf


def spectral_proxies(x: np.ndarray, sr: int) -> tuple[float, float, float]:
    """(presence fraction 2-5 kHz by power, amplitude-spectrum centroid Hz,
    crest factor dB) over the sustained portion: candidate harshness
    proxies, printed so their (dis)agreement with Cooper's ear is visible."""
    windowed = x * np.hanning(len(x))
    mag = np.abs(np.fft.rfft(windowed))
    freqs = np.fft.rfftfreq(len(x), 1 / sr)
    power = mag ** 2
    presence = power[(freqs >= 2000) & (freqs <= 5000)].sum() / power.sum()
    centroid = (mag * freqs).sum() / mag.sum()
    crest = 20 * math.log10(np.max(np.abs(x)) / math.sqrt(np.mean(x ** 2)))
    return float(presence), float(centroid), crest


def measure(path: Path, work: Path) -> dict:
    wav = work / (path.stem + ".wav")
    decode_to_wav(path, wav)
    pcm = read_pcm16_mono(wav)
    wav.unlink(missing_ok=True)
    x = np.asarray(pcm, dtype=np.float64) / 32768.0
    end = sustain_end(pcm, SAMPLE_RATE)
    lufs, _ = measure_lufs(pcm, SAMPLE_RATE)
    presence, centroid, crest = spectral_proxies(x[:end], SAMPLE_RATE)
    return {"tp": true_peak_dbtp(x), "lufs": lufs, "presence": presence,
            "centroid": centroid, "crest": crest}


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent / "assets" / "audio" / "notes"
    results: dict[str, dict[int, dict]] = {}
    with tempfile.TemporaryDirectory(prefix="dynamic_headroom_") as tmp:
        work = Path(tmp)
        for inst in INSTRUMENTS:
            results[inst] = {}
            for midi in available(inst):
                results[inst][midi] = measure(root / inst / f"{filename(midi)}.mp3", work)

    print("Every note (true peak dBTP, LUFS, presence %), PLAYED marks Loud or Quiet's note:")
    for inst, notes in results.items():
        print(f"\n=== {inst} (trim {TRIM_DB.get(inst, 0):+.1f}) ===")
        for midi, r in notes.items():
            mark = "  <- PLAYED" if midi == played_midi(inst) else ""
            room = CEILING_DBTP - r["tp"] - TRIM_DB.get(inst, 0)
            print(f"  {filename(midi):10s} tp={r['tp']:6.2f}  LUFS={r['lufs']:6.2f}  "
                  f"presence={r['presence']*100:5.1f}%  peak room={room:+5.1f}{mark}")

    played = {i: results[i][played_midi(i)] for i in INSTRUMENTS}
    print("\nThe note Loud or Quiet plays. START = clipping room, rounded DOWN to 0.5 dB.")
    print("Proxies alongside; Cooper's trim is the ear's verdict they should agree with.\n")
    print(f"{'instrument':10s} {'note':10s} {'trim':>5s} {'peak room':>9s} {'START':>6s} "
          f"{'presence':>8s} {'centroid':>8s} {'crest':>6s}")
    for inst, r in played.items():
        room = CEILING_DBTP - r["tp"] - TRIM_DB.get(inst, 0)
        start = max(0.0, math.floor(room * 2) / 2)
        print(f"{inst:10s} {filename(played_midi(inst)):10s} {TRIM_DB.get(inst, 0):+5.1f} "
              f"{room:+9.1f} {start:+6.1f} {r['presence']*100:7.1f}% "
              f"{r['centroid']:7.0f}Hz {r['crest']:5.1f}dB")

if __name__ == "__main__":
    main()

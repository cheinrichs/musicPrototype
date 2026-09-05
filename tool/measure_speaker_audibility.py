#!/usr/bin/env python3
"""What fraction of each note's energy sits above the frequency a phone
or tablet speaker can actually reproduce?

Why this exists: a "the fundamental is too low for the speaker" rule
turns out to be the wrong test. A listening comparison (pure sine tones
vs. a harmonic-rich tone, both stepping C2->C4 on an iPhone speaker)
found pure sines nearly inaudible at C2 but a harmonic-rich tone at the
same pitch clearly audible all the way down — the ear reconstructs a
missing/inaudible fundamental from its harmonics, so what actually
predicts on-device audibility isn't the fundamental frequency, it's how
much of the note's real energy sits above the speaker's rolloff. This
script measures exactly that, per file, so a bright note and a dull note
at the same pitch (e.g. a harmonically rich cello note vs. a
fundamental-heavy tuba note) can be told apart — a fixed pitch floor
can't make that distinction.

This does NOT tell you a file is inaudible on its own — that needs an
actual listen (see tool/build_speaker_listening_test.py, which builds a
real comparison from library samples). It tells you which files are
*worth* listening to first.

Method: a 2nd-order Butterworth high-pass at --cutoff (default 200Hz —
a reasonable, conservative estimate of where small phone/tablet speakers
start rolling off; adjust with --cutoff if a specific device measures
differently) is applied to each note's sustained portion (same
sustain-detection as normalize_loudness.py, so a long quiet decay tail
doesn't skew the ratio). Energy fraction above cutoff = sum(filtered^2)
/ sum(original^2) over that window.

Usage:
    python3 tool/measure_speaker_audibility.py                    # every HighLowInstrument dir
    python3 tool/measure_speaker_audibility.py assets/audio/notes/tuba
    python3 tool/measure_speaker_audibility.py --cutoff 250 --csv out.csv
"""
from __future__ import annotations

import argparse
import math
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from normalize_loudness import (
    decode_to_wav, read_pcm16_mono, sustain_end, apply_biquad,
    HIGH_LOW_INSTRUMENT_DIRS, SAMPLE_RATE,
)


def highpass_coeffs(fc: float, fs: float, q: float = 0.7071067811865476):
    """RBJ cookbook 2nd-order (Butterworth, Q=0.707) high-pass biquad."""
    w0 = 2 * math.pi * fc / fs
    alpha = math.sin(w0) / (2 * q)
    cosw0 = math.cos(w0)
    b0 = (1 + cosw0) / 2
    b1 = -(1 + cosw0)
    b2 = (1 + cosw0) / 2
    a0 = 1 + alpha
    a1 = -2 * cosw0
    a2 = 1 - alpha
    return (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)


def energy_fraction_above(samples, sr, cutoff_hz):
    end = sustain_end(samples, sr)
    window = samples[:end]
    if len(window) < 200:
        return None
    x = [s / 32768.0 for s in window]
    total_energy = sum(v * v for v in x)
    if total_energy <= 0:
        return None
    filtered = apply_biquad(x, highpass_coeffs(cutoff_hz, sr))
    high_energy = sum(v * v for v in filtered)
    return high_energy / total_energy


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("dirs", nargs="*", default=None)
    parser.add_argument("--cutoff", type=float, default=200.0, metavar="HZ")
    parser.add_argument("--flag-below", type=float, default=0.5, metavar="FRACTION",
                         help="Flag files whose above-cutoff energy fraction is below this (default 0.5)")
    parser.add_argument("--csv", metavar="PATH")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    if args.dirs:
        dirs = [Path(d) for d in args.dirs]
    else:
        dirs = [repo_root / "assets" / "audio" / "notes" / n for n in HIGH_LOW_INSTRUMENT_DIRS]

    rows = []
    with tempfile.TemporaryDirectory(prefix="speaker_audibility_") as tmp:
        work_dir = Path(tmp)
        for d in dirs:
            if not d.exists():
                continue
            print(f"\n=== {d.name} ===")
            for mp3_path in sorted(d.glob("*.mp3")):
                wav = work_dir / (mp3_path.stem + ".wav")
                decode_to_wav(mp3_path, wav)
                samples = read_pcm16_mono(wav)
                wav.unlink(missing_ok=True)
                frac = energy_fraction_above(samples, SAMPLE_RATE, args.cutoff)
                if frac is None:
                    print(f"  {mp3_path.name:16s} (silent/unreadable)")
                    continue
                flag = "  ** LOW — mostly below cutoff **" if frac < args.flag_below else ""
                print(f"  {mp3_path.name:16s} {frac*100:5.1f}% of energy above {args.cutoff:.0f}Hz{flag}")
                rows.append((d.name, mp3_path.name, frac))

    print(f"\nPer-instrument mean fraction of energy above {args.cutoff:.0f}Hz:")
    per_inst: dict[str, list[float]] = {}
    for inst, _, frac in rows:
        per_inst.setdefault(inst, []).append(frac)
    for inst, vals in sorted(per_inst.items(), key=lambda kv: sum(kv[1]) / len(kv[1])):
        print(f"  {inst:10s} mean={sum(vals)/len(vals)*100:5.1f}%  min={min(vals)*100:5.1f}%  max={max(vals)*100:5.1f}%")

    flagged = [(inst, name, frac) for inst, name, frac in rows if frac < args.flag_below]
    print(f"\n{len(flagged)}/{len(rows)} files below {args.flag_below*100:.0f}% energy above {args.cutoff:.0f}Hz:")
    for inst, name, frac in flagged:
        print(f"  {inst}/{name}: {frac*100:.1f}%")

    if args.csv:
        import csv
        with open(args.csv, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["instrument", "filename", f"fraction_above_{int(args.cutoff)}hz"])
            for inst, name, frac in rows:
                w.writerow([inst, name, frac])
        print(f"\nWrote {args.csv}")


if __name__ == "__main__":
    main()

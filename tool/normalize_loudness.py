#!/usr/bin/env python3
"""Measure and re-normalize the High/Low note library by integrated
loudness (LUFS, ITU-R BS.1770 K-weighting) instead of peak level.

Why this exists: the library was peak-normalized (see
measure_note_pitch.py and the guitar/tuba/bells pitch audits it drove) —
every file's *sample peak* sits in the same narrow band. But peak level
isn't perceived loudness: the ear is far less sensitive at low
frequencies, so a low, bass-heavy note peak-matched to a bright, treble-
heavy note reads as quieter even though their peaks measure the same.
Cooper noticed this as "tuba is too quiet" — measurement here confirms
the mechanism is real but more specific than that framing suggests (see
the module-level report this produces): it isn't that tuba is uniquely
under-loud, it's that a peak match doesn't equalize integrated loudness
across instruments generally, and which direction any given file needs
to move depends on its actual spectral/envelope shape.

Beyond comfort, this matters because HighLowInstrument's samples are
reused for a future Loud/Soft game (MVP scope) — if loudness happens to
correlate with pitch or instrument identity today, a child could use
loudness as an unintended cue for a *pitch* game, and Loud/Soft would
inherit samples where volume isn't actually a controlled variable.

Usage:
    python3 tool/normalize_loudness.py --measure                 # report only, no changes
    python3 tool/normalize_loudness.py --measure assets/audio/notes/tuba
    python3 tool/normalize_loudness.py --apply --target -16.0    # normalize the whole library
    python3 tool/normalize_loudness.py --apply --target -16.0 assets/audio/notes/tuba

Requires macOS's built-in `afconvert` to decode, and a `ffmpeg` binary
(with libmp3lame) to re-encode — this repo's Trello card 55 audio work
established `pip install --user imageio-ffmpeg` as the way to get one
without Homebrew; pass its path via --ffmpeg or set the IMAGEIO_FFMPEG
env var if it's not already on PATH as `ffmpeg`. Everything else is
Python standard library.

Method:
  - Loudness: ITU-R BS.1770 K-weighting (a mild high-shelf above ~1.7kHz
    plus a 38Hz high-pass — this is the standard broadcast/streaming
    loudness-matching filter, not a full equal-loudness-contour model;
    see the module docstring's note above about what that does and
    doesn't correct for) applied to the *sustained* portion of the note
    only. A single struck/plucked/bowed note's long decay tail would
    otherwise drag integrated loudness down and cause over-boosting —
    the sustained portion is taken as everything up to the last point
    the note's RMS envelope (20ms windows) is still within 20dB of its
    own peak.
  - Gain: a flat per-file scalar to move measured LUFS to --target,
    computed on the *original* (unnormalized-by-this-script) audio each
    run so re-running is idempotent rather than compounding.
  - Headroom: after gain, a 4x-oversampled true-peak estimate must stay
    at or under -1 dBTP; if the requested gain would exceed that, the
    gain is clamped and the file is reported as headroom-limited rather
    than silently clipped or silently under-corrected.
"""
from __future__ import annotations

import argparse
import array
import math
import os
import shutil
import subprocess
import sys
import tempfile
import wave
from dataclasses import dataclass
from pathlib import Path

SAMPLE_RATE = 44100
TRUE_PEAK_CEILING_DBTP = -1.0
OVERSAMPLE = 4

# HighLowInstrument's own sample directories — this is the library a
# child actually hears compared side-by-side in one game, so it's the
# scope for "loudness shouldn't be an accidental pitch/instrument cue".
# Deliberately excludes the generic (non-instrument) tone and the unused
# percussion/ directory — different feature, not part of this audit.
HIGH_LOW_INSTRUMENT_DIRS = [
    "bells", "cello", "flute", "guitar", "oboe", "piano", "trumpet",
    "tuba", "violin",
]


def find_ffmpeg() -> str:
    env = os.environ.get("IMAGEIO_FFMPEG")
    if env and Path(env).exists():
        return env
    which = shutil.which("ffmpeg")
    if which:
        return which
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        pass
    raise RuntimeError(
        "No ffmpeg found. Install one (e.g. `pip install --user imageio-ffmpeg`), "
        "then pass its path via --ffmpeg or IMAGEIO_FFMPEG."
    )


def decode_to_wav(mp3_path: Path, wav_path: Path) -> None:
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", f"LEI16@{SAMPLE_RATE}", str(mp3_path), str(wav_path)],
        check=True, capture_output=True,
    )


def read_pcm16_mono(wav_path: Path) -> array.array:
    with wave.open(str(wav_path), "rb") as w:
        assert w.getframerate() == SAMPLE_RATE
        assert w.getnchannels() == 1
        assert w.getsampwidth() == 2
        frames = w.readframes(w.getnframes())
    arr = array.array("h")
    arr.frombytes(frames)
    return arr


def write_pcm16_mono(wav_path: Path, samples) -> None:
    with wave.open(str(wav_path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        clamped = array.array("h", (max(-32768, min(32767, int(round(s)))) for s in samples))
        w.writeframes(clamped.tobytes())


def encode_to_mp3(wav_path: Path, mp3_path: Path, ffmpeg: str) -> None:
    subprocess.run(
        [ffmpeg, "-y", "-i", str(wav_path), "-ac", "1", "-ar", str(SAMPLE_RATE),
         "-b:a", "64k", "-codec:a", "libmp3lame", "-map_metadata", "-1",
         "-write_xing", "0", "-id3v2_version", "0", "-write_id3v1", "0",
         str(mp3_path)],
        check=True, capture_output=True,
    )


def k_weighting_coeffs(fs: float):
    """ITU-R BS.1770-4 Annex 2 two-stage K-weighting filter, derived for
    the given sample rate (the published coefficients are usually quoted
    for 48kHz; these formulas re-derive them for any rate, including our
    44.1kHz library)."""
    f0 = 1681.9744509555319
    G = 3.99984385397
    Q = 0.7071752369554193
    K = math.tan(math.pi * f0 / fs)
    Vh = 10 ** (G / 20)
    Vb = Vh ** 0.4996667741545416
    a0 = 1.0 + K / Q + K * K
    stage1 = (
        (Vh + Vb * K / Q + K * K) / a0,
        2 * (K * K - Vh) / a0,
        (Vh - Vb * K / Q + K * K) / a0,
        2 * (K * K - 1.0) / a0,
        (1.0 - K / Q + K * K) / a0,
    )

    f0 = 38.13547087613982
    Q = 0.5003270373238773
    K = math.tan(math.pi * f0 / fs)
    a0 = 1.0 + K / Q + K * K
    stage2 = (
        1.0, -2.0, 1.0,
        2 * (K * K - 1.0) / a0,
        (1.0 - K / Q + K * K) / a0,
    )
    return stage1, stage2


def apply_biquad(x, coeffs):
    b0, b1, b2, a1, a2 = coeffs
    y = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, xi in enumerate(x):
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        y[i] = yi
        x2, x1 = x1, xi
        y2, y1 = y1, yi
    return y


def k_weight(x, fs):
    s1, s2 = k_weighting_coeffs(fs)
    return apply_biquad(apply_biquad(x, s1), s2)


def sustain_end(samples, sr, hop_ms=20, drop_db=20) -> int:
    """Sample index marking the end of the note's sustained portion —
    see the module docstring's "Method" section."""
    hop = int(sr * hop_ms / 1000)
    n = len(samples)
    envelope = []
    for start in range(0, n, hop):
        chunk = samples[start:start + hop]
        if not chunk:
            break
        rms = math.sqrt(sum(s * s for s in chunk) / len(chunk))
        envelope.append(rms)
    if not envelope:
        return n
    peak = max(envelope)
    if peak <= 0:
        return n
    threshold = peak * (10 ** (-drop_db / 20))
    last_good = 0
    for i, e in enumerate(envelope):
        if e >= threshold:
            last_good = i
    return min(n, (last_good + 1) * hop)


def measure_lufs(samples: array.array, sr: int) -> tuple[float | None, int]:
    """Returns (LUFS over the sustained portion, sustained-sample-count).
    LUFS is None if the sustained portion is silent."""
    end = sustain_end(samples, sr)
    sustained = samples[:end]
    x = [s / 32768.0 for s in sustained]
    weighted = k_weight(x, sr)
    if not weighted:
        return None, end
    mean_sq = sum(w * w for w in weighted) / len(weighted)
    if mean_sq <= 0:
        return None, end
    return -0.691 + 10 * math.log10(mean_sq), end


def true_peak_dbtp(samples: array.array, oversample: int = OVERSAMPLE) -> float:
    """4x-oversampled true-peak estimate via linear interpolation —
    approximate (a real ITU-R BS.1770 true-peak meter uses a windowed-
    sinc polyphase upsampler) but catches the common case of an
    inter-sample peak between two large same-sign samples that a plain
    sample-peak check would miss, which is what matters for headroom
    here."""
    n = len(samples)
    if n < 2:
        peak = max((abs(s) for s in samples), default=0)
        return 20 * math.log10(peak / 32768.0) if peak > 0 else -math.inf
    peak = 0.0
    for i in range(n - 1):
        a, b = samples[i], samples[i + 1]
        peak = max(peak, abs(a))
        for k in range(1, oversample):
            interp = a + (b - a) * (k / oversample)
            peak = max(peak, abs(interp))
    peak = max(peak, abs(samples[-1]))
    return 20 * math.log10(peak / 32768.0) if peak > 0 else -math.inf


def peak_dbfs(samples: array.array) -> float:
    peak = max((abs(s) for s in samples), default=0)
    return 20 * math.log10(peak / 32768.0) if peak > 0 else -math.inf


@dataclass
class FileReport:
    instrument: str
    filename: str
    lufs_before: float | None
    peak_before: float
    true_peak_before: float
    lufs_after: float | None = None
    peak_after: float | None = None
    true_peak_after: float | None = None
    gain_db: float = 0.0
    headroom_limited: bool = False


def resolve_dirs(repo_root: Path, requested: list[str] | None) -> list[Path]:
    if requested:
        return [Path(d) for d in requested]
    return [repo_root / "assets" / "audio" / "notes" / name for name in HIGH_LOW_INSTRUMENT_DIRS]


def process_file(mp3_path: Path, work_dir: Path, target_lufs: float | None, ffmpeg: str) -> FileReport:
    wav_path = work_dir / (mp3_path.stem + "_orig.wav")
    decode_to_wav(mp3_path, wav_path)
    samples = read_pcm16_mono(wav_path)
    wav_path.unlink(missing_ok=True)

    lufs_before, _ = measure_lufs(samples, SAMPLE_RATE)
    peak_before = peak_dbfs(samples)
    tp_before = true_peak_dbtp(samples)

    report = FileReport(
        instrument=mp3_path.parent.name, filename=mp3_path.name,
        lufs_before=lufs_before, peak_before=peak_before, true_peak_before=tp_before,
    )

    if target_lufs is None or lufs_before is None:
        return report

    gain_db = target_lufs - lufs_before
    # Headroom check: don't let the gain push true peak past the ceiling.
    max_gain_for_headroom = TRUE_PEAK_CEILING_DBTP - tp_before
    headroom_limited = gain_db > max_gain_for_headroom
    applied_gain = min(gain_db, max_gain_for_headroom)

    factor = 10 ** (applied_gain / 20)
    gained = [s * factor for s in samples]

    norm_wav = work_dir / (mp3_path.stem + "_norm.wav")
    write_pcm16_mono(norm_wav, gained)
    encode_to_mp3(norm_wav, mp3_path, ffmpeg)
    norm_wav.unlink(missing_ok=True)

    # Re-measure the actual encoded result (mp3 is lossy — worth
    # confirming what really landed, same lesson as the pitch audit).
    check_wav = work_dir / (mp3_path.stem + "_check.wav")
    decode_to_wav(mp3_path, check_wav)
    final_samples = read_pcm16_mono(check_wav)
    check_wav.unlink(missing_ok=True)

    report.gain_db = applied_gain
    report.headroom_limited = headroom_limited
    report.lufs_after, _ = measure_lufs(final_samples, SAMPLE_RATE)
    report.peak_after = peak_dbfs(final_samples)
    report.true_peak_after = true_peak_dbtp(final_samples)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("dirs", nargs="*", default=None,
                         help="Instrument directories (default: all 9 HighLowInstrument dirs)")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--measure", action="store_true", help="Report current LUFS/peak only, no changes")
    mode.add_argument("--apply", action="store_true", help="Normalize files in place to --target LUFS")
    parser.add_argument("--target", type=float, default=None, metavar="LUFS",
                         help="Target integrated loudness, e.g. -16.0 (required with --apply)")
    parser.add_argument("--ffmpeg", default=None, help="Path to an ffmpeg binary (with libmp3lame)")
    parser.add_argument("--csv", metavar="PATH", help="Also write the before/after table as CSV")
    args = parser.parse_args()

    if args.apply and args.target is None:
        parser.error("--apply requires --target")

    if shutil.which("afconvert") is None:
        print("ERROR: afconvert not found (Xcode Command Line Tools).", file=sys.stderr)
        sys.exit(1)

    ffmpeg = None
    if args.apply:
        try:
            ffmpeg = args.ffmpeg or find_ffmpeg()
        except RuntimeError as e:
            print(f"ERROR: {e}", file=sys.stderr)
            sys.exit(1)

    repo_root = Path(__file__).resolve().parent.parent
    dirs = resolve_dirs(repo_root, args.dirs)

    all_reports: list[FileReport] = []
    with tempfile.TemporaryDirectory(prefix="normalize_loudness_") as tmp:
        work_dir = Path(tmp)
        for d in dirs:
            if not d.exists():
                continue
            print(f"\n=== {d.name} ===")
            for mp3_path in sorted(d.glob("*.mp3")):
                target = args.target if args.apply else None
                r = process_file(mp3_path, work_dir, target, ffmpeg)
                all_reports.append(r)
                lufs_str = f"{r.lufs_before:6.2f}" if r.lufs_before is not None else "  n/a "
                line = f"  {r.filename:16s} LUFS={lufs_str} peak={r.peak_before:6.2f}dBFS truepeak={r.true_peak_before:6.2f}dBTP"
                if args.apply:
                    after_lufs = f"{r.lufs_after:6.2f}" if r.lufs_after is not None else "  n/a "
                    limited = "  ** HEADROOM-LIMITED **" if r.headroom_limited else ""
                    line += f"  -> gain={r.gain_db:+5.2f}dB  after LUFS={after_lufs} peak={r.peak_after:6.2f}dBFS truepeak={r.true_peak_after:6.2f}dBTP{limited}"
                print(line)

    valid = [r.lufs_before for r in all_reports if r.lufs_before is not None]
    if valid:
        print(f"\n{len(all_reports)} files, {len(valid)} measured.")
        print(f"LUFS range: {min(valid):.2f} to {max(valid):.2f}, mean {sum(valid)/len(valid):.2f}")

    per_instrument: dict[str, list[float]] = {}
    for r in all_reports:
        if r.lufs_before is not None:
            per_instrument.setdefault(r.instrument, []).append(r.lufs_before)
    print("\nPer-instrument mean LUFS (before):")
    for inst, vals in sorted(per_instrument.items(), key=lambda kv: sum(kv[1]) / len(kv[1])):
        print(f"  {inst:10s} mean={sum(vals)/len(vals):7.2f}  min={min(vals):7.2f}  max={max(vals):7.2f}")

    if args.csv:
        import csv
        with open(args.csv, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["instrument", "filename", "lufs_before", "peak_before_dbfs", "truepeak_before_dbtp",
                        "gain_db", "lufs_after", "peak_after_dbfs", "truepeak_after_dbtp", "headroom_limited"])
            for r in all_reports:
                w.writerow([r.instrument, r.filename, r.lufs_before, r.peak_before, r.true_peak_before,
                            r.gain_db, r.lufs_after, r.peak_after, r.true_peak_after, r.headroom_limited])
        print(f"\nWrote {args.csv}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Build a real-sample A/B listening test: a fixed reference note,
followed by each note of a test run in turn, with a gap between clips —
for judging on-device audibility by ear rather than by meter.

Why real samples instead of synthesized tones: a synthesized comparison
(e.g. pure sine vs. a bright sawtooth, both stepping the same pitches)
can show that harmonic content *can* carry a low note past a small
speaker's rolloff, but it can't tell you whether a *specific real
instrument's* recordings actually have that harmonic content — a mellow,
fundamental-heavy instrument won't behave like a bright synthetic test
tone. This builds the comparison from the library's own (already
loudness-normalized) files, so what's being judged is the real samples.

The reference clip is the same file before every test note, so the
listener has a constant, known-good anchor to judge each test note
against — level-matching only removes level as a confound, so any
change in perceived clarity or "smallness" across the run tracks the
test notes' actual harmonic content, not left-over volume differences.

Usage:
    python3 tool/build_speaker_listening_test.py \\
        --reference assets/audio/notes/flute/c5.mp3 \\
        --test-dir assets/audio/notes/tuba \\
        --out ~/Desktop/tuba_speaker_test.wav

    # Only a subset of the test directory's notes, in a specific order:
    python3 tool/build_speaker_listening_test.py \\
        --reference assets/audio/notes/flute/c5.mp3 \\
        --test-files assets/audio/notes/tuba/c2.mp3 assets/audio/notes/tuba/g2.mp3 \\
        --out ~/Desktop/tuba_speaker_test.wav

Requires macOS's built-in `afconvert` to decode. Writes a plain WAV
(mono, 44.1kHz, 16-bit) — uncompressed, so nothing about the comparison
is confounded by an extra lossy encode/decode pass on top of what's
already in the library's mp3s.
"""
from __future__ import annotations

import argparse
import array
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from normalize_loudness import decode_to_wav, read_pcm16_mono, SAMPLE_RATE
from measure_note_pitch import general_filename_midi


def sorted_by_real_pitch(paths: list[Path]) -> list[Path]:
    """Sorts by the real MIDI pitch each filename encodes (e.g. c2 < c_sharp_2
    < d2 < ... < b3), not alphabetically — plain sorted() puts a2/a3 before
    b2/b3 before c2/c3, which is not a pitch order at all."""
    def key(p: Path):
        midi = general_filename_midi(p.stem)
        return midi if midi is not None else float("inf")
    return sorted(paths, key=key)


def silence(seconds: float) -> array.array:
    return array.array("h", [0] * int(SAMPLE_RATE * seconds))


def load(mp3_path: Path, work_dir: Path) -> array.array:
    wav_path = work_dir / (mp3_path.stem + f"_{id(mp3_path)}.wav")
    decode_to_wav(mp3_path, wav_path)
    samples = read_pcm16_mono(wav_path)
    wav_path.unlink(missing_ok=True)
    return samples


def write_wav(path: Path, samples: array.array) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(samples.tobytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--reference", required=True, help="Path to the fixed reference note (mp3)")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--test-dir", help="Directory of test notes — every .mp3 in it, sorted by filename")
    group.add_argument("--test-files", nargs="+", help="Explicit list of test note paths, in order")
    parser.add_argument("--out", required=True, help="Output WAV path")
    parser.add_argument("--pre-gap", type=float, default=1.0, help="Seconds of silence between reference and test note (default 1.0)")
    parser.add_argument("--post-gap", type=float, default=2.0, help="Seconds of silence after the test note, before the next pair (default 2.0)")
    args = parser.parse_args()

    reference_path = Path(args.reference)
    if args.test_dir:
        test_paths = sorted_by_real_pitch(list(Path(args.test_dir).glob("*.mp3")))
    else:
        test_paths = [Path(p) for p in args.test_files]

    if not test_paths:
        print("No test files found.", file=sys.stderr)
        sys.exit(1)

    out_path = Path(args.out).expanduser()

    with tempfile.TemporaryDirectory(prefix="speaker_listening_test_") as tmp:
        work_dir = Path(tmp)
        reference = load(reference_path, work_dir)
        pre_gap = silence(args.pre_gap)
        post_gap = silence(args.post_gap)

        sequence = array.array("h")
        print(f"Reference: {reference_path}")
        for test_path in test_paths:
            test_samples = load(test_path, work_dir)
            sequence.extend(reference)
            sequence.extend(pre_gap)
            sequence.extend(test_samples)
            sequence.extend(post_gap)
            print(f"  + {test_path}")

        write_wav(out_path, sequence)

    duration = len(sequence) / SAMPLE_RATE
    print(f"\nWrote {out_path} ({duration:.1f}s, {len(test_paths)} test note(s), "
          f"reference-then-test with {args.pre_gap:.1f}s/{args.post_gap:.1f}s gaps)")


if __name__ == "__main__":
    main()

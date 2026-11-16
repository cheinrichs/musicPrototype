#!/usr/bin/env python3
"""Split a recording of several notes played in turn (one University of
Iowa MIS file holds a whole octave, e.g. xylophone.rosewood.mf.C5B5.aif)
into one short mp3 per note, in this library's format.

Each note:
  - starts 10 ms before its onset;
  - runs to the library's standard length (1.645625 s, every instrument),
    or until 20 ms before the next onset, whichever comes first;
  - gets a 5 ms fade-in and an 80 ms fade-out, so nothing clicks;
  - is padded with silence to the standard length;
  - is downmixed to mono (a real channel average), 44.1 kHz, and encoded
    to 64 kbps CBR mp3.

The files are NAMED BY THE PITCH THE SOURCE CLAIMS. That is a claim, not
a fact: verify every file with tool/measure_note_pitch.py afterwards
(--verify-chromatic) before trusting it, then normalise loudness with
tool/normalize_loudness.py.

Onsets are the strong peaks of a 10 ms RMS envelope (see [onsets]). If the onsets
found do not number the notes expected, NOTHING is written, and the
onsets are printed so the recording can be looked at.

Usage:
    python3 -E tool/split_note_runs.py SOURCE.aif --first C5 --count 12 --out DIR
    python3 -E tool/split_note_runs.py SOURCE.aif --first F4 --count 7 --out DIR

Run from the repo root, never from inside the download's directory:
downloaded audio is untrusted data, so it is passed as a path only. (Not
-I: that also drops the user site-packages, where numpy lives.) Requires
afconvert (macOS), numpy, and ffmpeg (see normalize_loudness.find_ffmpeg).
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from normalize_loudness import encode_to_mp3, find_ffmpeg  # noqa: E402

SR = 44100
PEAK_WITHIN_DB = 20.0
NOTE_LENGTH_S = 1.645625
NAMES = ["c", "c_sharp", "d", "d_sharp", "e", "f", "f_sharp", "g",
         "g_sharp", "a", "a_sharp", "b"]
LETTERS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def parse_note(s: str) -> int:
    s = s.strip()
    pc = LETTERS[s[0].upper()]
    rest = s[1:]
    if rest.startswith(("#", "s")):
        pc += 1
        rest = rest[1:]
    return (int(rest) + 1) * 12 + pc


def file_stem(midi: int) -> str:
    name = NAMES[midi % 12]
    octave = midi // 12 - 1
    return f"{name}_{octave}" if "_" in name else f"{name}{octave}"


def decode(source: Path, work: Path) -> np.ndarray:
    wav = work / "decoded.wav"
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", f"LEI16@{SR}", str(source), str(wav)],
        check=True, capture_output=True,
    )
    with wave.open(str(wav), "rb") as w:
        channels = w.getnchannels()
        assert w.getframerate() == SR and w.getsampwidth() == 2
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2")
    data = data.reshape(-1, channels).astype(np.float64).mean(axis=1)
    return data / 32768.0


def onsets(x: np.ndarray) -> list[int]:
    """Strikes: peaks of the 10 ms RMS envelope within [PEAK_WITHIN_DB] of
    the file's loudest, each the highest point within 0.4 s either side and
    at least 0.8 s after the last, walked back to where its rise begins.
    (A rise-over-recent-minimum test fired on the recording room's own
    low-level noise, 40-60 dB down: 43-59 "onsets" for 12 notes.)"""
    hop = SR // 100
    frames = len(x) // hop
    rms = np.sqrt(np.mean(x[: frames * hop].reshape(frames, hop) ** 2, axis=1))
    db = 20 * np.log10(np.maximum(rms, 1e-9))
    top = db.max()
    found: list[int] = []
    for i in range(frames):
        if db[i] < top - PEAK_WITHIN_DB:
            continue
        if db[i] < db[max(0, i - 40): i + 41].max():
            continue
        if found and i - found[-1] < 80:
            continue
        j = i
        while j > 0 and i - j < 5 and db[j - 1] < db[j] - 0.5:
            j -= 1
        found.append(j)
    return [f * hop for f in found]


def first_sound(x: np.ndarray) -> int:
    """A file holding ONE note: where the sound first comes within 25 dB of
    its loudest. Peak-finding is wrong for a single SUSTAINED note: a held
    flute tone peaks well after it starts (walking back from the peak cut
    G#6 0.5 s in), and a dip in the held tone reads as a second strike."""
    hop = SR // 100
    frames = len(x) // hop
    rms = np.sqrt(np.mean(x[: frames * hop].reshape(frames, hop) ** 2, axis=1))
    db = 20 * np.log10(np.maximum(rms, 1e-9))
    return int(np.argmax(db > db.max() - 25)) * hop


def write_mono_wav(path: Path, y: np.ndarray) -> None:
    pcm = np.clip(np.round(y * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", type=Path)
    ap.add_argument("--first", required=True, help="The first note's claimed pitch, e.g. C5")
    ap.add_argument("--count", required=True, type=int, help="How many notes the file holds")
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    ffmpeg = find_ffmpeg()
    first = parse_note(args.first)
    length = int(round(NOTE_LENGTH_S * SR))
    fade_in, fade_out = int(0.005 * SR), int(0.08 * SR)
    with tempfile.TemporaryDirectory(prefix="split_note_runs_") as tmp:
        work = Path(tmp)
        x = decode(args.source, work)
        starts = onsets(x) if args.count > 1 else [first_sound(x)]
        if len(starts) != args.count:
            print(f"ERROR: {args.source.name}: found {len(starts)} onsets, expected "
                  f"{args.count}: " + ", ".join(f"{s / SR:.2f}s" for s in starts),
                  file=sys.stderr)
            sys.exit(1)
        args.out.mkdir(parents=True, exist_ok=True)
        for k, s in enumerate(starts):
            begin = max(0, s - int(0.01 * SR))
            end = begin + length
            if k + 1 < len(starts):
                end = min(end, starts[k + 1] - int(0.02 * SR))
            y = x[begin:end].copy()
            y[:fade_in] *= np.linspace(0, 1, min(fade_in, len(y)))[: len(y[:fade_in])]
            n = min(fade_out, len(y))
            y[len(y) - n:] *= np.linspace(1, 0, n)
            y = np.concatenate([y, np.zeros(max(0, length - len(y)))])
            stem = file_stem(first + k)
            wav = work / f"{stem}.wav"
            write_mono_wav(wav, y)
            encode_to_mp3(wav, args.out / f"{stem}.mp3", ffmpeg)
            print(f"  {stem}.mp3  onset {s / SR:6.2f}s  kept {len(x[begin:end]) / SR:.3f}s")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Compute a coarse loudness envelope for every voice line and ship it as
one small JSON manifest, assets/audio/voice/envelopes.json.

Why this exists: the speaking indicator (Trello card PIm7xE6n) used to be
a looping bob, then a looping sway — Cooper rejected both on device with
the same underlying complaint: a loop is fixed motion at a fixed tempo,
and speech isn't periodic, so steady repeating motion reads as a *state*
the character is in (excited, fidgety) rather than as talking. The fix
agreed with Cooper is to drive the indicator (a small scale pulse now,
mouth movement once sprites support it) from the voice line's own
loudness envelope, so the motion actually lands on the rhythm of the
speech.

This has to happen at build time, not on the device: runtime audio
analysis is unnecessary cost on an iPad and less reliable than measuring
the known, static source files once. `tool/normalize_loudness.py` already
does per-file loudness analysis for this project's note library — this
reuses its decode/read helpers rather than re-deriving them.

Output format (assets/audio/voice/envelopes.json):
    {
      "hopMs": 30,
      "lines": {
        "clefSaysHigh": [0.0, 0.12, 0.87, ...],
        ...
      }
    }

Each line's samples are RMS loudness per hopMs block, normalized 0-1
against that clip's own peak block — a *relative* curve (loud parts vs.
quiet parts of this line), not a cross-line loudness comparison. That's
all the speaking indicator needs: open on the loud syllables, close in
the gaps.

Usage:
    python3 tool/build_voice_envelopes.py                 # write the manifest
    python3 tool/build_voice_envelopes.py --self-test

Requires macOS's built-in `afconvert` and numpy, same as
measure_note_onset.py, whose decode helpers (via measure_note_pitch) this
reuses.
"""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from measure_note_pitch import decode_to_wav, read_pcm16_mono  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
VOICE_DIR = REPO_ROOT / "assets" / "audio" / "voice"
MANIFEST_PATH = VOICE_DIR / "envelopes.json"

HOP_MS = 30
# A floor under which we call a block "silent" regardless of the clip's own
# peak, so a clip that's mostly near-silence (a long tail, or noise floor)
# doesn't get its noise floor stretched up toward 1.0 by the normalization.
FLOOR_DBFS = -50.0
# Coarse enough to keep the manifest small; fine enough that a pulse driven
# by these numbers doesn't look like it's snapping between two values.
ROUND_DP = 3


def compute_envelope(samples: np.ndarray, sample_rate: int, hop_ms: int = HOP_MS) -> list[float]:
    """RMS-per-hop envelope for a mono float signal in [-1, 1], normalized
    0-1 against the signal's own peak block. Pure function so it can be
    checked against synthetic signals with known shapes."""
    hop = max(1, int(sample_rate * hop_ms / 1000))
    usable = (len(samples) // hop) * hop
    if usable == 0:
        return []
    env = np.sqrt((samples[:usable].reshape(-1, hop) ** 2).mean(axis=1))

    floor = 10 ** (FLOOR_DBFS / 20)
    env = np.maximum(env, 0.0)
    peak = float(env.max())
    if peak <= floor:
        return [0.0] * len(env)

    normalized = np.clip((env - floor) / (peak - floor), 0.0, 1.0)
    return [round(float(v), ROUND_DP) for v in normalized]


def build_envelope_for_file(mp3: Path, work_dir: Path) -> list[float]:
    wav = work_dir / (mp3.stem + ".wav")
    decode_to_wav(mp3, wav)
    raw, sr = read_pcm16_mono(wav)
    wav.unlink()
    return compute_envelope(np.asarray(raw, dtype=np.float64) / 32768.0, sr)


def self_test() -> None:
    sr = 44100
    hop = HOP_MS

    def hops(n: int) -> int:
        return int(sr * hop / 1000) * n

    # 1. Two loud blocks separated by a quiet gap: the envelope must show
    # loud-quiet-loud, not a flat line or a single ramp.
    loud = np.full(hops(2), 0.8)
    quiet = np.full(hops(2), 0.01)
    signal = np.concatenate([loud, quiet, loud])
    env = compute_envelope(signal, sr)
    assert env[0] > 0.9, env
    assert env[2] < env[0] and env[2] < 0.2, env
    assert env[-1] > 0.9, env

    # 2. Pure near-silence throughout (a clip with no real signal, or an
    # empty/failed decode's worth of noise floor): every block must read
    # ~0, never divide-by-near-zero blowing a noise floor up to 1.0.
    noise = np.random.default_rng(0).normal(0, 10 ** (-55 / 20) / 3, hops(4))
    env = compute_envelope(noise, sr)
    assert all(v < 0.05 for v in env), env

    # 3. A single block louder than everything else normalizes to exactly
    # 1.0 there, and the file's own quieter-but-real content stays above
    # the floor rather than being crushed to 0.
    quiet_real = np.full(hops(1), 0.05)  # well above FLOOR_DBFS (~0.003)
    peak = np.full(hops(1), 0.9)
    env = compute_envelope(np.concatenate([quiet_real, peak]), sr)
    assert env[1] == 1.0, env
    assert env[0] > 0.0, env

    # 4. Empty input: no crash, empty envelope.
    assert compute_envelope(np.zeros(0), sr) == []

    print("self-test passed (4 synthetic signals with known envelope shapes)")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        self_test()
        return

    files = sorted(VOICE_DIR.glob("*.mp3"))
    lines: dict[str, list[float]] = {}
    skipped: list[str] = []
    with tempfile.TemporaryDirectory(prefix="voice_env_") as tmp:
        for f in files:
            envelope = build_envelope_for_file(f, Path(tmp))
            if not envelope:
                skipped.append(f.name)
                continue
            lines[f.stem] = envelope

    manifest = {"hopMs": HOP_MS, "lines": lines}
    MANIFEST_PATH.write_text(json.dumps(manifest, separators=(",", ":")))

    print(f"wrote {MANIFEST_PATH} ({len(lines)} lines, "
          f"{MANIFEST_PATH.stat().st_size} bytes)")
    if skipped:
        print(f"skipped (no usable audio): {skipped}")


if __name__ == "__main__":
    main()

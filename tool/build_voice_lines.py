#!/usr/bin/env python3
"""Convert Cooper's re-recorded VoiceLine WAVs into the repo's voice
assets, gain-normalized to their own target, separate from the notes.

Why voice gets its own script rather than reusing normalize_loudness.py
directly on assets/audio/voice/: these are freshly delivered WAVs from
outside the repo (different sample rate, arbitrary upload filenames)
being placed under their VoiceLine enum names for the first time, not
existing library mp3s being re-normalized in place — and the mapping
from upload filename to enum member is one-off business logic that
doesn't belong in the general-purpose normalizer. The actual measurement
and gain/headroom logic is shared (imported from normalize_loudness.py),
including its whole-clip LUFS mode: speech doesn't have the single-note
decay-tail problem the sustain-window trimming exists for, and trimming
speech risks truncating a real pause between words.

Two constraints specific to voice, from Cooper directly:
  - Normalize to voice's own target, separate from the note library's
    -18 LUFS. The target itself is derived from the data (see
    VOICE_TARGET_LUFS below) rather than picked to sit above the notes
    upfront — an earlier attempt at picking a hot target for exactly that
    reason left most files headroom-limited and made the *inconsistency*
    between lines worse, not better. Resolution (also Cooper, once the
    tension showed up in the numbers): consistency between the voice
    lines matters more than the voice-vs-notes offset — get the lines
    even first, restore the offset later with a uniform playback-time
    gain across the whole voice set if it's still wanted, rather than
    sacrificing evenness to chase it here.
  - Gain only, never anything that could shift pitch — Clef speaks about
    a fifth above Piper and that separation is deliberate character
    design. A flat scalar gain (what this script and
    normalize_loudness.process_file both do) cannot shift pitch; the one
    thing to avoid is resampling with a *rate* change disguised as
    something else. afconvert's resample here only changes the *sample*
    rate (e.g. 24kHz upload -> 44.1kHz library rate) to match existing
    playback speed/pitch, not the *content* rate — this is the ordinary,
    correct way to bring an upload to the library's format and does not
    retime or repitch the performance.

Usage:
    python3 tool/build_voice_lines.py --uploads-dir "/path/to/uploads" --apply
    python3 tool/build_voice_lines.py --uploads-dir "/path/to/uploads"   # measure only

Requires macOS's built-in `afconvert` and an ffmpeg binary (see
normalize_loudness.find_ffmpeg's docstring for how one gets located).
"""
from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from normalize_loudness import find_ffmpeg, process_file

VOICE_TARGET_LUFS = -18.6
# Derived from the data, not picked upfront — a first attempt at -14.0
# (chosen only to sit above the note library's -18.0) left 8 of the 9
# lines headroom-limited and widened their spread instead of closing it.
# The right way to derive this: force every file to its true post-encode
# true-peak ceiling (run with an unreachably hot --target, e.g. +10, and
# read off each file's resulting "after" LUFS), then target the lowest of
# those ceilings *among files with no recording artifact* — one line
# (clefSaysHighSecond) has an isolated transient spike (a plosive pop/
# click, not its real vocal level) that drags its own ceiling far below
# the rest; excluding it, the lowest legitimate ceiling was ~-18.6,
# which then lets 8 of 9 files land within ~0.1 LU of each other. See
# assets/audio/voice/README.md for the full account, including that
# outlier. Re-derive (don't reuse this number unchanged) if the line-up
# changes — a new recording could easily have a lower or higher ceiling.

# Cooper's upload filename -> VoiceLine enum member it replaces/creates.
# "Second"-suffixed members are new: Clef/Piper each have a first-note
# narration line and a second-note continuation that joins the two into
# one sentence (e.g. "Ooh, that sounds high!" ... "...and that sounds
# low!") — see lib/audio/voice_line.dart's doc comments for the mapping
# rationale and the one line intentionally left unfilled
# (VoiceLine.listenForLow — no Piper recording exists for it yet).
UPLOAD_TO_VOICE_LINE = {
    "20bf64a5-Clef_ooh_that_sounds_high.wav": "clefSaysHigh",
    "75cb641e-Clef_and_ooh_that_sounds_high.wav": "clefSaysHighSecond",
    "1929972d-Clef_Give_me_the_High_One.wav": "putMeOnHigh",
    "5958aac0-Clef_ooh_listen_for_the_high_one.wav": "listenForHigh",
    "d2df3e58-Clef_ooh_nearly_listen_again.wav": "tryAgainClef",
    "8a3a543e-Piper_Fox_That_sounds_low.wav": "piperSaysLow",
    "e442de23-Piper_Fox_and_that_sounds_low.wav": "piperSaysLowSecond",
    "e00f0963-Piper_Fox_Give_me_the_Low_One.wav": "putMeOnLow",
    "74310ef0-Piper_Fox_Nearly_Have_another_listen.wav": "tryAgainPiper",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--uploads-dir", required=True, help="Directory containing the uploaded WAVs")
    parser.add_argument("--voice-dir", default=None, help="Output directory (default: <repo>/assets/audio/voice)")
    parser.add_argument("--target", type=float, default=VOICE_TARGET_LUFS, metavar="LUFS")
    parser.add_argument("--apply", action="store_true", help="Write the normalized mp3s (default: measure only)")
    parser.add_argument("--ffmpeg", default=None)
    args = parser.parse_args()

    uploads_dir = Path(args.uploads_dir)
    repo_root = Path(__file__).resolve().parent.parent
    voice_dir = Path(args.voice_dir) if args.voice_dir else repo_root / "assets" / "audio" / "voice"

    ffmpeg = args.ffmpeg
    if args.apply and ffmpeg is None:
        try:
            ffmpeg = find_ffmpeg()
        except RuntimeError as e:
            print(f"ERROR: {e}", file=sys.stderr)
            sys.exit(1)

    missing = [name for name in UPLOAD_TO_VOICE_LINE if not (uploads_dir / name).exists()]
    if missing:
        print("ERROR: missing uploads:", file=sys.stderr)
        for m in missing:
            print(f"  {m}", file=sys.stderr)
        sys.exit(1)

    reports = []
    with tempfile.TemporaryDirectory(prefix="build_voice_lines_") as tmp:
        work_dir = Path(tmp)
        for upload_name, voice_line in UPLOAD_TO_VOICE_LINE.items():
            src = uploads_dir / upload_name
            dst = voice_dir / f"{voice_line}.mp3"
            r = process_file(
                dst, work_dir, args.target if args.apply else None, ffmpeg,
                whole_clip=True, src_path=src, group="voice",
            )
            reports.append((upload_name, voice_line, r))

    print(f"{'upload':45s} {'VoiceLine':20s} {'LUFS before':>12s} {'peak before':>12s}")
    for upload_name, voice_line, r in reports:
        lufs_str = f"{r.lufs_before:.2f}" if r.lufs_before is not None else "n/a"
        print(f"{upload_name[:45]:45s} {voice_line:20s} {lufs_str:>12s} {r.peak_before:>10.2f}dB")
        if args.apply:
            lufs_after = f"{r.lufs_after:.2f}" if r.lufs_after is not None else "n/a"
            limited = "  ** HEADROOM-LIMITED **" if r.headroom_limited else ""
            print(f"  -> gain={r.gain_db:+.2f}dB  after LUFS={lufs_after}  "
                  f"peak_after={r.peak_after:.2f}dBFS  truepeak_after={r.true_peak_after:.2f}dBTP{limited}")

    valid = [r.lufs_before for _, _, r in reports if r.lufs_before is not None]
    if valid:
        print(f"\nLUFS spread before: {max(valid) - min(valid):.1f}dB "
              f"(min {min(valid):.2f}, max {max(valid):.2f})")

    print("\nNot mapped to any recording (left as a gap, per Cooper):")
    print("  VoiceLine.listenForLow — no Piper 'listen for the low one' recording exists yet")

    if not args.apply:
        print("\n(measure-only run — pass --apply to write the normalized mp3s)")


if __name__ == "__main__":
    main()

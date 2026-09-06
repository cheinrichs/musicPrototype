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

Cross-batch reality (Cooper): every recording batch will differ — he
records against a free Gemini credit allowance and comes back in a fresh
session once it runs out, sometimes with just one replacement line
rather than a full set. UPLOAD_TO_VOICE_LINE below is therefore an
append-only historical log, not a fixed manifest: add an entry per file
as it's delivered, across however many sessions that takes. Pointing
--uploads-dir at a folder that only has some of the mapped files is the
normal case, not an error — this script processes whatever's present
there and reports the rest as simply not found in *this* directory
(check an earlier delivery's folder for them, or note the discrepancy
if a file that should still exist has gone missing).

Usage:
    # Whatever's present in this batch's folder, at the standing target:
    python3 tool/build_voice_lines.py --uploads-dir "/path/to/uploads" --apply

    # Just the one new line dropped in later, from wherever it landed —
    # doesn't require the rest of the historical uploads to be reachable:
    python3 tool/build_voice_lines.py --file "/path/to/new_take.wav" \\
        --voice-line listenForLow --apply

    # Measure without writing anything (omit --apply) to sanity-check a
    # new file's own headroom ceiling against the standing target before
    # committing to it — see the WARNING this prints if the file can't
    # reach VOICE_TARGET_LUFS without limiting, which is exactly the
    # "next batch turns out louder/quieter than this one" case to watch
    # for as more lines arrive over time.

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
# those ceilings *among files with no recording defect* (see
# assets/audio/voice/README.md — one 2026-09 line was investigated for a
# suspected click and turned out to be genuine vocal emphasis on closer
# inspection, so nothing was excluded from that batch after all; the
# principle — a real defect can be excluded from the derivation, a loud
# performance choice can't — still stands for whatever the next batch
# turns up). This produced -18.6 for the nine 2026-09 lines, landing 8 of
# 9 within ~0.1 LU of each other. Re-derive (don't reuse this number
# unchanged) whenever a new file's own ceiling sits below it — see the
# WARNING this script prints when that happens.

# Cooper's upload filename -> VoiceLine enum member it replaces/creates.
# Append-only historical log across delivery sessions — see the "cross-
# batch reality" section of the module docstring. Two 2026-09 members are
# new (not replacements): Clef/Piper each got a first-note narration line
# and a second-note continuation that joins the two into one sentence
# (e.g. "Ooh, that sounds high!" ... "...and that sounds low!") — see
# lib/audio/voice_line.dart's doc comments for the mapping rationale.
UPLOAD_TO_VOICE_LINE = {
    # 2026-09 batch (nine lines)
    "20bf64a5-Clef_ooh_that_sounds_high.wav": "clefSaysHigh",
    "75cb641e-Clef_and_ooh_that_sounds_high.wav": "clefSaysHighSecond",
    "1929972d-Clef_Give_me_the_High_One.wav": "putMeOnHigh",
    "5958aac0-Clef_ooh_listen_for_the_high_one.wav": "listenForHigh",
    "d2df3e58-Clef_ooh_nearly_listen_again.wav": "tryAgainClef",
    "8a3a543e-Piper_Fox_That_sounds_low.wav": "piperSaysLow",
    "e442de23-Piper_Fox_and_that_sounds_low.wav": "piperSaysLowSecond",
    "e00f0963-Piper_Fox_Give_me_the_Low_One.wav": "putMeOnLow",
    "74310ef0-Piper_Fox_Nearly_Have_another_listen.wav": "tryAgainPiper",
    # Earlier take, confirmed usable by Cooper despite predating the 2026-09
    # batch ("there's nothing wrong with the listen for the low one line
    # ... that line is fine for use") — same 24kHz source format, measured
    # fundamental (108Hz) sits inside the 2026-09 Piper lines' own range
    # (106-142Hz), so it's a plausible match for the same character/session
    # family even though it arrived separately.
    "3d4ecc4c-Piper_Fox_Listen_for_the_Low_One.wav": "listenForLow",
}


def resolve_targets(args) -> list[tuple[Path, str]]:
    """Returns [(source_path, voice_line_name), ...] for this run."""
    if args.file:
        if not args.voice_line:
            raise SystemExit("--file requires --voice-line")
        return [(Path(args.file), args.voice_line)]

    uploads_dir = Path(args.uploads_dir)
    found = []
    not_here = []
    for upload_name, voice_line in UPLOAD_TO_VOICE_LINE.items():
        path = uploads_dir / upload_name
        if path.exists():
            found.append((path, voice_line))
        else:
            not_here.append(upload_name)
    if not_here:
        print(f"({len(not_here)} mapped upload(s) not in this directory — "
              f"normal if they came from an earlier delivery session):")
        for name in not_here:
            print(f"  {name}")
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src_group = parser.add_mutually_exclusive_group(required=True)
    src_group.add_argument("--uploads-dir", help="Directory to scan for any known mapped upload filenames")
    src_group.add_argument("--file", help="A single source WAV, paired with --voice-line")
    parser.add_argument("--voice-line", help="VoiceLine enum name --file should become (required with --file)")
    parser.add_argument("--voice-dir", default=None, help="Output directory (default: <repo>/assets/audio/voice)")
    parser.add_argument("--target", type=float, default=VOICE_TARGET_LUFS, metavar="LUFS")
    parser.add_argument("--apply", action="store_true", help="Write the normalized mp3s (default: measure only)")
    parser.add_argument("--ffmpeg", default=None)
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    voice_dir = Path(args.voice_dir) if args.voice_dir else repo_root / "assets" / "audio" / "voice"

    ffmpeg = args.ffmpeg
    if args.apply and ffmpeg is None:
        try:
            ffmpeg = find_ffmpeg()
        except RuntimeError as e:
            print(f"ERROR: {e}", file=sys.stderr)
            sys.exit(1)

    targets = resolve_targets(args)
    if not targets:
        print("Nothing to do — no mapped uploads found in that directory.", file=sys.stderr)
        sys.exit(1)

    reports = []
    with tempfile.TemporaryDirectory(prefix="build_voice_lines_") as tmp:
        work_dir = Path(tmp)
        for src, voice_line in targets:
            dst = voice_dir / f"{voice_line}.mp3"
            r = process_file(
                dst, work_dir, args.target if args.apply else None, ffmpeg,
                whole_clip=True, src_path=src, group="voice",
            )
            reports.append((src.name, voice_line, r))

    print(f"\n{'upload':45s} {'VoiceLine':20s} {'LUFS before':>12s} {'peak before':>12s}")
    for upload_name, voice_line, r in reports:
        lufs_str = f"{r.lufs_before:.2f}" if r.lufs_before is not None else "n/a"
        print(f"{upload_name[:45]:45s} {voice_line:20s} {lufs_str:>12s} {r.peak_before:>10.2f}dB")
        if args.apply:
            lufs_after = f"{r.lufs_after:.2f}" if r.lufs_after is not None else "n/a"
            limited = "  ** HEADROOM-LIMITED — did not reach target, see below **" if r.headroom_limited else ""
            print(f"  -> gain={r.gain_db:+.2f}dB  after LUFS={lufs_after}  "
                  f"peak_after={r.peak_after:.2f}dBFS  truepeak_after={r.true_peak_after:.2f}dBTP{limited}")
            if r.headroom_limited:
                print(f"  WARNING: {voice_line} could not reach {args.target:.1f} LUFS without exceeding "
                      f"true-peak headroom. It now sits {args.target - r.lufs_after:.2f} LU below every "
                      f"file that did reach target — re-derive VOICE_TARGET_LUFS (see this script's "
                      f"docstring) if that's a bigger gap than expected for this file's content.")

    valid = [r.lufs_before for _, _, r in reports if r.lufs_before is not None]
    if len(valid) > 1:
        print(f"\nLUFS spread before (this run's files only): {max(valid) - min(valid):.2f} LU "
              f"(min {min(valid):.2f}, max {max(valid):.2f})")

    if args.apply:
        after_vals = [r.lufs_after for _, _, r in reports if r.lufs_after is not None]
        if len(after_vals) > 1:
            print(f"LUFS spread after (this run's files only): {max(after_vals) - min(after_vals):.2f} LU "
                  f"(min {min(after_vals):.2f}, max {max(after_vals):.2f})")

    mapped_lines = set(UPLOAD_TO_VOICE_LINE.values())
    print(f"\nVoiceLine members with no recording in the historical log above: "
          f"check lib/audio/voice_line.dart's enum against {sorted(mapped_lines)} "
          f"for any not yet listed there.")

    if not args.apply:
        print("\n(measure-only run — pass --apply to write the normalized mp3s)")


if __name__ == "__main__":
    main()

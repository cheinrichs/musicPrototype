#!/usr/bin/env python3
"""Measure the real fundamental frequency of every note sample under
assets/audio/notes/ and report which note name it actually sounds like.

Why this exists: the pitch label on a sample file (its filename, e.g.
c4.mp3) is a claim, not a fact. Trello card 55's guitar/tuba work found a
label that had been wrong since the instrument's original commit and
survived undetected for months because nobody had measured the audio
directly — every "fix" up to that point reasoned about the label instead
of the waveform. This script is the fix for that: it decodes each file and
estimates its fundamental by autocorrelation, so mislabeled samples show up
as a number instead of a plausible-sounding guess.

Usage:
    python3 tool/measure_note_pitch.py                  # measure everything
    python3 tool/measure_note_pitch.py assets/audio/notes/guitar
    python3 tool/measure_note_pitch.py --json out.json   # also write JSON
    python3 tool/measure_note_pitch.py --verify-chromatic [dirs...]
    python3 tool/measure_note_pitch.py --verify-labels [dirs...]

Requires macOS's built-in `afconvert` (Xcode Command Line Tools) to decode
mp3 -> PCM WAV. Everything else is Python standard library — no pip
packages, so this runs on any dev machine that can already build this
project's iOS target, without extra setup.

Two known failure modes, both hit for real during this tool's two audits
so far (guitar/tuba transposition, then bells/oboe/violin) — see the
"SUSPECT" flags this script's default mode prints, and use
--verify-chromatic / --verify-labels rather than trusting a single
autocorrelation number for anything that looks octave-off:

1. Naive "what's the single strongest periodicity in this file"
   autocorrelation can report a real but non-fundamental partial instead
   of the one a person would name the note by. This isn't always a bug in
   the *measurement* — for bells specifically, it's genuine physics: a
   struck bell's loudest partial ("nominal") sits a real octave above the
   partial it's conventionally *named* by ("prime"/strike note), so a
   "find the strongest periodicity" detector will systematically prefer
   nominal over prime. --verify-labels is the check that resolves this:
   it looks for genuine periodicity *at the labelled pitch specifically*,
   regardless of whether it's the file's single strongest component — see
   [verify_label_periodicity]. This is how bells' widespread "+12
   semitones" flag (2026-09) turned out to be a false positive for 23 of
   its 24 files, not a mislabeling.
2. A short analysis window can occasionally make a real fundamental and a
   comparably-strong harmonic swap places in strength by noise alone —
   this genuinely happened during the 2026-09 audit (oboe/d5.mp3,
   violin/c4.mp3 both flagged wrongly under a ~2/3-second window; both
   read cleanly correct once measured over the note's full duration).
   [normalized_autocorrelation_peak] now uses (almost) the whole note for
   exactly this reason — see its docstring — but a borderline case is
   still worth double-checking with --verify-labels before trusting the
   default mode's single number.

A handful of files are also just bad recordings (clipped, silent, wrong
content, or genuinely ambiguous between two adjacent real notes) rather
than mislabeled — those read as low confidence or fail --verify-labels
outright, and should be reported for manual removal rather than
relabelled by algorithm. --verify-chromatic (checks that an instrument's
own files form a consistent chromatic scale, independent of any label —
see [verify_chromatic_structure]) is the primary safeguard against a
*systematic* measurement error slipping through a label comparison
undetected, but note it assumes one dominant pitch per file and so isn't
the right check for bells specifically (see [verify_label_periodicity]
above) — it will report a bells file as inconsistent with its neighbors
whenever one of the pair happens to measure by its nominal partial and
the other by its prime, even when both are correctly labelled.
"""

from __future__ import annotations

import argparse
import array
import json
import math
import re
import shutil
import subprocess
import sys
import tempfile
import wave
from dataclasses import dataclass, field
from pathlib import Path

SAMPLE_RATE = 44100
NOTE_NAMES = ['c', 'c_sharp', 'd', 'd_sharp', 'e', 'f', 'f_sharp', 'g',
              'g_sharp', 'a', 'a_sharp', 'b']
DISPLAY_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']

# The 24 canonical filenames every instrument directory has today, in
# chromatic (ascending-by-label) order. This is just a *reading* order —
# it says nothing about what the files actually sound like, which is the
# entire point of measuring them.
FILE_ORDER = []
for octave in (4, 5):
    for name in NOTE_NAMES:
        FILE_ORDER.append(f"{name}{octave}" if '_' not in name else f"{name}_{octave}")

MIN_FREQ_HZ = 45     # a bit below tuba's lowest real note (~65Hz)
MAX_FREQ_HZ = 1600   # a bit above the highest expected fundamental
MIN_CONFIDENCE = 0.35  # normalized-correlation floor before we call a reading "unusable"


def midi_to_name(midi: int) -> str:
    name = DISPLAY_NAMES[midi % 12]
    octave = midi // 12 - 1
    return f"{name}{octave}"


def freq_to_midi(freq: float) -> float:
    return 69 + 12 * math.log2(freq / 440.0)


def decode_to_wav(mp3_path: Path, wav_path: Path) -> None:
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", f"LEI16@{SAMPLE_RATE}", str(mp3_path), str(wav_path)],
        check=True, capture_output=True,
    )


def read_pcm16_mono(wav_path: Path) -> tuple[array.array, int]:
    with wave.open(str(wav_path), 'rb') as w:
        sr = w.getframerate()
        frames = w.readframes(w.getnframes())
    arr = array.array('h')
    arr.frombytes(frames)
    return arr, sr


def normalized_autocorrelation_peak(samples: array.array, sr: int) -> tuple[float | None, float]:
    """Return (frequency_hz, confidence) for the dominant periodicity in
    `samples`, or (None, 0.0) if nothing usable is found.

    Confidence is a 0..1 normalized correlation value. Among lags whose
    correlation is within 15% of the best one found, the *shortest* lag
    wins — this is the guard against reporting a subharmonic (half the
    true frequency) just because it accumulated slightly more raw energy.

    Uses (almost) the whole note, not a fixed sub-second window: an
    earlier version here used ~2/3s starting after the attack, which was
    short enough that a real fundamental and a comparably-strong harmonic
    could land within noise of each other, occasionally flipping which
    one "won" — this cost real files a false octave-error flag during
    the 2026-09 audit (oboe/d5.mp3, violin/c4.mp3: both measured cleanly
    correct once checked over the note's full duration; see that audit's
    report). More data straightforwardly means a better-conditioned
    correlation estimate, and normalized correlation is scale-invariant,
    so a quieter but genuine periodicity in the decaying tail doesn't get
    penalized for being quiet the way a raw-magnitude spectral peak would.
    """
    n = len(samples)
    if n < 200:
        return None, 0.0

    # Analysis window: skip just the attack transient, keep everything
    # after it (including the decay tail — see the "uses almost the whole
    # note" note above).
    start = n // 8
    chunk = samples[start:]
    m = len(chunk)
    if m < 200:
        return None, 0.0

    mean = sum(chunk) / m
    x = [s - mean for s in chunk]

    min_lag = max(2, sr // MAX_FREQ_HZ)
    max_lag = min(m // 2, sr // MIN_FREQ_HZ)
    if max_lag <= min_lag:
        return None, 0.0

    candidates: list[tuple[int, float]] = []
    for lag in range(min_lag, max_lag):
        span = m - lag
        if span < min_lag:
            break
        num = 0.0
        e0 = 0.0
        e1 = 0.0
        # Stride 2 keeps this fast enough for ~260 files without losing
        # meaningful precision at these sample rates/frequencies.
        for i in range(0, span, 2):
            a = x[i]
            b = x[i + lag]
            num += a * b
            e0 += a * a
            e1 += b * b
        denom = math.sqrt(e0 * e1)
        if denom <= 0:
            continue
        norm_corr = num / denom
        candidates.append((lag, norm_corr))

    if not candidates:
        return None, 0.0

    best_corr = max(c for _, c in candidates)
    if best_corr < MIN_CONFIDENCE:
        return None, best_corr

    # Only consider genuine local peaks (a lag whose correlation beats
    # both neighbors), so we're picking among real periodicity candidates
    # rather than every point on a rising slope.
    peaks = []
    for i in range(1, len(candidates) - 1):
        lag, corr = candidates[i]
        if corr >= candidates[i - 1][1] and corr >= candidates[i + 1][1]:
            peaks.append((lag, corr))
    if not peaks:
        peaks = candidates

    threshold = best_corr * 0.85
    strong_peaks = [(lag, corr) for lag, corr in peaks if corr >= threshold]
    if not strong_peaks:
        strong_peaks = peaks
    best_lag = min(strong_peaks, key=lambda lc: lc[0])[0]
    best_lag_corr = dict(strong_peaks)[best_lag]

    freq = sr / best_lag
    return freq, best_lag_corr


@dataclass
class Measurement:
    filename: str
    exists: bool = True
    freq_hz: float | None = None
    confidence: float = 0.0
    measured_midi: int | None = None
    measured_note: str | None = None
    cents_off: float | None = None
    error: str | None = None


def measure_file(mp3_path: Path, work_dir: Path) -> Measurement:
    m = Measurement(filename=mp3_path.name)
    wav_path = work_dir / (mp3_path.stem + ".wav")
    try:
        decode_to_wav(mp3_path, wav_path)
        samples, sr = read_pcm16_mono(wav_path)
        freq, confidence = normalized_autocorrelation_peak(samples, sr)
        m.confidence = confidence
        if freq is None:
            m.error = "no usable periodicity found (silent, noise, or too quiet)"
            return m
        m.freq_hz = freq
        exact_midi = freq_to_midi(freq)
        nearest_midi = round(exact_midi)
        m.measured_midi = nearest_midi
        m.measured_note = midi_to_name(nearest_midi)
        m.cents_off = round((exact_midi - nearest_midi) * 100, 1)
    except subprocess.CalledProcessError as e:
        m.error = f"afconvert failed: {e.stderr.decode(errors='replace')[:200]}"
    finally:
        wav_path.unlink(missing_ok=True)
    return m


@dataclass
class InstrumentSummary:
    dominant_offset: int | None
    agreement: float  # fraction of high-confidence files agreeing with dominant_offset
    high_confidence_count: int


def annotate_offset_agreement(measurements: list[Measurement], label_midis: list[int]) -> InstrumentSummary:
    """Report-only pass: flags each file's offset-from-label against the
    instrument's own dominant (mode) offset, but never rewrites a
    measurement. Earlier versions of this script auto-corrected outliers
    toward the mode — that's wrong whenever the *dominant* reading is
    itself the artifact (bells' inharmonic overtones reliably fool
    autocorrelation into reporting a clean +12 semitones on most files,
    which is exactly backwards: the minority readings are the honest
    ones there). Only a human, with instrument-specific reasoning, should
    decide which side of a disagreement to trust — this function just
    surfaces the disagreement.
    """
    from collections import Counter

    raw_offsets = [
        m.measured_midi - label_midi
        for m, label_midi in zip(measurements, label_midis)
        if m.measured_midi is not None and m.confidence >= 0.9
    ]
    if not raw_offsets:
        return InstrumentSummary(dominant_offset=None, agreement=0.0, high_confidence_count=0)

    mode_offset, mode_count = Counter(raw_offsets).most_common(1)[0]
    agreement = mode_count / len(raw_offsets)

    for m, label_midi in zip(measurements, label_midis):
        if m.measured_midi is None:
            continue
        raw_offset = m.measured_midi - label_midi
        if raw_offset != mode_offset:
            m.error = (m.error or "") + \
                f" [offset {raw_offset:+d} semitones vs. this instrument's dominant offset {mode_offset:+d} " \
                f"({mode_count}/{len(raw_offsets)} high-confidence files agree on {mode_offset:+d}) " \
                f"— needs a human call, not auto-correction]"

    return InstrumentSummary(dominant_offset=mode_offset, agreement=agreement,
                              high_confidence_count=len(raw_offsets))


def measure_instrument_dir(dir_path: Path, work_dir: Path) -> tuple[list[Measurement], InstrumentSummary]:
    results = []
    label_midis = []
    for filename in FILE_ORDER:
        mp3_path = dir_path / f"{filename}.mp3"
        label_midis.append(filename_implied_midi(filename))
        if not mp3_path.exists():
            results.append(Measurement(filename=f"{filename}.mp3", exists=False, error="file missing"))
            continue
        results.append(measure_file(mp3_path, work_dir))
    summary = annotate_offset_agreement(results, label_midis)
    return results, summary


def filename_implied_midi(filename_stem: str) -> int:
    """What MIDI number this file's *name* claims, per the app's existing
    c4/c_sharp_4/... convention (independent of what it actually sounds
    like)."""
    for i, name in enumerate(NOTE_NAMES):
        for octave in (4, 5):
            candidate = f"{name}{octave}" if '_' not in name else f"{name}_{octave}"
            if candidate == filename_stem:
                return (octave + 1) * 12 + i
    raise ValueError(f"unrecognized filename stem: {filename_stem}")


_GENERAL_NOTE_RE = re.compile(r'^([a-g])(_sharp)?_?(\d+)$')


def general_filename_midi(filename_stem: str) -> int | None:
    """Like [filename_implied_midi], but accepts *any* octave digit, not
    just 4/5 — needed once a file has been renamed to its real pitch
    (e.g. tuba's c2.mp3), which the fixed-octave version above can't
    parse. Returns None rather than raising for anything that doesn't
    look like a note filename at all.
    """
    m = _GENERAL_NOTE_RE.match(filename_stem)
    if not m:
        return None
    letter, sharp, octave_str = m.groups()
    name = letter + ('_sharp' if sharp else '')
    try:
        index = NOTE_NAMES.index(name)
    except ValueError:
        return None
    octave = int(octave_str)
    return (octave + 1) * 12 + index


# How far a measured interval's cents may drift from the mathematically
# exact 2^(n/12) before it's flagged. Loose enough for real acoustic
# recordings (individual notes measured up to ~35 cents from concert
# pitch elsewhere in this audit) but a small fraction of the 1200 cents a
# harmonic-lock octave error would produce, or even the 100+ cents a
# neighbor-note mixup would produce.
CHROMATIC_TOLERANCE_CENTS = 50

# How far off a note's label the closest genuine periodicity may sit
# before --verify-labels calls it SUSPECT rather than OK. Wider than
# CHROMATIC_TOLERANCE_CENTS (50c) because this checks a *narrowband*
# search around one specific frequency rather than a ratio between two
# measured values, and real single-note tuning drift on this library has
# run up to ~35 cents in isolated readings elsewhere in this audit.
LABEL_PERIODICITY_TOLERANCE_CENTS = 50
LABEL_PERIODICITY_MIN_CORRELATION = 0.9


def midi_to_freq(midi: int) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12.0)


@dataclass
class LabelCheckResult:
    filename: str
    label_note: str
    label_freq: float
    found_freq: float
    correlation: float
    cents_off: float
    ok: bool


def verify_label_periodicity(dir_path: Path, work_dir: Path) -> list[LabelCheckResult]:
    """Does the labelled pitch show genuine periodicity, regardless of
    whether it's the file's single strongest one? This is the check that
    resolved bells (2026-09): a struck bell's loudest partial (nominal)
    sits a real octave above the partial it's conventionally *named* by
    (prime/strike note), so [verify_chromatic_structure] and this
    script's default "strongest periodicity wins" mode both
    systematically favor nominal — but the labelled (prime) pitch is
    still genuinely, cleanly present in a good file. Normalized
    correlation is scale-invariant, so a real but quiet partial doesn't
    get penalized here the way a raw spectral-magnitude comparison would
    penalize it (an earlier pass at this used peak spectral magnitude and
    it was *not* discriminating enough — every bells file looked like the
    label was "basically absent" by that measure, even the 23 that turned
    out fine).

    Only usable on files this script's fixed-octave FILE_ORDER recognizes
    (i.e. not yet renamed to an arbitrary real octave) — pass a still-
    untouched instrument's directory, not e.g. guitar/tuba's post-rename
    state.
    """
    results = []
    for stem in FILE_ORDER:
        mp3_path = dir_path / f"{stem}.mp3"
        if not mp3_path.exists():
            continue
        label_midi = filename_implied_midi(stem)
        label_freq = midi_to_freq(label_midi)

        wav_path = work_dir / (mp3_path.stem + ".wav")
        decode_to_wav(mp3_path, wav_path)
        samples, sr = read_pcm16_mono(wav_path)
        wav_path.unlink(missing_ok=True)

        n = len(samples)
        start = n // 8
        window = samples[start:]
        m = len(window)
        if m < 200:
            results.append(LabelCheckResult(f"{stem}.mp3", midi_to_name(label_midi),
                                             label_freq, 0.0, 0.0, float('nan'), False))
            continue
        mean = sum(window) / m
        x = [s - mean for s in window]

        tol = LABEL_PERIODICITY_TOLERANCE_CENTS
        lo_lag = max(1, int(sr / (label_freq * 2 ** (tol / 1200))))
        hi_lag = int(sr / (label_freq * 2 ** (-tol / 1200)))
        best_lag, best_corr = None, -1.0
        for lag in range(lo_lag, hi_lag + 1):
            span = m - lag
            if span <= 0:
                break
            num = e0 = e1 = 0.0
            for i in range(0, span, 2):
                a, b = x[i], x[i + lag]
                num += a * b
                e0 += a * a
                e1 += b * b
            denom = math.sqrt(e0 * e1)
            corr = num / denom if denom > 0 else 0.0
            if corr > best_corr:
                best_lag, best_corr = lag, corr

        found_freq = sr / best_lag if best_lag else 0.0
        cents_off = 1200 * math.log2(found_freq / label_freq) if found_freq > 0 else float('nan')
        ok = best_corr > LABEL_PERIODICITY_MIN_CORRELATION and abs(cents_off) < tol
        results.append(LabelCheckResult(f"{stem}.mp3", midi_to_name(label_midi),
                                         label_freq, found_freq, best_corr, cents_off, ok))
    return results


@dataclass
class ChromaticCheckFailure:
    description: str
    cents_error: float


def verify_chromatic_structure(
    dir_path: Path, work_dir: Path
) -> tuple[list[tuple[str, float]], list[ChromaticCheckFailure]]:
    """The primary safeguard against a *systematic* measurement error —
    not just a single mislabeled file, but autocorrelation locking onto a
    harmonic consistently enough across an instrument that every file
    reads a clean octave off, which would make a label-vs-measurement
    check pass despite being wrong (this is exactly how the original
    guitar error could have been born, had it come from a measurement
    instead of a bad assumption).

    Checks the *internal* structure of an instrument's files instead of
    comparing each one to an assumed label: every file's name is parsed
    for its own claimed real pitch (general_filename_midi, so this works
    on both the untouched instruments and the ones renamed by this
    audit), the files are measured and sorted by that claimed pitch, and
    then:
      - every consecutive pair must sit at very close to the 2^(1/12)
        ratio their semitone gap implies (within
        CHROMATIC_TOLERANCE_CENTS), and
      - every pair exactly 12 semitones apart (by filename) must measure
        very close to an exact 2:1 ratio.
    A real chromatic scale satisfies both by construction; a systematic
    harmonic lock breaks the octave check outright, and a lock on any
    single file breaks its neighboring consecutive-ratio checks
    conspicuously. Nothing here is auto-corrected — failures are
    returned for the caller to report.
    """
    freqs: list[tuple[str, int, float]] = []  # (filename, midi, freq_hz)
    unparseable: list[str] = []
    for mp3_path in sorted(dir_path.glob("*.mp3")):
        stem = mp3_path.stem
        midi = general_filename_midi(stem)
        if midi is None:
            unparseable.append(mp3_path.name)
            continue
        m = measure_file(mp3_path, work_dir)
        if m.freq_hz is None:
            unparseable.append(f"{mp3_path.name} (unreadable: {m.error})")
            continue
        freqs.append((mp3_path.name, midi, m.freq_hz))

    freqs.sort(key=lambda t: t[1])
    failures: list[ChromaticCheckFailure] = []

    # Consecutive-pair check.
    for (name1, midi1, freq1), (name2, midi2, freq2) in zip(freqs, freqs[1:]):
        gap = midi2 - midi1
        if gap <= 0:
            continue
        expected_ratio = 2 ** (gap / 12)
        actual_ratio = freq2 / freq1
        cents_error = 1200 * math.log2(actual_ratio / expected_ratio)
        if abs(cents_error) > CHROMATIC_TOLERANCE_CENTS:
            failures.append(ChromaticCheckFailure(
                f"{name1} -> {name2} ({gap} semitone(s) apart by filename): "
                f"expected ratio {expected_ratio:.4f}, measured {actual_ratio:.4f} "
                f"({freq1:.2f}Hz -> {freq2:.2f}Hz)",
                cents_error,
            ))

    # Exact-octave check, across every pair (not just consecutive ones —
    # this is the direct test for a systematic whole-instrument lock,
    # which the consecutive-pair check would only catch indirectly via
    # accumulated small errors).
    by_midi = {midi: (name, freq) for name, midi, freq in freqs}
    for name1, midi1, freq1 in freqs:
        midi2 = midi1 + 12
        if midi2 not in by_midi:
            continue
        name2, freq2 = by_midi[midi2]
        actual_ratio = freq2 / freq1
        cents_error = 1200 * math.log2(actual_ratio / 2.0)
        if abs(cents_error) > CHROMATIC_TOLERANCE_CENTS:
            failures.append(ChromaticCheckFailure(
                f"{name1} -> {name2} (octave apart by filename): "
                f"expected ratio 2.0000, measured {actual_ratio:.4f} "
                f"({freq1:.2f}Hz -> {freq2:.2f}Hz)",
                cents_error,
            ))

    if unparseable:
        for u in unparseable:
            failures.append(ChromaticCheckFailure(f"could not measure/parse: {u}", float('nan')))

    return [(name, freq) for name, _, freq in freqs], failures


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("dirs", nargs="*", default=None,
                         help="Instrument directories to measure (default: all of assets/audio/notes/*)")
    parser.add_argument("--json", metavar="PATH", help="Also write full results as JSON to this path")
    parser.add_argument(
        "--verify-chromatic", action="store_true",
        help="Run the chromatic-structure safeguard instead of the label-vs-measurement "
             "report: checks that each instrument's own files form a consistent chromatic "
             "scale (consecutive semitones at 2^(1/12), octaves at exactly 2:1), which a "
             "systematic measurement error (e.g. autocorrelation locking onto a harmonic "
             "across a whole instrument) would break even though a label-vs-measurement "
             "comparison could not catch it (see this module's docstring). Works on any "
             "filename octave, so it's the right check to run after a rename. Not the right "
             "check for bells specifically — see --verify-labels and this module's docstring.",
    )
    parser.add_argument(
        "--verify-labels", action="store_true",
        help="Check whether each file's *labelled* pitch shows genuine periodicity, "
             "regardless of whether it's the file's single strongest one (see "
             "verify_label_periodicity's docstring — this is what resolved bells: its "
             "loudest partial is real but sits an octave above the one it's named by). "
             "Only works on files still using the fixed-octave c4/c5-style naming "
             "(pre-rename) — not guitar/tuba's current real-pitch filenames.",
    )
    args = parser.parse_args()

    if shutil.which("afconvert") is None:
        print("ERROR: afconvert not found. This script decodes mp3 via macOS's "
              "built-in afconvert (Xcode Command Line Tools) — install those "
              "and try again.", file=sys.stderr)
        sys.exit(1)

    repo_root = Path(__file__).resolve().parent.parent
    notes_root = repo_root / "assets" / "audio" / "notes"

    if args.dirs:
        dirs = [Path(d) for d in args.dirs]
    else:
        dirs = sorted(p for p in notes_root.iterdir() if p.is_dir())

    if args.verify_chromatic:
        overall_ok = True
        with tempfile.TemporaryDirectory(prefix="measure_note_pitch_") as tmp:
            work_dir = Path(tmp)
            for d in dirs:
                print(f"\n=== {d.name} (chromatic structure check) ===")
                freqs, failures = verify_chromatic_structure(d, work_dir)
                print(f"  {len(freqs)} files measured, sorted by filename-implied real pitch")
                if not failures:
                    print("  PASS — every consecutive pair and every octave pair checked out")
                else:
                    overall_ok = False
                    for f in failures:
                        cents_str = "n/a" if math.isnan(f.cents_error) else f"{f.cents_error:+.0f}c"
                        print(f"  FAIL ({cents_str}): {f.description}")
        sys.exit(0 if overall_ok else 1)

    if args.verify_labels:
        overall_ok = True
        with tempfile.TemporaryDirectory(prefix="measure_note_pitch_") as tmp:
            work_dir = Path(tmp)
            for d in dirs:
                print(f"\n=== {d.name} (label periodicity check) ===")
                results = verify_label_periodicity(d, work_dir)
                for r in results:
                    status = "OK" if r.ok else "SUSPECT"
                    if not r.ok:
                        overall_ok = False
                    cents_str = "n/a" if math.isnan(r.cents_off) else f"{r.cents_off:+.0f}c"
                    print(f"  {r.filename:16s} label={r.label_note:4s} ({r.label_freq:7.2f}Hz)  "
                          f"found={r.found_freq:7.2f}Hz  corr={r.correlation:.4f}  "
                          f"cents_off={cents_str:>6s}  {status}")
        sys.exit(0 if overall_ok else 1)

    all_results: dict[str, list[Measurement]] = {}
    all_summaries: dict[str, InstrumentSummary] = {}
    with tempfile.TemporaryDirectory(prefix="measure_note_pitch_") as tmp:
        work_dir = Path(tmp)
        for d in dirs:
            print(f"\n=== {d.name} ===")
            results, summary = measure_instrument_dir(d, work_dir)
            all_results[d.name] = results
            all_summaries[d.name] = summary
            for m in results:
                stem = m.filename.removesuffix(".mp3")
                try:
                    implied_midi = filename_implied_midi(stem)
                    implied_note = midi_to_name(implied_midi)
                except ValueError:
                    implied_midi, implied_note = None, "?"

                if not m.exists:
                    print(f"  {m.filename:16s} MISSING")
                    continue
                if m.measured_midi is None:
                    conf = f"{m.confidence:.2f}"
                    print(f"  {m.filename:16s} label={implied_note:4s} "
                          f"SUSPECT: unreadable (confidence {conf}) {m.error or ''}")
                    continue

                offset = m.measured_midi - implied_midi if implied_midi is not None else None
                flag = ""
                if offset is not None and offset != 0:
                    flag = f"  ** offset {offset:+d} semitones **"
                if m.error:
                    flag += f"  SUSPECT: {m.error}"
                if m.confidence < 0.55:
                    flag += f"  (low confidence {m.confidence:.2f})"

                print(f"  {m.filename:16s} label={implied_note:4s} -> measured={m.measured_note:4s} "
                      f"({m.freq_hz:7.2f}Hz, {m.cents_off:+.0f}c, conf={m.confidence:.2f}){flag}")

            s = all_summaries[d.name]
            if s.dominant_offset is not None:
                print(f"  --- dominant offset: {s.dominant_offset:+d} semitones "
                      f"({s.agreement * 100:.0f}% of {s.high_confidence_count} high-confidence files agree) ---")

    if args.json:
        serializable = {
            inst: {
                "summary": {
                    "dominant_offset_semitones": all_summaries[inst].dominant_offset,
                    "agreement": all_summaries[inst].agreement,
                    "high_confidence_count": all_summaries[inst].high_confidence_count,
                },
                "files": [
                    {
                        "filename": m.filename,
                        "exists": m.exists,
                        "freq_hz": m.freq_hz,
                        "confidence": m.confidence,
                        "measured_midi": m.measured_midi,
                        "measured_note": m.measured_note,
                        "cents_off": m.cents_off,
                        "error": m.error,
                    }
                    for m in results
                ],
            }
            for inst, results in all_results.items()
        }
        Path(args.json).write_text(json.dumps(serializable, indent=2))
        print(f"\nWrote {args.json}")


if __name__ == "__main__":
    main()

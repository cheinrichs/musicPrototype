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
project's iOS target, without extra setup — with one narrow exception:
measuring a SPECTRAL_PEAK_INSTRUMENT_DIRS directory (currently just
bells) needs numpy for its FFT, imported lazily so nothing else in this
file takes on the dependency. Every other instrument stays exactly as
dependency-free as before.

Four known failure modes, all hit for real across this tool's audits so
far (guitar/tuba transposition, then bells/oboe/violin, then the 2026-09
handbell import) — see the "SUSPECT" flags this script's default mode
prints, and use --verify-chromatic / --verify-labels rather than
trusting a single autocorrelation number for anything that looks
octave-off:

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

3. A stereo (or any multi-channel) source silently corrupts every
   measurement if it isn't downmixed to mono first — [decode_to_wav] only
   pins sample rate/bit depth, not channel count, and reading interleaved
   L/R frames as a flat mono stream (a bug present until the 2026-09
   handbell import) doesn't error, it just measures garbage. The
   giveaway that caught it: *every* file in a stereo batch reading the
   same implausible frequency near this script's MAX_FREQ_HZ boundary
   regardless of the files' actual different pitches — real audio content
   doesn't do that; a format bug reading the same interleaving artifact
   in every file does. If a fresh source's numbers look suspiciously
   uniform, identical across files, or pinned near MIN_FREQ_HZ/
   MAX_FREQ_HZ, check `afinfo <file>`'s channel count before doubting the
   acoustics — see [read_pcm16_mono]'s docstring for the fix (a real
   channel average, not `afconvert -c 1`, which was tried and found to
   just drop every channel but the first).

4. A fixed search ceiling (MAX_FREQ_HZ) doesn't just miss a note pitched
   above it — it actively *mismeasures* it, since autocorrelation can
   only report a periodicity whose lag corresponds to a frequency within
   that ceiling. The 2026-09 handbell import needed MAX_FREQ_HZ raised
   from 1600 to 2150 (bells reach real B6, ~1976Hz) for exactly this
   reason: several files below the old ceiling kept reading a real
   octave low, structurally unable to ever report their true pitch until
   the ceiling was raised past it, not just prone to drift there. If a
   fresh source's readings cluster suspiciously near MIN_FREQ_HZ or
   MAX_FREQ_HZ, check whether the true pitch might simply be outside the
   search range before suspecting the acoustics.

A handful of files are also just bad recordings (clipped, silent, wrong
content, or genuinely ambiguous between two adjacent real notes) rather
than mislabeled — those read as low confidence or fail --verify-labels
outright, and should be reported for manual removal rather than
relabelled by algorithm. One 2026-09 handbell file looked like exactly
this at first (a hard-clipped attack, ~0.5ms at the exact int16 rail)
but turned out fine once measured past the clip — worth a second,
narrower look before writing off a file the clipping alone would
suggest excluding.

--verify-chromatic (checks that an instrument's own files form a
consistent chromatic scale, independent of any label — see
[verify_chromatic_structure]) is the primary safeguard against a
*systematic* measurement error slipping through a label comparison
undetected, but note it assumes one dominant pitch per file and so isn't
the right check for the *old* bells set specifically (see
[verify_label_periodicity] above, and SPECTRAL_PEAK_INSTRUMENT_DIRS for
why the *current*, 2026-09 hand-bell set needs a different fix again) —
it will report a bells file as inconsistent with its neighbors
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
# A bit above the highest expected fundamental — raised from 1600 to 2150
# for the 2026-09 handbell import: bells reach up to real B6 (~1976Hz),
# and a search ceiling below a file's true pitch doesn't just miss it, it
# actively mismeasures it. autocorrelation can only ever report a
# periodicity whose lag is >= sr/MAX_FREQ_HZ, so at the old 1600Hz ceiling
# the several bells tuned above that point were structurally incapable of
# ever reading their own real strike note — the search would find
# whatever real periodicity *was* in range instead, which for a bell is
# often its hum tone one octave down. That's not a coincidence with why
# the whole-note reading kept landing an octave low on exactly the
# higher-pitched bells (see OCTAVE_AMBIGUOUS_INSTRUMENT_DIRS): a bit of
# it was genuine partial-dominance drift, but a bit of it was this
# ceiling silently ruling out the correct answer before the algorithm
# ever got a chance to consider it.
MAX_FREQ_HZ = 2150
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
    """Read 16-bit PCM samples as mono, downmixing if the source has more
    than one channel.

    [decode_to_wav] only pins sample rate/bit depth (`-d LEI16@...`), not
    channel count, so a genuinely multi-channel source passes through
    unchanged. Every asset this tool measured before 2026-09 (the
    Philharmonia-derived note library) happened to already be mono, so
    reading the decoded frames as a flat stream — the previous
    implementation — never surfaced this. It broke on the first
    non-orchestral source: InspectorJ's handbell field recordings on
    Freesound are stereo, and treating their interleaved L/R frames as one
    mono stream corrupted every measurement, producing an identical,
    spurious ~1575Hz reading across many *different* files regardless of
    their real pitch — a dead giveaway of a format bug, not an acoustic
    one, since real bells don't all ring the same note.

    Averages channels rather than dropping any: `afconvert -c 1` was
    tried first and rejected after direct sample comparison showed it
    just keeps channel 0 and discards the rest, not a real mix — silently
    picking one mic over another rather than combining them.
    """
    with wave.open(str(wav_path), 'rb') as w:
        sr = w.getframerate()
        nchannels = w.getnchannels()
        frames = w.readframes(w.getnframes())
    raw = array.array('h')
    raw.frombytes(frames)
    if nchannels <= 1:
        return raw, sr
    channels = [raw[ch::nchannels] for ch in range(nchannels)]
    mono = array.array('h', (sum(s) // nchannels for s in zip(*channels)))
    return mono, sr


def normalized_autocorrelation_peak(
    samples: array.array, sr: int
) -> tuple[float | None, float]:
    """Return (frequency_hz, confidence) for the dominant periodicity in
    `samples`, or (None, 0.0) if nothing usable is found.

    Confidence is a 0..1 normalized correlation value. Among lags whose
    correlation is within 15% of the best one found, the *shortest* lag
    wins — this is the guard against reporting a subharmonic (half the
    true frequency) just because it accumulated slightly more raw energy.

    Uses (almost) the whole note, not a fixed sub-second window: an
    earlier version here used ~2/3s starting after the attack, which was
    short enough that a real fundamental and a comparably-strong
    harmonic could land within noise of each other, occasionally
    flipping which one "won" — this cost real files a false octave-error
    flag during the 2026-09 audit (oboe/d5.mp3, violin/c4.mp3: both
    measured cleanly correct once checked over the note's full duration;
    see that audit's report). More data straightforwardly means a
    better-conditioned correlation estimate, and normalized correlation
    is scale-invariant, so a quieter but genuine periodicity in the
    decaying tail doesn't get penalized for being quiet the way a
    raw-magnitude spectral peak would.

    A tempting-looking fix for plucked strings (whose fundamental decays
    faster than its harmonics) was tried and reverted: analyzing only a
    short window right after the attack, on the theory that catching the
    fundamental before it fades would stop a harmonic from winning late.
    In practice that window landed on pluck/finger noise for most guitar
    files and returned pure garbage (e.g. d_sharp_3.mp3 measuring
    ~1520Hz) — worse than the problem it targeted, which affected only
    one or two files. See OCTAVE_AMBIGUOUS_INSTRUMENT_DIRS below for the actual
    fix: an octave-tolerant *comparison* in the chromatic check, which
    doesn't touch detection at all.
    """
    n = len(samples)
    if n < 200:
        return None, 0.0

    # Skip just the attack transient, keep everything after it
    # (including the decay tail — see the "uses almost the whole note"
    # note above).
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


# Directories measured by [spectral_peak] instead of the default
# [normalized_autocorrelation_peak] — currently just hand bells (2026-09
# InspectorJ import). Not a general replacement; see spectral_peak's
# docstring for why bells specifically need a different *method*, not
# just a different window on the same one.
SPECTRAL_PEAK_INSTRUMENT_DIRS = {"bells"}


def spectral_peak(
    samples: array.array, sr: int, start_s: float = 0.05, window_s: float = 1.0
) -> tuple[float | None, float]:
    """Return (frequency_hz, confidence) for the dominant FFT peak in a
    window starting [start_s] seconds in and [window_s] seconds long.
    Used only for [SPECTRAL_PEAK_INSTRUMENT_DIRS] (hand bells) — every
    other instrument still uses [normalized_autocorrelation_peak].

    Why bells need an entirely different method, not just a different
    window on the same one (which is all guitar needed —
    OCTAVE_AMBIGUOUS_INSTRUMENT_DIRS's comparison-side tolerance covers
    guitar's plucked-string decay drift because that drift is *clean*:
    late in the note, a harmonic outweighs the fundamental by exactly an
    octave, consistently). A struck hand bell has several inharmonic
    partials decaying at their own different rates, and which one
    dominates keeps shifting throughout the note — verified directly on
    the 2026-09 InspectorJ import: --verify-chromatic's whole-note
    autocorrelation reading disagreed with a careful by-hand FFT check on
    most of the 13 files, by amounts that don't fit a clean octave
    relationship (108c, 749c, 96c, 1405c, ... — not ~0c or ~1200c), so
    the octave-tolerant comparison can't paper over it the way it does
    for guitar. A fixed early window sidesteps this because the strike's
    initial ring is dominated by one clear partial (the "note you hear")
    before the others have had time to compete — confirmed empirically:
    every one of the 12 well-tuned files read a single, overwhelmingly
    dominant peak (usually >90% stronger than the next-loudest) in this
    window, forming an internally consistent chromatic scale within a
    few cents per step.

    Also avoids normalized_autocorrelation_peak's own failure mode at
    short windows: its "shortest lag among near-ties wins" rule (the
    guard against reporting a subharmonic) can pick a spurious
    short-lag artifact when several partials are comparably strong —
    exactly bells' situation, and exactly what made a short-window
    *autocorrelation* attempt fail for guitar too (see
    normalized_autocorrelation_peak's docstring). A spectral peak just
    picks the tallest bin; it has no such tie-break to go wrong.

    Requires numpy, imported lazily so nothing else in this file takes on
    the dependency — every other measurement in this tool is pure
    standard library.
    """
    try:
        import numpy as np
    except ImportError as e:
        raise RuntimeError(
            "Measuring a SPECTRAL_PEAK_INSTRUMENT_DIRS directory (bells) "
            "needs numpy for its FFT-based pitch measurement — install it "
            "(`pip install numpy`) and try again. No other instrument in "
            "this tool needs it."
        ) from e

    arr = np.asarray(samples, dtype=np.float64)
    start = int(sr * start_s)
    end = min(len(arr), start + int(sr * window_s))
    chunk = arr[start:end]
    if len(chunk) < sr * 0.05:
        return None, 0.0

    spectrum = np.abs(np.fft.rfft(chunk * np.hanning(len(chunk))))
    freqs = np.fft.rfftfreq(len(chunk), d=1 / sr)
    mask = (freqs >= MIN_FREQ_HZ) & (freqs <= MAX_FREQ_HZ)
    f = freqs[mask]
    m = spectrum[mask]
    if len(m) < 3:
        return None, 0.0

    # Local maxima only — same reasoning as normalized_autocorrelation_peak:
    # pick among genuine peaks, not every point on a rising slope.
    peak_indices = [
        i for i in range(1, len(m) - 1) if m[i] > m[i - 1] and m[i] >= m[i + 1]
    ]
    if not peak_indices:
        return None, 0.0
    best_i = max(peak_indices, key=lambda i: m[i])
    best_freq = float(f[best_i])
    best_mag = float(m[best_i])

    # Confidence proxy: how dominant the best peak is over the next-
    # strongest one. Not the same math as normalized_autocorrelation_peak's
    # normalized-correlation confidence, but the same 0..1 scale and
    # meaning (1.0 = totally dominant, no real competition).
    others = sorted((float(m[i]) for i in peak_indices if i != best_i), reverse=True)
    second = others[0] if others else 0.0
    confidence = 1.0 - (second / best_mag if best_mag > 0 else 0.0)
    return best_freq, max(0.0, min(1.0, confidence))


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


# Instruments with a real, physically-explained reason a whole-note pitch
# read can land a genuine octave away from the note a person would name —
# not a measurement bug, an acoustic property of the instrument. Keyed by
# the instrument directory name under assets/audio/notes/. Used only to
# gate the octave-tolerant comparison in verify_chromatic_structure (see
# ratio_matches_with_octave_tolerance) — not a detection-side change; see
# normalized_autocorrelation_peak's docstring for why a detection-side
# fix (a short post-attack window) was tried for guitar and reverted.
#
# Two different causes land here, both producing the same octave-off
# symptom:
#   - guitar (plucked string): the fundamental decays measurably faster
#     than its harmonics, so a whole-note or late-note read can drift a
#     real octave *high* as the note dies.
#   - bells (struck handbell, 2026-09 InspectorJ import): tuned so the
#     hum tone — a real, audible partial — sits a genuine octave *below*
#     the strike note a listener actually identifies as "the note," and
#     which partial dominates a given analysis window shifts continuously
#     as the strike's other partials decay at their own different rates
#     (confirmed directly: an FFT comparison of an early ~1s window
#     against the later decay showed roughly half of the 12 real bells
#     landing on a clean octave-below reading once the strike's brighter
#     partials had faded — not a uniform, predictable shift, so no fixed
#     analysis window reliably avoids it the way it does for guitar).
OCTAVE_AMBIGUOUS_INSTRUMENT_DIRS = {"guitar", "bells"}


def measure_file(
    mp3_path: Path, work_dir: Path, use_spectral_peak: bool = False
) -> Measurement:
    m = Measurement(filename=mp3_path.name)
    wav_path = work_dir / (mp3_path.stem + ".wav")
    try:
        decode_to_wav(mp3_path, wav_path)
        samples, sr = read_pcm16_mono(wav_path)
        freq, confidence = (
            spectral_peak(samples, sr)
            if use_spectral_peak
            else normalized_autocorrelation_peak(samples, sr)
        )
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


# (instrument dir name, filename) -> why this specific file is allowed to
# fail the chromatic check without it meaning anything is wrong. This is
# for a documented, judged-acceptable pitch ambiguity in a *specific*
# file — not a general tolerance widening (that's what
# OCTAVE_AMBIGUOUS_INSTRUMENT_DIRS is for, a real acoustic correction rather than
# an exception). Add an entry only when a human has actually listened
# and made this call; a failure not listed here is a real failure.
KNOWN_ACCEPTABLE_DEVIATIONS: dict[tuple[str, str], str] = {
    ("tuba", "c_sharp_3.mp3"): (
        "Cooper, by ear against a pitch app: 'wiggles between C#3 and D3'. "
        "The game only compares real sounding pitch between two notes on "
        "the same instrument to decide which is higher, never names a "
        "note out loud — the tier ladder's narrowest interval is 4 "
        "semitones, so a 1-semitone ambiguity here can't flip which side "
        "of a pair reads higher. Restored (2026-09) after being pulled "
        "for measuring off-label; this is that same ambiguity, judged "
        "acceptable rather than fixed."
    ),
}


def ratio_matches_with_octave_tolerance(
    actual_ratio: float, expected_ratio: float, tol_cents: float
) -> tuple[bool, str | None]:
    """For [OCTAVE_AMBIGUOUS_INSTRUMENT_DIRS] only: checks [actual_ratio] against
    [expected_ratio] both directly and scaled by a real octave in either
    direction, returning (matched, note) — [note] says which side read
    the octave, or None if it matched directly with no drift at all.

    This is a comparison-side tolerance, not a detection-side one (see
    normalized_autocorrelation_peak's docstring for the detection-side
    fix that was tried and reverted). A plucked string's fundamental
    decays faster than its harmonics, so a whole-note read can lock onto
    a harmonic and measure one side of a pair a real octave off — Cooper
    confirmed this by ear against a pitch app on real guitar files
    (f_sharp_3.mp3 measuring an octave high was exactly this). Checking
    the ratio against 2x and 0.5x its expected value catches that
    specific, explained failure mode without loosening the check for
    anything else: a wrong-by-some-other-amount ratio still fails.
    """
    direct_cents = 1200 * math.log2(actual_ratio / expected_ratio)
    if abs(direct_cents) <= tol_cents:
        return True, None
    high_cents = 1200 * math.log2((actual_ratio / 2) / expected_ratio)
    if abs(high_cents) <= tol_cents:
        return True, "the second file read a real octave high"
    low_cents = 1200 * math.log2((actual_ratio * 2) / expected_ratio)
    if abs(low_cents) <= tol_cents:
        return True, "the first file read a real octave high"
    return False, None


@dataclass
class ChromaticCheckFailure:
    description: str
    cents_error: float
    accepted_reason: str | None = None


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

    For [OCTAVE_AMBIGUOUS_INSTRUMENT_DIRS] (currently just guitar), a ratio that
    misses the expected value is also checked against 2x and 0.5x that
    value before being called a real failure (see
    ratio_matches_with_octave_tolerance) — a plucked string's fundamental
    decays faster than its harmonics, so a whole-note read can lock onto
    a harmonic and measure one side of a pair a real octave off. This is
    a comparison-side tolerance, not a detection-side change for guitar.
    Bells (also in OCTAVE_AMBIGUOUS_INSTRUMENT_DIRS) get a real
    detection-side change on top of that — see SPECTRAL_PEAK_INSTRUMENT_DIRS
    and [spectral_peak]'s docstring for why guitar's comparison-only fix
    isn't enough for bells' messier, non-octave partial-dominance drift.
    """
    freqs: list[tuple[str, int, float]] = []  # (filename, midi, freq_hz)
    unparseable: list[str] = []
    use_spectral_peak = dir_path.name in SPECTRAL_PEAK_INSTRUMENT_DIRS
    for mp3_path in sorted(dir_path.glob("*.mp3")):
        stem = mp3_path.stem
        midi = general_filename_midi(stem)
        if midi is None:
            unparseable.append(mp3_path.name)
            continue
        m = measure_file(mp3_path, work_dir, use_spectral_peak=use_spectral_peak)
        if m.freq_hz is None:
            unparseable.append(f"{mp3_path.name} (unreadable: {m.error})")
            continue
        freqs.append((mp3_path.name, midi, m.freq_hz))

    freqs.sort(key=lambda t: t[1])
    failures: list[ChromaticCheckFailure] = []

    def known_reason(name1: str, name2: str) -> str | None:
        for n in (name1, name2):
            reason = KNOWN_ACCEPTABLE_DEVIATIONS.get((dir_path.name, n))
            if reason is not None:
                return reason
        return None

    # Consecutive-pair check.
    for (name1, midi1, freq1), (name2, midi2, freq2) in zip(freqs, freqs[1:]):
        gap = midi2 - midi1
        if gap <= 0:
            continue
        expected_ratio = 2 ** (gap / 12)
        actual_ratio = freq2 / freq1
        cents_error = 1200 * math.log2(actual_ratio / expected_ratio)
        if abs(cents_error) > CHROMATIC_TOLERANCE_CENTS:
            reason = known_reason(name1, name2)
            if reason is None and dir_path.name in OCTAVE_AMBIGUOUS_INSTRUMENT_DIRS:
                matched, note = ratio_matches_with_octave_tolerance(
                    actual_ratio, expected_ratio, CHROMATIC_TOLERANCE_CENTS
                )
                if matched:
                    reason = (
                        f"plucked-string octave drift ({note}): a plucked "
                        "string's fundamental decays faster than its "
                        "harmonics, so a whole-note read can lock onto a "
                        "harmonic and measure one side a real octave off — "
                        "see OCTAVE_AMBIGUOUS_INSTRUMENT_DIRS. The pitch relationship "
                        "checks out once that octave is accounted for."
                    )
            failures.append(ChromaticCheckFailure(
                f"{name1} -> {name2} ({gap} semitone(s) apart by filename): "
                f"expected ratio {expected_ratio:.4f}, measured {actual_ratio:.4f} "
                f"({freq1:.2f}Hz -> {freq2:.2f}Hz)",
                cents_error,
                accepted_reason=reason,
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
            reason = known_reason(name1, name2)
            if reason is None and dir_path.name in OCTAVE_AMBIGUOUS_INSTRUMENT_DIRS:
                matched, note = ratio_matches_with_octave_tolerance(
                    actual_ratio, 2.0, CHROMATIC_TOLERANCE_CENTS
                )
                if matched:
                    reason = (
                        f"plucked-string octave drift ({note}): a plucked "
                        "string's fundamental decays faster than its "
                        "harmonics, so a whole-note read can lock onto a "
                        "harmonic and measure one side a real octave off — "
                        "see OCTAVE_AMBIGUOUS_INSTRUMENT_DIRS. The pitch relationship "
                        "checks out once that octave is accounted for."
                    )
            failures.append(ChromaticCheckFailure(
                f"{name1} -> {name2} (octave apart by filename): "
                f"expected ratio 2.0000, measured {actual_ratio:.4f} "
                f"({freq1:.2f}Hz -> {freq2:.2f}Hz)",
                cents_error,
                accepted_reason=reason,
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
             "filename octave, so it's the right check to run after a rename. This is the "
             "current bells set's own check too (SPECTRAL_PEAK_INSTRUMENT_DIRS handles its "
             "measurement automatically) — --verify-labels below is for the *old*, "
             "fixed-octave-naming bells set specifically, not this one.",
    )
    parser.add_argument(
        "--verify-labels", action="store_true",
        help="Check whether each file's *labelled* pitch shows genuine periodicity, "
             "regardless of whether it's the file's single strongest one (see "
             "verify_label_periodicity's docstring — this is what resolved the *original* "
             "bells set's nominal-vs-prime question: its loudest partial was real but sat "
             "an octave above the one it was named by). Only works on files still using the "
             "fixed-octave c4/c5-style naming (pre-rename) — not guitar/tuba/the current "
             "bells set's real-pitch filenames.",
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
                real_failures = [f for f in failures if f.accepted_reason is None]
                accepted = [f for f in failures if f.accepted_reason is not None]
                if not failures:
                    print("  PASS — every consecutive pair and every octave pair checked out")
                elif not real_failures:
                    print(f"  PASS — {len(accepted)} documented exception(s), see below")
                else:
                    overall_ok = False
                for f in real_failures:
                    cents_str = "n/a" if math.isnan(f.cents_error) else f"{f.cents_error:+.0f}c"
                    print(f"  FAIL ({cents_str}): {f.description}")
                for f in accepted:
                    cents_str = "n/a" if math.isnan(f.cents_error) else f"{f.cents_error:+.0f}c"
                    print(f"  ACCEPTED ({cents_str}): {f.description}")
                    print(f"    -> {f.accepted_reason}")
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

#!/usr/bin/env python3
"""Measures Clef's H art (2026-11-20) for head-matched placement: for each
image (the three talking frames, thoughtful, celebrate), its drawn REGION
(alpha > 8, inside its SLICE_POINTS.json column), its BODY box on
near-opaque pixels (alpha > 200; the celebrate pose's glow reaches the
whole canvas at alpha > 0, so never measure her on alpha > 0), and her
HEAD CENTRE: the midpoint of her two eyes' white sclera.

Prints the numbers `CharacterArt.clef` (lib/games/high_low/widgets/
character_art.dart) records. The art is never re-saved: the app draws
these regions of the sheets as supplied.

Usage:  python3 -E tool/measure_clef_poses.py
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
CLEF = REPO / "assets" / "images" / "characters" / "clef"
MANIFEST = REPO / "assets" / "images" / "characters" / "instruments" / "SLICE_POINTS.json"


def measure(file: str, x0: int, x1: int) -> str:
    im = np.array(Image.open(CLEF / file).convert("RGBA")).astype(int)[:, x0:x1]
    a = im[..., 3]
    faint, body = a > 8, a > 200
    fy, fx = np.flatnonzero(faint.any(1)), np.flatnonzero(faint.any(0))
    by = np.flatnonzero(body.any(1))
    top, bot = by[0], by[-1] + 1
    h = bot - top
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    white = (r > 225) & (g > 225) & (b > 225) & body
    white[: top + int(0.35 * h)] = False
    white[top + int(0.75 * h):] = False
    ys, xs = np.nonzero(white)
    c = [xs.min(), xs.max()]
    for _ in range(20):
        lab = np.abs(xs[:, None] - np.array(c)[None]).argmin(1)
        c = [xs[lab == k].mean() for k in (0, 1)]
    eyes = sorted((xs[lab == k].mean(), ys[lab == k].mean()) for k in (0, 1))
    hx = (eyes[0][0] + eyes[1][0]) / 2 + x0
    hy = (eyes[0][1] + eyes[1][1]) / 2
    return (
        f"{file}: region ({x0 + fx[0]}, {fy[0]}, {fx[-1] - fx[0] + 1}, "
        f"{fy[-1] - fy[0] + 1})  body height {h}  head ({hx:.0f}, {hy:.0f})"
    )


def main() -> None:
    m = json.loads(MANIFEST.read_text())
    for file in ("clef_H_talk_x3.png",):
        w = m[file]["width"]
        cuts = [0, *m[file]["slices"], w]
        for i in range(3):
            print(measure(file, cuts[i], cuts[i + 1]))
    for file in ("clef_H_thoughtful.png", "clef_H_celebrate.png"):
        w = Image.open(CLEF / file).width
        print(measure(file, 0, w))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Prepare one single-image character pose (celebration, thinking, ...) so
it can be swapped with that character's mouth frames without the character
changing size.

The pose art ships on a big shared canvas (1024x1536) with the figure
floating inside it; the mouth frames (see slice_mouth_frames.py) are tight
crops at a smaller scale. To swap between them the app draws every image of a
character at one common scale, so this:

  1. crops the pose to its figure (alpha above a threshold), and
  2. scales it by 1/--scale, where --scale is how many pixels of pose art
     correspond to one pixel of mouth-frame art for the same body. Measure it
     once per character as (Hero pose body height) / (mouth frame body
     height), both taken on *solid* pixels so soft halos can't skew it.

Ground line: every prepared image is cropped to its own figure, so all of a
character's images share a bottom edge (their feet / lowest point) and the
app anchors them there.

Usage:
    python3 tool/prepare_character_pose.py POSE.png OUT.png --scale 1.631
    python3 tool/prepare_character_pose.py --self-test
"""

from __future__ import annotations

import argparse

import numpy as np
from PIL import Image

ALPHA_THRESHOLD = 10


def prepare(pose: Image.Image, scale: float) -> Image.Image:
    rgba = pose.convert("RGBA")
    alpha = np.array(rgba)[:, :, 3]
    ys, xs = np.where(alpha > ALPHA_THRESHOLD)
    cropped = rgba.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    w, h = cropped.size
    return cropped.resize((max(1, round(w / scale)), max(1, round(h / scale))), Image.LANCZOS)


def self_test() -> None:
    img = np.zeros((400, 300, 4), dtype=np.uint8)
    img[100:300, 50:150, 3] = 255  # a 100x200 figure floating on a bigger canvas
    out = prepare(Image.fromarray(img), 2.0)
    assert out.size == (50, 100), out.size
    # The figure fills the crop: no transparent margin left.
    a = np.array(out)[:, :, 3]
    assert a[0].max() > 0 and a[-1].max() > 0 and a[:, 0].max() > 0 and a[:, -1].max() > 0
    print("self-test passed (crop to figure, scale)")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pose", nargs="?")
    ap.add_argument("out", nargs="?")
    ap.add_argument("--scale", type=float)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        self_test()
        return
    if not (args.pose and args.out and args.scale):
        ap.error("POSE, OUT and --scale are required")
    out = prepare(Image.open(args.pose), args.scale)
    out.save(args.out, optimize=True)
    print(f"{args.out}: {out.size[0]}x{out.size[1]}")


if __name__ == "__main__":
    main()

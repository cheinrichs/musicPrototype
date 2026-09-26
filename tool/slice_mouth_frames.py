#!/usr/bin/env python3
"""Slice a character's three-frame mouth sheet (closed / open / wide) into
three separate, pixel-registered PNGs for the speaking indicator.

Why not just cut the sheet into thirds: the sheet's width (1774) isn't
divisible by three, and each frame's body sits at a slightly different x
within its tile (measured: frame 0's clef body sits ~14px right of frames
1 and 2). Swapping unregistered tiles would make the whole character jump
sideways every time the mouth opened — exactly the kind of registration
failure the rejected Piper sheet had (see SongStone-UI-Kit
Assets/Cast/README.md). So this aligns every frame to the middle frame by
maximising overlap of the *body* silhouette, using only rows that contain no
arms (the arms are what genuinely differs between frames), then crops all
three to one shared canvas so they can be stacked at identical size.

Usage:
    python3 tool/slice_mouth_frames.py SHEET.png OUT_DIR --prefix clef_mouth
    python3 tool/slice_mouth_frames.py --self-test

Requires Pillow and numpy. Outputs OUT_DIR/<prefix>_0.png (closed),
_1.png (open), _2.png (wide). Prints the shift applied to each frame and the
post-registration body overlap so a bad sheet is caught, not shipped.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ALPHA_THRESHOLD = 10
# Fractions of the sprite's height that hold only the body (the loop at the
# top, the curl at the bottom) and never the outstretched arms.
BODY_ROW_BANDS = ((0.00, 0.28), (0.85, 1.00))
MAX_SHIFT = 40
# Registration is judged by how far the body actually drifts between frames,
# in native sprite pixels, not by mask IoU: IoU on thin outlines punishes a
# 1px edge difference heavily (a first version required IoU >= 0.985 and
# rejected a sheet whose body centroids agreed to 0.4px). 4px at native size
# is ~1 logical pixel at the size this sprite is shown on screen.
MAX_DRIFT_PX = 4.0


def split_thirds(sheet: Image.Image) -> list[Image.Image]:
    w, h = sheet.size
    edges = [round(w * i / 3) for i in range(4)]
    tiles = [sheet.crop((edges[i], 0, edges[i + 1], h)) for i in range(3)]
    # Adjacent thirds of a width not divisible by 3 differ by a pixel; pad
    # them onto one canvas width so they can be compared and shifted.
    width = max(t.size[0] for t in tiles)
    padded = []
    for t in tiles:
        canvas = Image.new("RGBA", (width, h), (0, 0, 0, 0))
        canvas.paste(t.convert("RGBA"), (0, 0))
        padded.append(canvas)
    return padded


def _content_rows(alpha: np.ndarray) -> tuple[int, int]:
    ys = np.flatnonzero((alpha > ALPHA_THRESHOLD).any(axis=1))
    return int(ys.min()), int(ys.max())


def body_mask(alpha: np.ndarray) -> np.ndarray:
    """Boolean mask of the arm-free rows of one frame's silhouette."""
    top, bottom = _content_rows(alpha)
    height = bottom - top + 1
    mask = np.zeros_like(alpha, dtype=bool)
    for lo, hi in BODY_ROW_BANDS:
        y0, y1 = top + int(height * lo), top + int(height * hi)
        mask[y0 : y1 + 1] = alpha[y0 : y1 + 1] > ALPHA_THRESHOLD
    return mask


def best_shift(reference: np.ndarray, moving: np.ndarray) -> tuple[int, int, float]:
    """(dx, dy, overlap) that moves `moving` onto `reference`, by maximum
    intersection-over-union of the two masks."""
    best = (0, 0, -1.0)
    for dy in range(-10, 11):
        for dx in range(-MAX_SHIFT, MAX_SHIFT + 1):
            shifted = np.roll(np.roll(moving, dy, axis=0), dx, axis=1)
            inter = np.logical_and(reference, shifted).sum()
            union = np.logical_or(reference, shifted).sum()
            iou = inter / union if union else 0.0
            if iou > best[2]:
                best = (dx, dy, float(iou))
    return best


def register(frames: list[Image.Image]) -> tuple[list[Image.Image], list[tuple[int, int, float]]]:
    """Align frames to the middle one and crop to a shared canvas."""
    rgba = [f.convert("RGBA") for f in frames]
    alphas = [np.array(f)[:, :, 3] for f in rgba]
    ref = 1
    ref_mask = body_mask(alphas[ref])

    shifts = []
    for i, alpha in enumerate(alphas):
        shifts.append((0, 0, 1.0) if i == ref else best_shift(ref_mask, body_mask(alpha)))

    w, h = rgba[0].size
    shifted = []
    for img, (dx, dy, _) in zip(rgba, shifts):
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        canvas.paste(img, (dx, dy))
        shifted.append(canvas)

    # One shared crop: the union of all frames' content, so every frame
    # ends up the same size with the character at the same place in it.
    boxes = []
    for f in shifted:
        a = np.array(f)[:, :, 3] > ALPHA_THRESHOLD
        ys, xs = np.flatnonzero(a.any(axis=1)), np.flatnonzero(a.any(axis=0))
        boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    box = (
        min(b[0] for b in boxes), min(b[1] for b in boxes),
        max(b[2] for b in boxes), max(b[3] for b in boxes),
    )
    return [f.crop(box) for f in shifted], shifts


def registered_overlap(frames: list[Image.Image]) -> float:
    """Lowest pairwise body-mask IoU across registered frames. Informational
    only — see MAX_DRIFT_PX for why it isn't the pass/fail criterion."""
    masks = [body_mask(np.array(f.convert("RGBA"))[:, :, 3]) for f in frames]
    worst = 1.0
    for i in range(len(masks)):
        for j in range(i + 1, len(masks)):
            inter = np.logical_and(masks[i], masks[j]).sum()
            union = np.logical_or(masks[i], masks[j]).sum()
            worst = min(worst, inter / union if union else 0.0)
    return float(worst)


def registration_drift(frames: list[Image.Image]) -> float:
    """Worst drift, in pixels, between any two frames of the body's centroid
    and of its left/right extents in the arm-free bands."""
    stats = []
    for f in frames:
        alpha = np.array(f.convert("RGBA"))[:, :, 3]
        mask = body_mask(alpha)
        ys, xs = np.where(mask)
        h = alpha.shape[0]
        extents = []
        for lo, hi in BODY_ROW_BANDS:
            band = alpha[int(h * lo) : int(h * hi) + 1] > ALPHA_THRESHOLD
            bxs = np.flatnonzero(band.any(axis=0))
            extents += [bxs.min(), bxs.max()]
        stats.append((xs.mean(), ys.mean(), *extents))
    worst = 0.0
    for i in range(len(stats)):
        for j in range(i + 1, len(stats)):
            worst = max(worst, max(abs(a - b) for a, b in zip(stats[i], stats[j])))
    return float(worst)


def self_test() -> None:
    # A body (vertical bar top + bottom) with "arms" only in the middle
    # rows, drawn at three different x offsets with different arm widths.
    def frame(x_offset: int, arm: int) -> Image.Image:
        img = np.zeros((300, 200, 4), dtype=np.uint8)
        img[10:290, 90 + x_offset : 110 + x_offset, 3] = 255  # body bar
        img[130:170, 90 + x_offset - arm : 110 + x_offset + arm, 3] = 255  # arms
        return Image.fromarray(img)

    sheet_frames = [frame(14, 30), frame(0, 26), frame(2, 34)]
    before = registration_drift(sheet_frames)
    out, shifts = register(sheet_frames)
    after = registration_drift(out)

    assert before > 10, f"self-test premise: frames start misregistered ({before})"
    assert after <= 1.0, f"registration failed to align the body ({after})"
    assert len({f.size for f in out}) == 1, "all frames must share one canvas size"
    assert abs(shifts[0][0]) == 14 and shifts[1][0] == 0 and abs(shifts[2][0]) == 2, shifts

    # An image of only three identical thirds splits into equal-width tiles
    # even when the width isn't divisible by three.
    odd = Image.new("RGBA", (1774, 887))
    tiles = split_thirds(odd)
    assert len({t.size for t in tiles}) == 1, "tiles must share one size after padding"
    assert tiles[0].size[0] >= 1774 // 3, tiles[0].size

    # ...and a full sheet of that odd width registers without error.
    body = np.zeros((300, 1774, 4), dtype=np.uint8)
    for k, x in enumerate((300, 880, 1470)):
        body[10:290, x : x + 20, 3] = 255
    registered, _ = register(split_thirds(Image.fromarray(body)))
    assert len({f.size for f in registered}) == 1

    print("self-test passed (registration, shared canvas, odd-width split)")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheet", nargs="?")
    ap.add_argument("out_dir", nargs="?")
    ap.add_argument("--prefix", default="mouth")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        self_test()
        return
    if not args.sheet or not args.out_dir:
        ap.error("SHEET and OUT_DIR are required")

    frames = split_thirds(Image.open(args.sheet))
    registered, shifts = register(frames)
    overlap = registered_overlap(registered)
    drift = registration_drift(registered)

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for i, f in enumerate(registered):
        f.save(out / f"{args.prefix}_{i}.png", optimize=True)

    print(f"shifts applied (dx, dy, iou-before-crop): {shifts}")
    print(f"shared canvas: {registered[0].size}; worst body drift: {drift:.1f}px "
          f"(limit {MAX_DRIFT_PX}px); body-mask IoU {overlap:.4f} (informational)")
    if drift > MAX_DRIFT_PX:
        print(f"WARNING: body drifts {drift:.1f}px between frames — this sheet is not properly registered", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

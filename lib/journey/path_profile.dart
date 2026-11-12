import 'dart:math' as math;

/// Where a backdrop's painted path runs, so stones lie ON it at its own
/// width — scaled to the path, not stuck on top of the painting (Cooper,
/// 2026-11: "the stones need to stay on the path better and be scaled to
/// fit the path as necessary").
///
/// DATA, per backdrop: samples across the image of the path's centre line
/// and its apparent width (its depth, top edge to bottom edge), each as a
/// fraction of the image's height. Measured from the art by colour
/// (tool-free: tan path pixels per column, smoothed); a new backdrop needs
/// its own table.
class PathProfile {
  final String asset;

  /// The image's aspect (width over height).
  final double aspect;

  /// The painted band, as fractions of the image's height: the backdrop is
  /// scaled so this band fills the screen.
  final double bandTop;
  final double bandHeight;

  /// (x across the image 0–1, centre-line y 0–1, path depth 0–1).
  final List<(double, double, double)> samples;

  /// Depth narrower than this is a measuring artefact at the image edge.
  final double minDepth;

  const PathProfile({
    required this.asset,
    required this.aspect,
    required this.bandTop,
    required this.bandHeight,
    required this.samples,
    required this.minDepth,
  });

  /// Centre-line y and depth at [u] (0–1 across the image), interpolated.
  (double centre, double depth) at(double u) {
    final x = u.clamp(0.0, 1.0);
    for (var i = 1; i < samples.length; i++) {
      final (x1, c1, d1) = samples[i];
      if (x <= x1) {
        final (x0, c0, d0) = samples[i - 1];
        final t = x1 == x0 ? 0.0 : (x - x0) / (x1 - x0);
        return (c0 + (c1 - c0) * t, math.max(minDepth, d0 + (d1 - d0) * t));
      }
    }
    final (_, c, d) = samples.last;
    return (c, math.max(minDepth, d));
  }
}

/// learning_paths/Forest.png: 1536×1024, painted band 24%–78% of its
/// height. The path crosses left to right, narrowing toward the right.
const forestPath = PathProfile(
  asset: 'assets/images/backgrounds/learning_paths/Forest.png',
  aspect: 1.5,
  bandTop: 0.24,
  bandHeight: 0.54,
  minDepth: 0.036,
  samples: [
    (0.000, 0.5975, 0.0316),
    (0.031, 0.6087, 0.0391),
    (0.062, 0.6243, 0.0465),
    (0.094, 0.6367, 0.0465),
    (0.125, 0.6439, 0.0462),
    (0.156, 0.6481, 0.0462),
    (0.188, 0.6504, 0.0482),
    (0.219, 0.6519, 0.0501),
    (0.250, 0.6515, 0.0521),
    (0.281, 0.6488, 0.0521),
    (0.312, 0.6453, 0.0518),
    (0.344, 0.6413, 0.0498),
    (0.375, 0.6380, 0.0482),
    (0.406, 0.6351, 0.0462),
    (0.438, 0.6326, 0.0456),
    (0.469, 0.6317, 0.0439),
    (0.500, 0.6310, 0.0430),
    (0.531, 0.6297, 0.0420),
    (0.562, 0.6286, 0.0410),
    (0.594, 0.6271, 0.0400),
    (0.625, 0.6266, 0.0400),
    (0.656, 0.6211, 0.0410),
    (0.688, 0.6159, 0.0420),
    (0.719, 0.6108, 0.0423),
    (0.750, 0.6131, 0.0426),
    (0.781, 0.6154, 0.0430),
    (0.812, 0.6177, 0.0423),
    (0.844, 0.6170, 0.0410),
    (0.875, 0.6136, 0.0394),
    (0.906, 0.6030, 0.0378),
    (0.938, 0.5889, 0.0365),
    (0.969, 0.5719, 0.0264),
    (1.000, 0.5622, 0.0169),
  ],
);

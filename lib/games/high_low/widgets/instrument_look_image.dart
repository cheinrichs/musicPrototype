import 'package:flutter/material.dart';

import '../../../app/art_registry.dart';
import '../models/high_low_instrument.dart';

/// Draws one [InstrumentLook], fitted inside its box like
/// `Image.asset(..., fit: BoxFit.contain)`: a whole file, or its region of
/// a sheet at the region's own aspect.
///
/// A region STANDS ON THE BOTTOM of its box, as a tall whole file does.
/// The box's bottom is where the stump's surface is; a wide region
/// (the xylophone, 849x606) centred in a square box hung 14% of the box
/// above it, floating over the stump (Cooper, on device, 2026-11-20).
class InstrumentLookImage extends StatelessWidget {
  final InstrumentLook look;
  const InstrumentLookImage(this.look, {super.key});

  @override
  Widget build(BuildContext context) {
    final r = look.region;
    if (r == null) return Image.asset(look.asset, fit: BoxFit.contain);
    return Align(
      alignment: Alignment.bottomCenter,
      child: AspectRatio(
        aspectRatio: r.width / r.height,
        child: ImageRegion(
          art: ArtRef(
            look.asset,
            image: Size(r.sheetWidth, r.sheetHeight),
            region: Rect.fromLTWH(r.left, r.top, r.width, r.height),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../app/art_registry.dart';
import '../models/high_low_instrument.dart';

/// Draws one [InstrumentLook], fitted inside its box like
/// `Image.asset(..., fit: BoxFit.contain)`: a whole file, or its region of
/// a sheet at the region's own aspect.
class InstrumentLookImage extends StatelessWidget {
  final InstrumentLook look;
  const InstrumentLookImage(this.look, {super.key});

  @override
  Widget build(BuildContext context) {
    final r = look.region;
    if (r == null) return Image.asset(look.asset, fit: BoxFit.contain);
    return Center(
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

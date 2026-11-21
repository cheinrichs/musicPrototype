# Percussion one-shots (24 .aif files) — provenance

⚠️ **INTENTIONALLY UNUSED** (recorded 2026-11-20). Kept, not deleted:
**do not delete without asking Cooper.**

- **What they are:** 24 single hits (agogô, bongos, cabasa, cajón, castanets,
  claves, congas, cowbell, jam blocks, sleigh bells, snaps, stomps,
  tambourine, timbales, triangle, wood blocks).
- **Where they came from:** added in commit ffed98e (2026-04-27) by
  Cooper, "for future use in rhythm games". Every file's AIFF metadata
  reads "Creator: Logic Pro 11.2.2", with a Logic project chunk and a
  "Tempo: 109.0" marker. All are 16-bit stereo, exactly 0.55 s long.
- **Stock content, almost certainly, not original recordings.** Twenty-four
  different instruments, named like the pieces of Logic's built-in
  percussion kits (`congabrightlow`, `cowbelldry`, `tambourinevintage`),
  each exported at an identical length from one 109 BPM project: that is
  Logic's own percussion sounds triggered and bounced, not a recording
  session. **To confirm with Cooper**, and record the answer here.
- **Licence:** Logic Pro's bundled content is licensed for commercial use
  in your own works. If these are stock content, that very likely covers
  them inside the app; if Cooper recorded them, they are his.
- **Why unused:** nothing plays them (only a comment in
  `rhythm_game_state.dart` mentions them), and no instrument art depicts
  most of these instruments. They were pulled ahead of a rhythm game that
  is not built.
- **They still ship**, because `assets/audio/notes/percussion/` is
  registered in `pubspec.yaml`. Unregistering the folder would stop that
  without deleting anything.

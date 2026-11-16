/// The credits screen's own content (Trello card rDHLTn8u) — a plain
/// list read from here, not hand-written into the screen's widget tree,
/// specifically so a future sample source (or art asset) is one new
/// [CreditEntry] here rather than a change to how the screen itself is
/// built. This file is the single place that content is maintained.
///
/// Distinct from `assets/audio/notes/bells/ATTRIBUTION.md`: that file is
/// a developer-facing audit record (measurement methodology, per-file
/// Freesound URLs, why a given note was renamed) — useful history, but
/// far more detail than a end-user credits screen should show. The
/// entries below are the same underlying facts, reduced to what
/// attribution actually requires (title, creator, source, licence,
/// whether it was modified) and phrased for someone who isn't a
/// developer. Keep both in sync by hand when a new sound source lands —
/// there's no automatic link between them.
library;

/// One credited work or source. [creator]/[sourceUrl]/[license] are
/// optional since not every entry needs all of them (e.g. in-house art
/// has no external licence to cite), but a CC-licensed asset should
/// always fill in all four plus [modified] — that's what attribution
/// actually requires.
class CreditEntry {
  final String title;
  final String? creator;
  final String? sourceUrl;
  final String? license;

  /// Extra context — what it's used for, whether it was modified, or
  /// anything else worth a reader knowing. Freeform, shown under the
  /// entry's main line.
  final String? note;

  /// ⚠️ Whether the source's LICENCE REQUIRES this credit. True: removing
  /// the entry BREACHES the licence (the CC BY 4.0 handbells). False: a
  /// courtesy, removable without consequence. Required — never defaulted —
  /// so every new entry has to decide.
  final bool attributionRequired;

  const CreditEntry({
    required this.title,
    this.creator,
    this.sourceUrl,
    this.license,
    this.note,
    required this.attributionRequired,
  });
}

class CreditSection {
  final String heading;
  final List<CreditEntry> entries;

  const CreditSection({required this.heading, required this.entries});
}

/// Every section the credits screen renders, in order. App version/build
/// number isn't in here — that's read live from the installed binary
/// (see [CreditsScreen]'s own build-info section), not a fact this static
/// list could state correctly.
const List<CreditSection> creditSections = [
  CreditSection(
    heading: 'Sound',
    entries: [
      // ⚠️ ATTRIBUTION RULES — read before tidying this list:
      // - InspectorJ's handbells are CC BY 4.0: the credit is REQUIRED,
      //   and removing it breaches the licence.
      // - Philharmonia and Iowa ask for no credit; theirs are courtesies.
      // Each entry's [CreditEntry.attributionRequired] says which, and
      // test/app/credits_data_test.dart fails if a required one goes.
      // Per-file provenance: assets/audio/notes/<instrument>/PROVENANCE.md
      // (Philharmonia, Iowa) and bells/ATTRIBUTION.md.
      CreditEntry(
        title: 'Philharmonia Orchestra sound samples',
        creator: 'Philharmonia Orchestra',
        // Philharmonia's own terms (checked 2026-11-14): free to use
        // as you wish, including in a commercial work, but never sold or
        // made available "as is". NOT Creative Commons — commit e5730e3
        // wrongly said "CC-licensed".
        sourceUrl: 'https://philharmonia.co.uk/audio-sound-samples',
        license: 'Free to use for any purpose, including commercially',
        attributionRequired: false,
        note:
            'Cello, flute, guitar, oboe, trumpet, tuba, and violin note '
            'samples, and drum hits.',
      ),
      CreditEntry(
        title: 'University of Iowa Musical Instrument Samples',
        creator: 'University of Iowa Electronic Music Studios',
        sourceUrl: 'https://theremin.music.uiowa.edu/MIS.html',
        license:
            'Freely available since 1997, for any project, without '
            'restriction',
        note: 'Piano and xylophone note samples.',
        attributionRequired: false,
      ),
      CreditEntry(
        title: 'Hand Bells, Singles',
        creator: 'InspectorJ',
        sourceUrl: 'https://freesound.org/people/InspectorJ/packs/19255/',
        license: 'CC BY 4.0 (creativecommons.org/licenses/by/4.0)',
        // REQUIRED by CC BY 4.0. Do not remove.
        attributionRequired: true,
        note:
            'Bell note samples. Modified: converted to mono, trimmed, and '
            'gain-normalized.',
      ),
    ],
  ),
  CreditSection(
    heading: 'Art',
    entries: [
      CreditEntry(
        title: 'Character and instrument illustrations',
        creator: 'SongStone',
        note: 'Original artwork created for this app.',
        attributionRequired: false,
      ),
    ],
  ),
];

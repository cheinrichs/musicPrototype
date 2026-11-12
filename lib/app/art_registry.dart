import 'package:flutter/widgets.dart';

/// A piece of art: a region of an image file. A whole file is a region
/// covering all of it, so sheets and one-file-per-asset both fit. Fields
/// are final; not `@immutable` only so the file/cell constructors can work
/// their region out.
class ArtRef {
  final String asset;

  /// The image's pixel size.
  final Size image;

  /// The art's region in it, in pixels.
  final Rect region;

  const ArtRef(this.asset, {required this.image, required this.region});

  /// A whole file.
  ArtRef.file(this.asset, Size size)
    : image = size,
      region = Offset.zero & size;

  /// Cell [column], [row] of a sheet laid out as an even grid of [cell]s.
  ArtRef.cell(
    this.asset, {
    required this.image,
    required Size cell,
    required int column,
    required int row,
  }) : region = Rect.fromLTWH(
         column * cell.width,
         row * cell.height,
         cell.width,
         cell.height,
       );

  double get aspect => region.width / region.height;
}

/// Every asset the app refers to BY ID, mapped to where it lives. ALL ART
/// IS PROVISIONAL (docs/product/STANDING_RULES.md): a replacement set is a
/// change to this table, not a search-and-replace across the code.
///
/// Families keep one naming and sizing convention so a replacement drops in
/// without per-file adjustment; where an asset has states, the id carries
/// the state as a suffix (`.rest` / `.hit`).
abstract final class Art {
  static const _dir = 'assets/images/journey';
  static const _instruments = 'assets/images/characters/instruments';

  // --- Game icons -----------------------------------------------------------
  // High vs Low is the standalone tree WITHOUT Clef: after card 222 Clef is
  // never on the tree, so game_icons_x3.png's tree is superseded.
  static const _gameIcons = '$_dir/game_icons_x3.png';
  static const _gameIconsSize = Size(2172, 724);

  // --- Decorations: rest/hit pairs on two 4×3 sheets of 362-px cells. -------
  static const _decoSize = Size(1448, 1086);
  static const _decoCell = Size(362, 362);

  static ArtRef _deco(String sheet, int column, int row) => ArtRef.cell(
    '$_dir/$sheet',
    image: _decoSize,
    cell: _decoCell,
    column: column,
    row: row,
  );

  static final Map<String, ArtRef> _table = {
    'game.high_low': ArtRef.file(
      '$_dir/game_icon_highlow_tree_noclef.png',
      const Size(1254, 1254),
    ),
    'game.loud_quiet': ArtRef.cell(
      _gameIcons,
      image: _gameIconsSize,
      cell: const Size(724, 724),
      column: 1,
      row: 0,
    ),
    'game.same_different': ArtRef.cell(
      _gameIcons,
      image: _gameIconsSize,
      cell: const Size(724, 724),
      column: 2,
      row: 0,
    ),

    // Placeholder reward tokens (Cooper: will change). Four 543×724 cells,
    // each a 543-square diamond centred in it. The game-unlock token (cell
    // 0) is retired with game unlocks and not referenced.
    'token.craft': const ArtRef(
      '$_dir/reward_tokens_placeholder_x4.png',
      image: Size(2172, 724),
      region: Rect.fromLTWH(543, 90.5, 543, 543),
    ),
    'token.song': const ArtRef(
      '$_dir/reward_tokens_placeholder_x4.png',
      image: Size(2172, 724),
      region: Rect.fromLTWH(1086, 90.5, 543, 543),
    ),

    // Instruments: the art the games already use, which doubles as the
    // instrument's reward token.
    for (final (id, file, w, h) in const [
      ('guitar', 'Guitar1.png', 363.0, 821.0),
      ('trumpet', 'Trumpet1.png', 531.0, 940.0),
      ('violin', 'Violin1.png', 512.0, 678.0),
      ('drum', 'Drum1.png', 358.0, 341.0),
      ('flute', 'Flute1.png', 246.0, 831.0),
      ('bell', 'Bell1.png', 392.0, 552.0),
      ('piano', 'Piano1.png', 572.0, 456.0),
    ])
      'instrument.$id': ArtRef.file('$_instruments/$file', Size(w, h)),

    // Set 1: mushroom, butterfly / acorn, bluebells / chipmunk, snail.
    // Set 2: frog, bluebird / pine cone, ladybird / daisy, dragonfly.
    for (final (sheet, names) in const [
      (
        'decorations_set1_pairs.png',
        [
          ['mushroom', 'butterfly'],
          ['acorn', 'bluebells'],
          ['chipmunk', 'snail'],
        ],
      ),
      (
        'decorations_set2_pairs.png',
        [
          ['frog', 'bluebird'],
          ['pine_cone', 'ladybird'],
          ['daisy', 'dragonfly'],
        ],
      ),
    ])
      for (var row = 0; row < 3; row++)
        for (var pair = 0; pair < 2; pair++) ...{
          'decoration.${names[row][pair]}.rest': _deco(sheet, pair * 2, row),
          'decoration.${names[row][pair]}.hit': _deco(sheet, pair * 2 + 1, row),
        },
  };

  static ArtRef of(String id) =>
      _table[id] ?? (throw ArgumentError('No art with id "$id"'));

  static bool has(String id) => _table.containsKey(id);

  static Iterable<String> get ids => _table.keys;
}

/// Draws the art [id] contained in its box, at its own aspect.
class ArtImage extends StatelessWidget {
  final String id;

  /// Mirrored left-to-right (objects only — never a creature, which would
  /// read as turning round; STANDING_RULES.md).
  final bool mirrored;

  const ArtImage(this.id, {super.key, this.mirrored = false});

  @override
  Widget build(BuildContext context) {
    final art = Art.of(id);
    Widget child = AspectRatio(
      aspectRatio: art.aspect,
      child: ImageRegion(art: art),
    );
    if (mirrored) child = Transform.flip(flipX: true, child: child);
    return Center(child: child);
  }
}

/// A region of an image, scaled to fill the box (which should share the
/// region's aspect — [ArtImage] makes sure of it).
class ImageRegion extends StatelessWidget {
  final ArtRef art;
  const ImageRegion({super.key, required this.art});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final r = art.region;
      final sx = c.maxWidth / r.width;
      final sy = c.maxHeight / r.height;
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: art.image.width * sx,
          maxWidth: art.image.width * sx,
          minHeight: art.image.height * sy,
          maxHeight: art.image.height * sy,
          child: Transform.translate(
            offset: Offset(-r.left * sx, -r.top * sy),
            child: Image.asset(art.asset, fit: BoxFit.fill),
          ),
        ),
      );
    },
  );
}

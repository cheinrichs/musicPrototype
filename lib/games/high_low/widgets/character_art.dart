import 'package:flutter/material.dart';
import '../../../app/art_registry.dart';
import 'mouth_frames.dart';

/// Which of a character's images is showing.
///
/// Only *speaking* has mouth frames — celebration and thinking are discrete
/// moments, so a single image each is correct.
enum CharacterPose {
  /// The resting pose. Its mouth follows the voice line's envelope; closed
  /// when nobody is speaking.
  speaking,

  /// A correct answer.
  celebrating,

  /// A wrong answer, and the idle nudge.
  thinking,
}

/// One image of a character: a [region] of [asset] (a whole file is a
/// region covering it), drawn into [box] — in the character's own units,
/// where her speaking frame is `Offset.zero & CharacterArt.frameSize`.
@immutable
class CharacterImage {
  final String asset;
  final Size sheet;
  final Rect region;
  final Rect box;

  const CharacterImage(
    this.asset, {
    required this.sheet,
    required this.region,
    required this.box,
  });

  /// A whole file of [size] pixels, drawn at one pixel per unit,
  /// bottom-centred on a [frame]-sized speaking frame (its feet on hers).
  CharacterImage.file(this.asset, Size size, Size frame)
    : sheet = size,
      region = Offset.zero & size,
      box = Rect.fromLTWH(
        (frame.width - size.width) / 2,
        frame.height - size.height,
        size.width,
        size.height,
      );

  /// A [region] of [asset] placed BY HEAD: scaled so its body
  /// ([bodyHeight] px of near-opaque art) is [drawnBodyHeight] units tall,
  /// and positioned so its [head] (sheet px) lands on [anchor] (units).
  factory CharacterImage.headMatched(
    String asset, {
    required Size sheet,
    required Rect region,
    required double bodyHeight,
    required Offset head,
    required double drawnBodyHeight,
    required Offset anchor,
  }) {
    final k = drawnBodyHeight / bodyHeight;
    final headInRegion = (head - region.topLeft) * k;
    return CharacterImage(
      asset,
      sheet: sheet,
      region: region,
      box: (anchor - headInRegion) & (region.size * k),
    );
  }

  /// This image grown by [factor] about [origin].
  CharacterImage grownAbout(Offset origin, double factor) => CharacterImage(
    asset,
    sheet: sheet,
    region: region,
    box: Rect.fromPoints(
      origin + (box.topLeft - origin) * factor,
      origin + (box.bottomRight - origin) * factor,
    ),
  );
}

/// Everything the app needs to draw one character: her three mouth frames
/// and her two single-image poses, each a [CharacterImage] placed in her own
/// units, where her speaking frame is `Offset.zero & frameSize`.
/// [CharacterSprite] draws all of them at one scale, so a pose swap never
/// changes her size unless the art says so.
///
/// ⚠️ THERE IS NO GLOBAL CHARACTER SIZE. Each screen's own layout sizes
/// the characters for the room it has: `SceneLayout.piperHeight` (High vs
/// Low), `LoudQuietLayout.piperHeight`, `JourneyMapGeometry.piperHeight`,
/// and a future Matching Grove layout of its own, which is the most crowded
/// screen (two stumps of card pairs plus both characters). Never match a
/// character's size on one screen to another's: an enlargement asked for
/// on one screen does not apply to the others
/// (docs/product/SAME_OR_DIFFERENT.md, amendment A2).
@immutable
class CharacterArt {
  /// Who she is ('clef', 'piper'): names her sprite's layers.
  final String name;
  final List<CharacterImage> mouthFrames;
  final CharacterImage celebration;
  final CharacterImage thinking;

  /// Her speaking frame, in her own units: what a layout's `height` is the
  /// height of.
  final Size frameSize;

  const CharacterArt({
    required this.name,
    required this.mouthFrames,
    required this.celebration,
    required this.thinking,
    required this.frameSize,
  });

  Size get celebrationSize => celebration.box.size;
  Size get thinkingSize => thinking.box.size;

  /// Everything she can occupy, across every image, in her own units.
  Rect get extent => [
    ...mouthFrames.map((i) => i.box),
    celebration.box,
    thinking.box,
  ].reduce((a, b) => a.expandToInclude(b));

  List<String> get allAssets => {
    for (final i in [...mouthFrames, celebration, thinking]) i.asset,
  }.toList();

  /// Clef, slate-blue "H" art (Cooper, 2026-11-20), drawn from the sheets
  /// as supplied — never re-saved — by tool/measure_clef_poses.py's numbers:
  ///
  /// - SPEAKING: the three frames of clef_H_talk_x3.png (closed, open,
  ///   wide), cut at SLICE_POINTS.json's columns.
  /// - THINKING: clef_H_thoughtful.png. CELEBRATING: clef_H_celebrate.png,
  ///   measured on near-opaque pixels: its glow reaches the whole canvas.
  /// - HEAD-MATCHED, so she never swells or shrinks on a change of state:
  ///   each image is placed by its head centre (the midpoint of her eyes)
  ///   at the size that matches her head. With the thoughtful pose's body
  ///   at H: talking 0.63H, celebrating 0.81H (head-band widths; the eye
  ///   spacing agrees within 3%).
  /// - 12% LARGER than the bronze Clef she replaces, about her feet (she is
  ///   slimmer): Cooper asked for 10-15%.
  ///
  /// The hop sheet (clef_H_move_x3.png) is for the Journey's movement
  /// (Trello 227), not here: its frame 2 is drawn 81 px up — the hop is in
  /// the art, so it is played on its own baselines with no code lift.
  static final CharacterArt clef = _clef();

  static CharacterArt _clef() {
    const talk = 'assets/images/characters/clef/clef_H_talk_x3.png';
    const talkSheet = Size(2170, 725);
    const talkBody = 719.0;
    const frame0 = Rect.fromLTWH(182, 0, 473, 723);
    const head0 = Offset(434, 413);
    final anchor = head0 - frame0.topLeft;
    const frameSize = Size(473, 723);
    CharacterImage talking(Rect region, double body, Offset head) =>
        CharacterImage.headMatched(
          talk,
          sheet: talkSheet,
          region: region,
          bodyHeight: body,
          head: head,
          drawnBodyHeight: body,
          anchor: anchor,
        );
    // Thoughtful at H: talking is 0.63H, celebrating 0.81H.
    const thoughtfulH = talkBody / 0.63;
    final images = [
      talking(frame0, 719, head0),
      talking(
        const Rect.fromLTWH(825, 1, 483, 724),
        722,
        const Offset(1083, 413),
      ),
      talking(
        const Rect.fromLTWH(1490, 0, 490, 725),
        722,
        const Offset(1749, 413),
      ),
      CharacterImage.headMatched(
        'assets/images/characters/clef/clef_H_celebrate.png',
        sheet: const Size(1024, 1536),
        region: const Rect.fromLTWH(144, 16, 818, 1446),
        bodyHeight: 1441,
        head: const Offset(543, 783),
        drawnBodyHeight: thoughtfulH * 0.81,
        anchor: anchor,
      ),
      CharacterImage.headMatched(
        'assets/images/characters/clef/clef_H_thoughtful.png',
        sheet: const Size(1024, 1536),
        region: const Rect.fromLTWH(147, 17, 708, 1478),
        bodyHeight: 1476,
        head: const Offset(522, 797),
        drawnBodyHeight: thoughtfulH,
        anchor: anchor,
      ),
    ];
    final feet = Offset(frameSize.width / 2, frameSize.height);
    final grown = [for (final i in images) i.grownAbout(feet, clefGrowth)];
    return CharacterArt(
      name: 'clef',
      mouthFrames: grown.sublist(0, 3),
      celebration: grown[3],
      thinking: grown[4],
      frameSize: frameSize,
    );
  }

  /// How much larger the H Clef draws than the bronze one she replaced.
  static const double clefGrowth = 1.12;

  /// Piper's mouth frames are a **stopgap**: cut from the rejected,
  /// unregistered sheet (her tail, fringe, flute and satchel redraw between
  /// frames), so expect visible jitter while timing and scale are tuned on
  /// device. Replacing them is a file swap — rerun
  /// `tool/slice_mouth_frames.py` on the new sheet — nothing here changes
  /// unless the new frames' pixel size does. Her poses
  /// (`tool/prepare_character_pose.py`) are at the frames' scale, feet on
  /// the frames' feet.
  static final CharacterArt piper = () {
    const frame = Size(492, 927);
    return CharacterArt(
      name: 'piper',
      mouthFrames: [
        for (final f in piperMouthFrameAssets)
          CharacterImage.file(f, frame, frame),
      ],
      celebration: CharacterImage.file(
        'assets/images/characters/piper/piper_celebration.png',
        const Size(585, 919),
        frame,
      ),
      thinking: CharacterImage.file(
        'assets/images/characters/piper/piper_thinking.png',
        const Size(585, 926),
        frame,
      ),
      frameSize: frame,
    );
  }();
}

/// A character drawn from [art] in [pose], [height] tall (the height of her
/// speaking frame; other images are drawn where her art places them, which
/// may reach above, beside or below it).
///
/// Every image stays mounted with only one visible, so each is decoded
/// before it is first needed — swapping one image for another on demand
/// would flash empty the first time a pose appeared.
class CharacterSprite extends StatelessWidget {
  final CharacterArt art;
  final CharacterPose pose;
  final MouthFrame mouth;
  final double height;

  const CharacterSprite({
    super.key,
    required this.art,
    required this.pose,
    required this.mouth,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final scale = height / art.frameSize.height;

    Widget layer(CharacterImage image, bool showing, String key) =>
        Positioned.fromRect(
          key: ValueKey('${art.name}-$key'),
          rect: Rect.fromLTWH(
            image.box.left * scale,
            image.box.top * scale,
            image.box.width * scale,
            image.box.height * scale,
          ),
          child: Opacity(
            opacity: showing ? 1.0 : 0.0,
            child: ImageRegion(
              art: ArtRef(
                image.asset,
                image: image.sheet,
                region: image.region,
              ),
            ),
          ),
        );

    return SizedBox(
      width: art.frameSize.width * scale,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < art.mouthFrames.length; i++)
            layer(
              art.mouthFrames[i],
              pose == CharacterPose.speaking && i == mouth.index,
              'mouth-$i',
            ),
          layer(
            art.celebration,
            pose == CharacterPose.celebrating,
            'celebration',
          ),
          layer(art.thinking, pose == CharacterPose.thinking, 'thinking'),
        ],
      ),
    );
  }
}

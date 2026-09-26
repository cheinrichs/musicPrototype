import 'package:flutter/material.dart';
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

/// Everything the app needs to draw one character: her mouth frames and her
/// two single-image poses, with each image's pixel size.
///
/// The images are produced by `tool/slice_mouth_frames.py` and
/// `tool/prepare_character_pose.py` at **one common scale per character**, so
/// [CharacterSprite] can draw all of them at the same scale and a pose swap
/// never changes her size. The recorded sizes are what the sprite scales by;
/// `character_art_test.dart` fails if a re-cut asset's dimensions stop
/// matching them.
@immutable
class CharacterArt {
  final List<String> mouthFrames;
  final String celebration;
  final String thinking;
  final Size frameSize;
  final Size celebrationSize;
  final Size thinkingSize;

  const CharacterArt({
    required this.mouthFrames,
    required this.celebration,
    required this.thinking,
    required this.frameSize,
    required this.celebrationSize,
    required this.thinkingSize,
  });

  static const clef = CharacterArt(
    mouthFrames: clefMouthFrameAssets,
    celebration: 'assets/images/characters/clef/clef_celebration.png',
    thinking: 'assets/images/characters/clef/clef_thinking.png',
    frameSize: Size(563, 860),
    celebrationSize: Size(584, 875),
    thinkingSize: Size(384, 879),
  );

  /// Piper's mouth frames are a **stopgap**: cut from the rejected,
  /// unregistered sheet (her tail, fringe, flute and satchel redraw between
  /// frames), so expect visible jitter while timing and scale are tuned on
  /// device. Replacing them is a file swap — rerun
  /// `tool/slice_mouth_frames.py` on the new sheet — nothing here changes
  /// unless the new frames' pixel size does.
  static const piper = CharacterArt(
    mouthFrames: piperMouthFrameAssets,
    celebration: 'assets/images/characters/piper/piper_celebration.png',
    thinking: 'assets/images/characters/piper/piper_thinking.png',
    frameSize: Size(492, 927),
    celebrationSize: Size(585, 919),
    thinkingSize: Size(585, 926),
  );

  List<String> get allAssets => [...mouthFrames, celebration, thinking];
}

/// A character drawn from [art] in [pose], [height] tall (the height of her
/// body in the mouth-frame pose; poses with slightly taller art, arms up,
/// come out proportionally a little taller).
///
/// Every image is drawn at the same scale and bottom-aligned on one ground
/// line. All five stay mounted with only one visible, so each is decoded
/// before it is first needed — swapping one `Image` for another on demand
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

    Widget layer(String asset, Size px, bool showing) => Opacity(
      key: ValueKey(asset),
      opacity: showing ? 1.0 : 0.0,
      child: Image.asset(
        asset,
        width: px.width * scale,
        height: px.height * scale,
        fit: BoxFit.fill,
        gaplessPlayback: true,
      ),
    );

    return SizedBox(
      width: art.frameSize.width * scale,
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < art.mouthFrames.length; i++)
            layer(
              art.mouthFrames[i],
              art.frameSize,
              pose == CharacterPose.speaking && i == mouth.index,
            ),
          layer(
            art.celebration,
            art.celebrationSize,
            pose == CharacterPose.celebrating,
          ),
          layer(art.thinking, art.thinkingSize, pose == CharacterPose.thinking),
        ],
      ),
    );
  }
}

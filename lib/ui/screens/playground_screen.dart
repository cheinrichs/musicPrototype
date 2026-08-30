import 'package:flutter/material.dart';
import '../../audio/audio_controller.dart';
import '../../models/instrument.dart';
import '../components/glow_wiggle_character.dart';
import '../theme/theme.dart';

/// Where an instrument stands in the meadow.
///
/// [x] and [y] are fractions of the play area (0 = left/top, 1 =
/// right/bottom) and [depth] scales the character so the ones further up the
/// clearing read as further away. Positions were picked against
/// assets/images/backgrounds/Meadow.png in landscape: the painted dirt
/// clearing fills roughly the bottom 45% of the frame once the 3:2 artwork is
/// cover-cropped to a phone, with grass and hills above it. Nothing sits
/// higher than y = 0.5 — above that the character stops reading as standing
/// in the meadow and starts floating over the far hills.
class _MeadowSpot {
  const _MeadowSpot(this.instrument, this.x, this.y, this.depth);

  final Instrument instrument;
  final double x;
  final double y;
  final double depth;
}

/// A loose arc across the clearing rather than a row — the eye travels
/// left-to-right and front-to-back, and no two characters sit at the same
/// height. Listed back-to-front so the nearer ones paint over the further
/// ones where they overlap.
/// The [depth] numbers are tuned per instrument rather than purely by
/// distance, because the kit art has wildly different proportions — the
/// guitar is 0.44:1 and the piano 1.25:1 — and sizing everything off a single
/// height would leave the guitar towering over the piano.
const List<_MeadowSpot> _meadowLayout = [
  _MeadowSpot(Instrument.violin, 0.55, 0.52, 0.62),
  _MeadowSpot(Instrument.trumpet, 0.90, 0.56, 0.62),
  _MeadowSpot(Instrument.guitar, 0.11, 0.57, 0.86),
  _MeadowSpot(Instrument.drums, 0.74, 0.80, 0.72),
  _MeadowSpot(Instrument.piano, 0.33, 0.84, 0.82),
];

/// Sound Playground — tap an instrument to hear a melody
class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  Instrument? _activeInstrument;

  @override
  void initState() {
    super.initState();
    // Preload all clips — silent no-op for any that don't exist yet
    AudioController.instance.preloadClips(
      Instrument.values.expand((i) => i.assetPaths).toList(),
    );
  }

  @override
  void dispose() {
    AudioController.instance.stopCurrentClip();
    super.dispose();
  }

  Future<void> _play(Instrument instrument) async {
    setState(() => _activeInstrument = instrument);
    await AudioController.instance.playClip(instrument.randomAssetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed meadow — deliberately outside the SafeArea so the art
        // runs under the status bar and the rounded display corners.
        Image.asset(
          'assets/images/backgrounds/Meadow.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildMeadow()),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTitlePlate(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The title reads over painted sky, so it gets a soft parchment scrim
  /// rather than plain text on the artwork.
  Widget _buildTitlePlate() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.ivory.withValues(alpha: 0.85),
              AppColors.ivory.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sound Playground',
              style: AppTypography.heading2.copyWith(color: AppColors.forest),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tap an instrument to hear it!',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeadow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Size off the shorter axis so the characters stay in proportion to
        // the clearing on both a phone and an iPad.
        final baseSize = (constraints.maxHeight * 0.42)
            .clamp(90.0, 220.0)
            .toDouble();

        return Stack(
          children: [
            for (final spot in _meadowLayout)
              _PositionedInstrument(
                spot: spot,
                baseSize: baseSize,
                bounds: constraints.biggest,
                isActive: _activeInstrument == spot.instrument,
                onTap: () => _play(spot.instrument),
              ),
          ],
        );
      },
    );
  }
}

/// Places one character so that *its own centre* lands on the spot's
/// fractional coordinate.
///
/// The child is deliberately left to size itself (no fixed slot box) and then
/// shifted back by half its measured size — that keeps each tap target the
/// shape of the character it belongs to, so the wide-but-short drum and the
/// narrow-but-tall guitar don't end up with big empty hit areas that steal
/// taps from their neighbours.
class _PositionedInstrument extends StatelessWidget {
  const _PositionedInstrument({
    required this.spot,
    required this.baseSize,
    required this.bounds,
    required this.isActive,
    required this.onTap,
  });

  final _MeadowSpot spot;
  final double baseSize;
  final Size bounds;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: bounds.width * spot.x,
      top: bounds.height * spot.y,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: _InstrumentCharacter(
          instrument: spot.instrument,
          size: baseSize * spot.depth,
          isActive: isActive,
          onTap: onTap,
          // Stagger the idle bob so the meadow doesn't pulse in unison.
          bobDelay: Duration(milliseconds: (spot.x * 900).round()),
        ),
      ),
    );
  }
}

class _InstrumentCharacter extends StatefulWidget {
  const _InstrumentCharacter({
    required this.instrument,
    required this.size,
    required this.isActive,
    required this.onTap,
    required this.bobDelay,
  });

  final Instrument instrument;
  final double size;
  final bool isActive;
  final VoidCallback onTap;
  final Duration bobDelay;

  @override
  State<_InstrumentCharacter> createState() => _InstrumentCharacterState();
}

class _InstrumentCharacterState extends State<_InstrumentCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: AppAnimations.buttonPressDown,
    );
    _pressScale = Tween<double>(
      begin: 1.0,
      end: AppAnimations.buttonPressScale,
    ).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _pressController.forward().then((_) => _pressController.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _pressScale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlowWiggleCharacter(
              size: widget.size,
              isActive: widget.isActive,
              glowColor: widget.instrument.color,
              bobDelay: widget.bobDelay,
              child: _buildArt(),
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildNamePlate(),
          ],
        ),
      ),
    );
  }

  Widget _buildArt() {
    final art = widget.instrument.artAssetPath;

    return art != null
        ? Image.asset(art, height: widget.size, fit: BoxFit.contain)
        // No kit character for this instrument yet — fall back to the emoji
        // at roughly the same visual weight so the scene still balances. The
        // width is explicit: an unbounded SizedBox here would stretch the
        // character's tap target across the whole meadow.
        : SizedBox(
            width: widget.size * 0.9,
            height: widget.size,
            child: Center(
              child: Text(
                widget.instrument.emoji,
                style: TextStyle(fontSize: widget.size * 0.6),
              ),
            ),
          );
  }

  Widget _buildNamePlate() {
    return AnimatedContainer(
      duration: AppAnimations.fast,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: widget.isActive
            ? AppColors.card
            : AppColors.card.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
        border: Border.all(
          color: widget.isActive
              ? widget.instrument.color
              : AppColors.cardEdge,
          width: widget.isActive ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        widget.instrument.label,
        style: AppTypography.label.copyWith(
          color: widget.isActive ? AppColors.ink : AppColors.textSecondary,
        ),
      ),
    );
  }
}

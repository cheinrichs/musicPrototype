import 'package:flutter/material.dart';
import '../../audio/audio_controller.dart';
import '../../models/instrument.dart';
import '../theme/theme.dart';

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
      Instrument.values.map((i) => i.assetPath).toList(),
    );
  }

  @override
  void dispose() {
    AudioController.instance.stopCurrentClip();
    super.dispose();
  }

  Future<void> _play(Instrument instrument) async {
    setState(() => _activeInstrument = instrument);
    await AudioController.instance.playClip(instrument.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Two columns with md spacing on sides and between cards
    final cardSize = (screenWidth - AppSpacing.md * 2 - AppSpacing.md) / 2;

    return SafeArea(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sound Playground',
              style: AppTypography.heading2.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap an instrument to hear it!',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  alignment: WrapAlignment.center,
                  children: Instrument.values.map((instrument) {
                    return SizedBox(
                      width: cardSize,
                      height: cardSize,
                      child: _InstrumentCard(
                        instrument: instrument,
                        isActive: _activeInstrument == instrument,
                        onTap: () => _play(instrument),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstrumentCard extends StatefulWidget {
  const _InstrumentCard({
    required this.instrument,
    required this.isActive,
    required this.onTap,
  });

  final Instrument instrument;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_InstrumentCard> createState() => _InstrumentCardState();
}

class _InstrumentCardState extends State<_InstrumentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.88).animate(
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
    final color = widget.instrument.color;

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _pressScale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: widget.isActive
                ? color.withValues(alpha: 0.18)
                : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isActive ? color : color.withValues(alpha: 0.35),
              width: widget.isActive ? 3 : 1.5,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: widget.isActive ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.elasticOut,
                child: Text(
                  widget.instrument.emoji,
                  style: const TextStyle(fontSize: 52),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTypography.buttonMedium.copyWith(
                  color: widget.isActive ? color : AppColors.textSecondary,
                ),
                child: Text(widget.instrument.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

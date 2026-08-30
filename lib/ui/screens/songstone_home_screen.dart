import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../theme/theme.dart';

/// The app's true entry point — a branded "SongStone" landing screen shown
/// at launch, in front of the [MainShell] bottom-nav (Trello card 37).
///
/// The Trello concept art was a portrait mockup (wordmark stacked above
/// three buttons). The app is landscape-only, so this reflows that as two
/// side-by-side halves — wordmark on the left, the three section buttons
/// stacked in the right column — rather than letterboxing the portrait
/// composition into a wide screen.
class SongStoneHomeScreen extends StatelessWidget {
  const SongStoneHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/Forest.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(flex: 6, child: Center(child: _buildWordmark())),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 4, child: _buildMenu(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordmark() {
    return SizedBox(
      width: 320,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Iridescent "geode" glow standing in for the concept art's
          // rainbow egg — no matching art in the kit yet, so this is a
          // painted gradient rather than a placeholder image.
          Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFFF3E9CE),
                      AppColors.lavender,
                      AppColors.sky,
                      AppColors.gold,
                    ],
                    stops: [0.0, 0.45, 0.75, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.04, duration: const Duration(seconds: 3), curve: Curves.easeInOut),
          _floatingNote(
            icon: Icons.music_note_rounded,
            color: AppColors.rose,
            left: 24,
            top: 18,
            delay: const Duration(milliseconds: 0),
          ),
          _floatingNote(
            icon: Icons.music_note_rounded,
            color: AppColors.sky,
            right: 20,
            top: 34,
            delay: const Duration(milliseconds: 400),
          ),
          _floatingNote(
            icon: Icons.audiotrack_rounded,
            color: AppColors.gold,
            right: 44,
            bottom: 46,
            delay: const Duration(milliseconds: 800),
          ),
          _buildWordmarkText(),
        ],
      ),
    );
  }

  Widget _floatingNote({
    required IconData icon,
    required Color color,
    double? left,
    double? right,
    double? top,
    double? bottom,
    required Duration delay,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child:
          Icon(icon, color: color, size: 22)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: 0,
                end: -8,
                delay: delay,
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeInOut,
              ),
    );
  }

  /// Chunky outlined display wordmark: a stroked layer behind a filled
  /// layer gives the painted-outline look from the concept art without
  /// needing a custom font weight/stroke asset.
  Widget _buildWordmarkText() {
    final style = AppTypography.heading1.copyWith(fontSize: 44, height: 1.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        // Stroke pass (outline)
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Song',
                style: style.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 5
                    ..color = AppColors.goldDeep,
                ),
              ),
              TextSpan(
                text: 'Stone',
                style: style.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 5
                    ..color = AppColors.skyDeep,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        // Fill pass
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Song', style: style.copyWith(color: AppColors.gold)),
              TextSpan(text: 'Stone', style: style.copyWith(color: AppColors.sky)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMenu(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MenuPill(
          label: 'Playground',
          delay: const Duration(milliseconds: 100),
          onTap: () => context.go(AppRoutes.home, extra: {'initialTab': 2}),
        ),
        const SizedBox(height: AppSpacing.md),
        _MenuPill(
          label: 'Learning Path',
          delay: const Duration(milliseconds: 200),
          onTap: () => context.go(AppRoutes.home, extra: {'initialTab': 1}),
        ),
        const SizedBox(height: AppSpacing.md),
        _MenuPill(
          label: 'Games',
          delay: const Duration(milliseconds: 300),
          onTap: () => context.go(AppRoutes.home, extra: {'initialTab': 0}),
        ),
      ],
    );
  }
}

/// Soft translucent blue-green pill button matching the concept art's menu
/// style — a lighter-weight sibling of [SquishyButton] without the hard
/// "step" shadow, since the mockup's buttons read as flat glassy panels.
class _MenuPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Duration delay;

  const _MenuPill({
    required this.label,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.sky.withValues(alpha: 0.55),
              AppColors.sage.withValues(alpha: 0.55),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
          border: Border.all(
            color: AppColors.ivory.withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.buttonMedium.copyWith(color: AppColors.ivory),
        ),
      ),
    ).animate(delay: delay).fade(duration: AppAnimations.medium).slideX(
      begin: 0.15,
      end: 0,
      duration: AppAnimations.medium,
    );
  }
}

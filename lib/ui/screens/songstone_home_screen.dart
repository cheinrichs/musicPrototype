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

  /// The real lockup (Cooper's call — stop waiting on it): rainbow stone
  /// plus the painted "SongStone" wordmark, together in one image. This
  /// used to be a coded placeholder here — a plain radial-gradient circle
  /// standing in for the stone, floating Material note icons around it,
  /// and a separately hand-styled "SongStone" text wordmark underneath.
  /// Since the real asset already paints its own wordmark (and its own
  /// notes/flowers/treble clef), all of that placeholder scaffolding is
  /// gone with it rather than layered on top — showing "SongStone" twice,
  /// once as pixels and once as a second Flutter Text, would read as a
  /// mistake, not a flourish.
  Widget _buildWordmark() {
    return SizedBox(
          width: 320,
          // The source PNG's own aspect ratio (1536x1024) — AspectRatio
          // keeps it undistorted rather than stretching to a fixed height
          // the way the old placeholder box did.
          child: const AspectRatio(
            aspectRatio: 1536 / 1024,
            child: Image(
              image: AssetImage('assets/images/logos/SongStoneLogo.png'),
              fit: BoxFit.contain,
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1,
          end: 1.03,
          duration: const Duration(seconds: 3),
          curve: Curves.easeInOut,
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
              style: AppTypography.buttonMedium.copyWith(
                color: AppColors.ivory,
              ),
            ),
          ),
        )
        .animate(delay: delay)
        .fade(duration: AppAnimations.medium)
        .slideX(begin: 0.15, end: 0, duration: AppAnimations.medium);
  }
}

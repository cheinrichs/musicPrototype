import 'package:flutter/material.dart';
import '../theme/theme.dart';
import 'squishy_button.dart';

/// Card for selecting a game from the home screen.
///
/// Restyled to match the Lumi "choice card" (`.card-base`/`.card-choice`
/// in kit.css): a warm parchment gradient with a hard-edged step shadow,
/// replacing the previous flat white Material card.
class GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isLocked;

  const GameCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accentColor = AppColors.primary,
    this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return SquishyButton(
      onTap: isLocked ? null : onTap,
      gradient: AppColors.cardGradient,
      backgroundColor: AppColors.card,
      shadowColor: AppColors.cardShadow,
      stepHeight: 4,
      enabled: !isLocked,
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderRadius: AppSpacing.radiusLg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            flex: 2,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
                maxWidth: 56,
                maxHeight: 56,
              ),
              decoration: BoxDecoration(
                color: isLocked
                    ? AppColors.textSecondary.withValues(alpha: 0.2)
                    : accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLocked
                      ? AppColors.textSecondary.withValues(alpha: 0.3)
                      : accentColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Icon(
                isLocked ? Icons.lock_outline : icon,
                size: 28,
                color: isLocked ? AppColors.textSecondary : accentColor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.bodyLarge.copyWith(
              color: isLocked ? AppColors.textSecondary : AppColors.textPrimary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

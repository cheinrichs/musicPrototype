import 'package:flutter/material.dart';
import '../../app/art_registry.dart';
import '../theme/theme.dart';
import 'squishy_button.dart';

/// Card for selecting a game from the home screen.
///
/// Restyled to match the Lumi "choice card" (`.card-base`/`.card-choice`
/// in kit.css): a warm parchment gradient with a hard-edged step shadow,
/// replacing the previous flat white Material card.
class GameCard extends StatelessWidget {
  final String title;
  final IconData icon;

  /// The game's painted icon, by art id; [icon] stands in where a game has
  /// none yet.
  final String? artId;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isLocked;

  const GameCard({
    super.key,
    required this.title,
    required this.icon,
    this.artId,
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
      stepHeight: 3,
      enabled: !isLocked,
      padding: const EdgeInsets.all(AppSpacing.xs),
      borderRadius: AppSpacing.radiusMd,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: artId != null
                ? ArtImage(artId!)
                : Center(
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                        maxWidth: 34,
                        maxHeight: 34,
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
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        isLocked ? Icons.lock_outline : icon,
                        size: 18,
                        color: isLocked ? AppColors.textSecondary : accentColor,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          // The game's name only — no subtitle (Cooper: "the game names are
          // enough").
          Text(
            title,
            style: AppTypography.bodyLarge.copyWith(
              color: isLocked ? AppColors.textSecondary : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

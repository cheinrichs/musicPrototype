import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/state/skill_state.dart';
import '../../models/musical_skill.dart';
import '../theme/theme.dart';

/// Developer / parent-facing screen showing XP and level for each of the
/// 11 musical skill nodes.
class SkillProfileScreen extends StatelessWidget {
  const SkillProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Consumer<SkillState>(
                builder: (context, skills, _) {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    itemCount: MusicalSkill.values.length,
                    separatorBuilder: (context, i) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final skill = MusicalSkill.values[index];
                      return _SkillCard(skill: skill, skills: skills);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text('Skill Profile', style: AppTypography.heading2)),
          IconButton(
            onPressed: () => context.read<SkillState>().seedRandom(),
            icon: const Icon(Icons.casino_rounded),
            color: AppColors.textSecondary,
            tooltip: 'Seed random data',
          ),
          IconButton(
            onPressed: () => context.read<SkillState>().reset(),
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.textSecondary,
            tooltip: 'Reset all XP',
          ),
        ],
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill, required this.skills});

  final MusicalSkill skill;
  final SkillState skills;

  @override
  Widget build(BuildContext context) {
    final level = skills.levelFor(skill);
    final xp = skills.xpFor(skill);
    final progress = skills.progressFor(skill);
    final toNext = skills.xpToNextLevelFor(skill);
    final notStarted = xp == 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notStarted
              ? AppColors.shadow
              : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji + level badge
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(skill.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                if (!notStarted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Lv $level',
                      style: AppTypography.label.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Name, description, XP bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.label,
                  style: AppTypography.buttonMedium.copyWith(
                    color: notStarted
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  skill.description,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (notStarted)
                  Text(
                    'Not started yet',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.shadow,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level < 5
                        ? '$xp XP  ·  $toNext to next level'
                        : '$xp XP  ·  Max level!',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

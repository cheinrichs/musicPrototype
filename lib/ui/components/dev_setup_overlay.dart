import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/config.dart';
import '../../app/state/dev_settings_state.dart';
import '../../models/agency_stage.dart';
import '../../models/concept_tier.dart';
import '../../models/round_order.dart';
import '../theme/theme.dart';

/// Debug-only pre-game gate: lets a developer pick an [AgencyStage],
/// [ConceptTier], and [RoundOrder] from [DevSettingsState] before an
/// activity starts (Trello card 92). Generic across activities — it only
/// touches the shared, activity-agnostic dev-settings model, never a
/// specific game's own state — so any game screen can drop this in ahead
/// of its normal auto-start the same way [HighLowScreen] does.
///
/// The caller is responsible for only mounting this in [kDevMode] (it
/// renders real, tappable UI regardless of build mode if given the
/// chance) — that's the actual guarantee that a shipping build can never
/// present it. Calls [onStart] once the developer confirms.
class DevSetupOverlay extends StatelessWidget {
  final VoidCallback onStart;

  const DevSetupOverlay({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final devSettings = context.watch<DevSettingsState>();
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dev: agency setup',
                    style: AppTypography.heading3,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Debug-only — never shown in a release build.',
                    style: AppTypography.label,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ChipRow<AgencyStage>(
                    title: 'Agency stage',
                    values: AgencyStage.values,
                    labelOf: (s) => '${s.code} · ${s.label}',
                    selected: devSettings.agencyStage,
                    onSelected: devSettings.setAgencyStage,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ChipRow<ConceptTier>(
                    title: 'Concept tier',
                    values: ConceptTier.values,
                    labelOf: (t) => t.label,
                    selected: devSettings.conceptTier,
                    onSelected: devSettings.setConceptTier,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ChipRow<RoundOrder>(
                    title: 'Round order',
                    values: RoundOrder.values,
                    labelOf: (o) => o.label,
                    selected: devSettings.roundOrder,
                    onSelected: devSettings.setRoundOrder,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: onStart,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Text('Start'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipRow<T> extends StatelessWidget {
  final String title;
  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;

  const _ChipRow({
    required this.title,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.label),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final value in values)
              ChoiceChip(
                label: Text(labelOf(value)),
                selected: value == selected,
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
    );
  }
}

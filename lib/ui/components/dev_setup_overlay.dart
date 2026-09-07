import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
/// The caller is responsible for only mounting this when `devToolsEnabled`
/// (see app/config.dart) is true — it renders real, tappable UI regardless
/// of build mode if given the chance — that's the actual guarantee that a
/// public App Store build can never present it. Calls [onStart] once the
/// developer confirms.
///
/// Deliberately not wrapped in a scroll view (Trello card "Dev agency
/// setup screen should fit without scrolling") — a `SingleChildScrollView`
/// hit-tests its entire viewport, not just what it paints, which is
/// exactly what once made High/Low's drag-to-answer interaction
/// completely untappable (see `GameScreenLayout.scrollableBody`). This
/// screen has no full-screen gesture layer behind it the way High/Low
/// does, so that specific bug can't recur here today — but the whole
/// point of a debug gate like this is that new controls get bolted onto
/// it later without much scrutiny, so it's safer to just not have a
/// scroll view sitting around waiting to matter. Every row below is sized
/// to comfortably fit the tightest landscape viewport in real use
/// (iPhone SE) with headroom left over for one more settings row (a
/// future player-type control) — if a future addition ever needs more
/// vertical room than that leaves, that's the moment to reach for
/// [Expanded]/[FittedBox] inside this column, not a scroll view.
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
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dev: agency setup',
                    style: AppTypography.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Internal build only — never shown on the App Store.',
                    style: AppTypography.label.copyWith(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SettingRow<AgencyStage>(
                    title: 'Agency',
                    values: AgencyStage.values,
                    labelOf: (s) => '${s.code} · ${s.label}',
                    selected: devSettings.agencyStage,
                    onSelected: devSettings.setAgencyStage,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _SettingRow<ConceptTier>(
                    title: 'Tier',
                    values: ConceptTier.values,
                    labelOf: (t) => t.label,
                    selected: devSettings.conceptTier,
                    onSelected: devSettings.setConceptTier,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _SettingRow<RoundOrder>(
                    title: 'Order',
                    values: RoundOrder.values,
                    labelOf: (o) => o.label,
                    selected: devSettings.roundOrder,
                    onSelected: devSettings.setRoundOrder,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 40,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onStart,
                      child: const Text('Start'),
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

/// One setting's label and its options, sharing a single row (Trello card
/// "Dev agency setup screen should fit without scrolling": the label used
/// to sit on its own line above a [Wrap] of full-size chips, which — being
/// too wide to all fit on one line at this column's width — wrapped onto a
/// second line and left the agency row with a lot of empty space to the
/// right of its last chip). Giving the options [Expanded] width on the
/// same row as the label both removes that stacked label line (tightening
/// the vertical rhythm) and, combined with the chips' own smaller sizing
/// below, keeps every row's options on one line with no leftover gap.
class _SettingRow<T> extends StatelessWidget {
  final String title;
  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;

  const _SettingRow({
    required this.title,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          child: Text(title, style: AppTypography.label.copyWith(fontSize: 12)),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(labelOf(value)),
                  labelStyle: const TextStyle(fontSize: 12),
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  selected: value == selected,
                  onSelected: (_) => onSelected(value),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

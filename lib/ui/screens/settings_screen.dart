import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/config.dart';
import '../../app/state/profile_state.dart';
import '../../games/game_levels.dart';
import '../../games/tier_progression.dart';
import '../../journey/journey_art.dart';
import '../../models/agency_stage.dart';
import '../../models/profile.dart';
import '../theme/theme.dart';
import 'credits_screen.dart';
import 'setup_quiz_screen.dart';

/// Settings, behind the gear on the player picker and the reading gate
/// (Cooper, 2026-11-15; docs/product/PROFILES.md). Profile-level settings
/// sit ABOVE profiles, so they live here, where no child is active:
/// adding and deleting players, each child's picture, placement and age
/// band, the dev profile (internal builds only), the credits.
class SettingsScreen extends StatelessWidget {
  final ProfileState profiles;

  /// Opens the dev profile. Only ever called on an internal build.
  final VoidCallback onDevProfile;

  /// Tests only: false stands in for a release-flavoured build.
  final bool showDevProfile;

  const SettingsScreen({
    super.key,
    required this.profiles,
    required this.onDevProfile,
    this.showDevProfile = true,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: profiles,
    builder: (context, _) => Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (final child in profiles.childProfiles)
            ListTile(
              key: ValueKey('settings-child-${child.id}'),
              leading: SizedBox.square(
                dimension: 44,
                child: AvatarBadge(index: child.avatarIndex),
              ),
              title: Text(child.name),
              subtitle: Text(
                [
                  if (child.ageBand != null) 'Age ${child.ageBand!.label}',
                  dragAnswers[child.agencyOverride ?? AgencyStage.observe]!,
                  for (final (id, name) in [
                    (GameLevels.highLow, 'High vs Low'),
                    (GameLevels.loudQuiet, 'Loud or Quiet'),
                  ])
                    '$name ${GameLevels.label(id, child.levelOf(id))}'
                        '${_evidence(context, child.id, id)}',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ChildSettingsScreen(profiles: profiles, child: child),
                ),
              ),
            ),
          if (profiles.canAddChild)
            ListTile(
              key: const ValueKey('settings-add'),
              leading: const Icon(Icons.person_add_alt_1_rounded),
              title: const Text('Add a player'),
              onTap: () async {
                final answers = await SetupQuizScreen.run(
                  context,
                  takenAvatars: profiles.takenAvatars(),
                );
                if (answers != null) await profiles.addChild(answers);
              },
            )
          else
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Six players is the most one device holds'),
              subtitle: Text('Delete one to add another.'),
            ),
          // INTERNAL BUILDS ONLY: a const guard, so a release-flavoured
          // build drops this tile and everything it reaches.
          if (kDevProfileCompiledIn && showDevProfile) ...[
            const Divider(),
            Semantics(
              label: 'Dev profile (internal)',
              child: ListTile(
                key: const ValueKey('dev-profile'),
                leading: const Icon(Icons.build_rounded),
                title: const Text('Dev profile (internal)'),
                onTap: onDevProfile,
              ),
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About and credits'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CreditsScreen()),
            ),
          ),
        ],
      ),
    ),
  );
}

/// One child's settings: picture, where play starts, age band, delete.
class ChildSettingsScreen extends StatelessWidget {
  final ProfileState profiles;
  final Profile child;

  const ChildSettingsScreen({
    super.key,
    required this.profiles,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: profiles,
    builder: (context, _) {
      final p = profiles.childProfiles
          .where((x) => x.id == child.id)
          .firstOrNull;
      if (p == null) return const SizedBox.shrink();
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(p.name),
          backgroundColor: AppColors.background,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Picture', style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 150,
              child: AvatarGrid(
                // Their own stays choosable; siblings' are hidden.
                taken: profiles.takenAvatars(exceptId: p.id),
                selected: p.avatarIndex,
                onSelected: (i) => profiles.setAvatar(p, i),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Where play starts', style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.xs),
            // Cooper's option (b): the honest statement, so a later
            // automatic change never looks like this failing to save.
            Text(
              'This is a starting point. ${p.name}’s games keep adjusting '
              'as they play, so this can change on its own.',
              key: const ValueKey('placement-note'),
              style: AppTypography.bodyMedium,
            ),
            for (final MapEntry(:key, :value) in dragAnswers.entries)
              ListTile(
                key: ValueKey('placement-${key.name}'),
                title: Text(value),
                trailing: p.agencyOverride == key
                    ? const Icon(Icons.check_rounded, color: AppColors.goldDeep)
                    : null,
                onTap: () => profiles.setPlacement(p, key),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text('Age range', style: AppTypography.heading3),
            for (final band in AgeBand.values)
              ListTile(
                key: ValueKey('age-${band.name}'),
                title: Text(band.label),
                trailing: p.ageBand == band
                    ? const Icon(Icons.check_rounded, color: AppColors.goldDeep)
                    : null,
                onTap: () => profiles.setAgeBand(p, band),
              ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              key: const ValueKey('delete-player'),
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text('Delete ${p.name}'),
              subtitle: const Text('Removes their progress too.'),
              onTap: () async {
                final sure = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: Text('Delete ${p.name}?'),
                    content: const Text(
                      'Their journey and progress on this device are removed. '
                      'This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(d).pop(false),
                        child: const Text('Keep'),
                      ),
                      FilledButton(
                        key: const ValueKey('delete-confirm'),
                        onPressed: () => Navigator.of(d).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (sure != true) return;
                await profiles.deleteProfile(p);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    },
  );
}

/// "(6 right of 10)" — how far a child's tier evidence has got in a game,
/// so an adult can see why a level is or is not moving.
String _evidence(BuildContext context, String profileId, String gameId) {
  try {
    final g = Provider.of<TierProgressState>(
      context,
      listen: false,
    ).gameRecord(profileId, gameId);
    return g == null || g.slots.isEmpty ? '' : ' (${g.summary})';
  } on ProviderNotFoundException {
    return '';
  }
}

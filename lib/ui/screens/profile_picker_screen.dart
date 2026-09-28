import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/router.dart';
import '../../app/state/profile_state.dart';
import '../../app/state/progress_state.dart';
import '../../app/state/skill_state.dart';
import '../../models/profile.dart';
import '../components/adult_door.dart';
import '../theme/theme.dart';

/// "Pick a profile at launch" (Trello card 170) — the app's true first
/// screen, ahead of [SongStoneHomeScreen]. Deliberately plain: this is
/// functional plumbing (keeping two children's play apart, keeping the dev
/// screens away from them), not an illustrated moment, so it doesn't need
/// the character art the rest of the app uses — large, readable tiles are
/// enough.
///
/// Not persisted across launches on purpose: picking is a deliberate step
/// every time on a shared device (see [ProfileState.selectProfile]'s doc
/// comment), so there's no "remembered last profile" branch here to skip
/// the picker — it always shows.
class ProfilePickerScreen extends StatelessWidget {
  const ProfilePickerScreen({super.key});

  /// Everything this screen's actions need, captured once from `context`
  /// **before their first `await`** — never re-read from `context`, or
  /// gated on a `context.mounted` check, after one. Growing the profile
  /// list changes the tiles/button's positions in this screen's unkeyed
  /// `Column`, which is exactly the situation where Flutter's default
  /// reconciliation *can* dispose and recreate a widget's own Element
  /// rather than reusing it — a real, if unconfirmed-in-this-instance,
  /// risk while a `context.mounted` check afterward is silently the only
  /// thing standing between "added" and "actually navigated". [GoRouter]
  /// is an app-wide singleton that outlives any one screen's Element, so
  /// routing through an instance captured up front sidesteps the whole
  /// risk instead of guarding around one occurrence of it.
  _Deps _deps(BuildContext context) => _Deps(
    profileState: context.read<ProfileState>(),
    progressState: context.read<ProgressState>(),
    skillState: context.read<SkillState>(),
    router: GoRouter.of(context),
  );

  Future<void> _choose(_Deps deps, Profile profile) async {
    deps.profileState.selectProfile(profile);
    await Future.wait([
      deps.progressState.loadForProfile(profile.id),
      deps.skillState.loadForProfile(profile.id),
    ]);
    deps.router.go(AppRoutes.landing);
  }

  Future<void> _addChild(BuildContext context) async {
    final deps = _deps(context);
    final name = await _promptForName(context, title: 'Add a child');
    if (name == null || name.trim().isEmpty) return;
    final profile = await deps.profileState.addProfile(name.trim());
    await _choose(deps, profile);
  }

  /// The adult profile: at most one ever exists (Trello card 170). If it's
  /// already there, tapping [AdultDoor] just selects it — no re-entry of a
  /// name it already has. If not, this is the one place it gets created.
  Future<void> _adultDoor(BuildContext context) async {
    final deps = _deps(context);
    if (deps.profileState.hasAdultProfile) {
      await _choose(
        deps,
        deps.profileState.profiles.firstWhere((p) => p.isAdult),
      );
      return;
    }
    final name = await _promptForName(
      context,
      title: "What's your name?",
      initial: 'Parent',
    );
    if (name == null || name.trim().isEmpty) return;
    final profile = await deps.profileState.addProfile(
      name.trim(),
      isAdult: true,
    );
    await _choose(deps, profile);
  }

  Future<String?> _promptForName(
    BuildContext context, {
    required String title,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Consumer<ProfileState>(
                    builder: (context, profileState, _) {
                      final children = profileState.profiles
                          .where((p) => !p.isAdult)
                          .toList();
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Who's playing?",
                            style: AppTypography.heading2,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          for (final profile in children) ...[
                            _ProfileTile(
                              profile: profile,
                              onTap: () => _choose(_deps(context), profile),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          FilledButton.icon(
                            onPressed: () => _addChild(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add a child'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            // Tucked in the corner, same treatment SongStoneHomeScreen
            // gives the adult-settings door — small and easy to miss for a
            // child, easy to find for an adult scanning the screen.
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: AdultDoor(
                  icon: Icons.person_outline_rounded,
                  semanticLabel: "I'm the grown-up",
                  onTap: () => _adultDoor(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;

  const _ProfileTile({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.largeTapTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cardEdge, width: 1.5),
            borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  profile.name.isEmpty ? '?' : profile.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(profile.name, style: AppTypography.bodyLarge),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// See [ProfilePickerScreen._deps]'s doc comment for why these are captured
/// once, up front, rather than re-read from `context` after an `await`.
class _Deps {
  final ProfileState profileState;
  final ProgressState progressState;
  final SkillState skillState;
  final GoRouter router;

  const _Deps({
    required this.profileState,
    required this.progressState,
    required this.skillState,
    required this.router,
  });
}

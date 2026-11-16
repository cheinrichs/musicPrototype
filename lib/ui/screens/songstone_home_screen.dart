import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/config.dart';
import '../../app/router.dart';
import '../../app/state/profile_state.dart';
import '../../app/state/progress_state.dart';
import '../../app/state/skill_state.dart';
import '../../journey/journey_art.dart';
import '../../journey/journey_state.dart';
import '../../models/profile.dart';
import '../components/reading_gate.dart';
import '../theme/theme.dart';
import 'settings_screen.dart';
import 'setup_quiz_screen.dart';

/// The SongStone logo page — the CHOOSE-YOUR-PLAYER screen and the app's
/// first screen. Each child is a round badge standing on the meadow's
/// stumps; picking one goes straight to their Journey, which is home.
///
/// Cooper, 2026-11-15 (docs/product/PROFILES.md):
/// - CHILDREN ONLY, each on one tap. The dev profile lives in settings now
///   (internal builds only), so there is one gate, not two.
/// - The last tile is always "Add Profile" (an outlined +, with words),
///   UNGATED: the quiz abandons in one tap and writes nothing until done.
///   Hidden at six children.
/// - The gear opens settings, behind the reading gate.
///
/// Picking is a deliberate step every launch on a shared device — never a
/// remembered default (card 170).
class SongStoneHomeScreen extends StatelessWidget {
  /// Tests only: false stands in for a release-flavoured build. In a real
  /// release-flavoured build [kDevProfileCompiledIn] is a false CONST, so
  /// the dev profile's code is dropped whatever this says.
  final bool showDevProfile;

  const SongStoneHomeScreen({super.key, this.showDevProfile = true});

  static const background = 'assets/images/backgrounds/Forest.png';

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<ProfileState>();
    final children = profiles.childProfiles;
    // The tiles: every child, then "Add Profile" — always last, and HIDDEN
    // at the cap (a + that does nothing is worse than none).
    final addTile = profiles.canAddChild;
    final tiles = children.length + (addTile ? 1 : 0);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final layout = PickerLayout(
            c.biggest,
            MediaQuery.paddingOf(context),
            tiles,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(background, fit: BoxFit.cover),
              Positioned.fromRect(rect: layout.logo, child: _wordmark()),
              for (var i = 0; i < children.length; i++)
                Positioned.fromRect(
                  rect: layout.badge(i),
                  child: _PlayerBadge(
                    profile: children[i],
                    onTap: () => _choose(context, children[i]),
                  ),
                ),
              if (addTile)
                Positioned.fromRect(
                  rect: layout.badge(children.length),
                  child: _AddProfileTile(onTap: () => _addChild(context)),
                ),
              // At the cap the + is HIDDEN (Cooper), so say why and how to
              // free a slot — for the grown-up, so in words. Top-left: the
              // tile row fills the bottom.
              if (!addTile)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Container(
                        key: const ValueKey('profile-cap-note'),
                        // Narrow: on an SE the logo starts ~180 pt in.
                        constraints: const BoxConstraints(maxWidth: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ivory.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: Text(
                          'Six players max. To add one, delete one in '
                          'Settings.',
                          style: AppTypography.label.copyWith(
                            color: AppColors.inkBrown,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // The gear: settings, behind the reading gate — and the ONLY
              // route to the dev profile, so it must be FINDABLE. Build 133
              // left it as a faint 20 px AdultDoor bottom-right and removed
              // the visible badge Cooper's hand went to bottom-left: he
              // couldn't find a way in. A plain, visible gear where that
              // badge was. The reading gate is what turns a child around,
              // not hiding the door.
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: _SettingsGear(onTap: () => _openSettings(context)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _wordmark() =>
      const Image(
            image: AssetImage('assets/images/logos/SongStoneLogo.png'),
            fit: BoxFit.contain,
          )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1,
            end: 1.03,
            duration: const Duration(seconds: 3),
            curve: Curves.easeInOut,
          );

  /// Everything an action needs, captured BEFORE its first await — a
  /// profile list that grows rebuilds this screen, and the router outlives
  /// it (see the old picker's note on why this matters).
  static _Deps _deps(BuildContext context) => _Deps(
    profiles: context.read<ProfileState>(),
    progress: context.read<ProgressState>(),
    skills: context.read<SkillState>(),
    journey: context.read<JourneyState>(),
    router: GoRouter.of(context),
  );

  /// Picks [profile] and goes HOME — the Journey.
  static Future<void> _choose(BuildContext context, Profile profile) =>
      _enter(_deps(context), profile);

  static Future<void> _enter(_Deps deps, Profile profile) async {
    deps.profiles.selectProfile(profile);
    deps.journey.useProfile(profile.id);
    await Future.wait([
      deps.progress.loadForProfile(profile.id),
      deps.skills.loadForProfile(profile.id),
    ]);
    deps.router.go(AppRoutes.journey);
  }

  /// "Add Profile": the setup quiz, UNGATED (Cooper). It is safe because
  /// the quiz abandons in one tap and writes nothing until it completes,
  /// so a child's stray tap is a screen they leave, not a junk profile.
  static Future<void> _addChild(BuildContext context) async {
    final deps = _deps(context);
    final answers = await SetupQuizScreen.run(
      context,
      takenAvatars: deps.profiles.takenAvatars(),
    );
    if (answers == null) return;
    await deps.profiles.addChild(answers);
  }

  /// The gear: the reading gate (re-asked every time), then settings.
  Future<void> _openSettings(BuildContext context) async {
    final deps = _deps(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    if (!await ReadingGate.ask(context)) return;
    if (!navigator.mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (settingsContext) => SettingsScreen(
          profiles: deps.profiles,
          showDevProfile: showDevProfile,
          // INTERNAL BUILDS ONLY (the tile is const-guarded): already
          // behind the gate, so no second one.
          onDevProfile: () async {
            final dev = await deps.profiles.ensureDevProfile();
            if (dev == null) return;
            navigator.popUntil((r) => r.isFirst);
            await _enter(deps, dev);
          },
        ),
      ),
    );
  }
}

/// Where everything sits on the logo page, from the meadow's own art.
class PickerLayout {
  final Size size;
  final EdgeInsets padding;
  final int count;

  PickerLayout(this.size, this.padding, this.count);

  /// The background, 1448×1086, and its two stumps' top surfaces (centre,
  /// and half the width), measured on the art.
  static const art = Size(1448, 1086);
  static const stumps = [Offset(391, 745), Offset(1011, 745)];
  static const stumpHalfWidth = 135.0;

  /// The art's scale and offset under BoxFit.cover.
  double get _scale =>
      math.max(size.width / art.width, size.height / art.height);
  Offset get _offset => Offset(
    (size.width - art.width * _scale) / 2,
    (size.height - art.height * _scale) / 2,
  );

  Offset _onScreen(Offset p) => _offset + p * _scale;

  /// A stump's top, on screen.
  Offset stumpTop(int i) => _onScreen(stumps[i]);

  /// A badge's diameter: most of a stump's top, but never so tall the logo
  /// is crowded out — and, for three or more, small enough for them all to
  /// stand in a row across the two stumps.
  double get diameter {
    final onStump = stumpHalfWidth * 2 * _scale * 0.8;
    final byHeight = size.height * 0.3;
    var d = math.min(onStump, byHeight);
    if (count > 2) {
      final span =
          stumpTop(1).dx - stumpTop(0).dx + 2 * stumpHalfWidth * _scale;
      d = math.min(d, span / (count + (count - 1) * 0.15));
    }
    return d;
  }

  /// Child [i]'s badge: standing on a stump — one on the left stump, two
  /// on both, three or more in an even row across both.
  Rect badge(int i) {
    final d = diameter;
    final Offset foot;
    if (count <= 2) {
      foot = stumpTop(i);
    } else {
      final left = stumpTop(0).dx - stumpHalfWidth * _scale + d / 2;
      final right = stumpTop(1).dx + stumpHalfWidth * _scale - d / 2;
      foot = Offset(left + (right - left) * i / (count - 1), stumpTop(0).dy);
    }
    // Its foot a little into the stump's top, so it stands ON it; the name
    // hangs below, on the stump's face.
    final nameRoom = d * 0.32;
    return Rect.fromLTWH(
      foot.dx - d / 2,
      foot.dy + d * 0.12 - d,
      d,
      d + nameRoom,
    );
  }

  /// The wordmark: the sky above the badges.
  Rect get logo {
    final top = padding.top + AppSpacing.sm;
    final bottom = stumpTop(0).dy - diameter * 0.95;
    final h = math.max(0.0, bottom - top);
    final w = math.min(h * 1.5, size.width * 0.6);
    return Rect.fromCenter(
      center: Offset(size.width / 2, top + h / 2),
      width: w,
      height: w / 1.5,
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;

  const _PlayerBadge({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: profile.name,
    child: GestureDetector(
      key: ValueKey('player-${profile.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, c) {
          final d = c.maxWidth;
          return Column(
            children: [
              SizedBox.square(
                dimension: d,
                child: AvatarBadge(index: profile.avatarIndex),
              ),
              // The name: for the grown-up — a child finds their face.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.ivory.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusRound,
                      ),
                    ),
                    child: Text(
                      profile.name,
                      style: AppTypography.label.copyWith(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// The settings gear: a plain, visible circle (as the dev badge it
/// replaces was), never a faint door — it is the only way to settings and
/// the dev profile.
class _SettingsGear extends StatelessWidget {
  final VoidCallback onTap;
  const _SettingsGear({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Settings',
    child: GestureDetector(
      key: const ValueKey('settings-gear'),
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface.withValues(alpha: 0.85),
          border: Border.all(color: AppColors.cardEdge, width: 2),
        ),
        child: const Icon(Icons.settings_rounded, color: AppColors.warmGray),
      ),
    ),
  );
}

/// "Add Profile": an OUTLINED + with words beneath (Cooper). Visibly not
/// one of the round animal faces, so it never reads as another player to
/// pick. Words are right here alone: adding a profile is an adult's action.
class _AddProfileTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddProfileTile({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Add Profile',
    child: GestureDetector(
      key: const ValueKey('add-profile'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, c) {
          final d = c.maxWidth;
          return Column(
            children: [
              SizedBox.square(
                dimension: d,
                child: Padding(
                  padding: EdgeInsets.all(d * 0.08),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.ivory.withValues(alpha: 0.18),
                      border: Border.all(
                        color: AppColors.ivory,
                        width: d * 0.04,
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: d * 0.5,
                      color: AppColors.ivory,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.ivory.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusRound,
                      ),
                    ),
                    child: Text(
                      'Add Profile',
                      style: AppTypography.label.copyWith(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Deps {
  final ProfileState profiles;
  final ProgressState progress;
  final SkillState skills;
  final JourneyState journey;
  final GoRouter router;

  const _Deps({
    required this.profiles,
    required this.progress,
    required this.skills,
    required this.journey,
    required this.router,
  });
}

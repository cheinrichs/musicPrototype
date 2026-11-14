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
import '../components/adult_door.dart';
import '../components/reading_gate.dart';
import '../theme/theme.dart';
import 'credits_screen.dart';
import 'setup_quiz_screen.dart';

/// The SongStone logo page — now the CHOOSE-YOUR-PLAYER screen and the
/// app's first screen. Each child is a round badge standing on the
/// meadow's stumps; picking one goes straight to their Journey, which is
/// home.
///
/// - Child profiles open on ONE tap.
/// - On INTERNAL builds only, Cooper's dev profile is listed too, behind
///   the reading gate — a signpost for his daughter, never a security
///   boundary. In a release-flavoured build it is compiled out
///   ([kDevProfileCompiledIn]).
/// - The ADULT DOOR is a door, not a player: behind the reading gate it
///   opens the parent area — adding a child, re-taking a child's setup,
///   the credits. Profile-level settings sit ABOVE profiles, so they live
///   here, where no child is active; the fuller settings area slots in
///   behind the same door.
/// - With no children yet (a fresh install, an adult setting it up) the
///   first player's setup is offered directly.
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
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final layout = PickerLayout(
            c.biggest,
            MediaQuery.paddingOf(context),
            children.length,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(background, fit: BoxFit.cover),
              Positioned.fromRect(rect: layout.logo, child: _wordmark()),
              if (children.isEmpty)
                Positioned.fromRect(
                  rect: layout.firstSetup,
                  child: Center(
                    child: FilledButton.icon(
                      key: const ValueKey('first-setup'),
                      onPressed: () => _addChild(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Set up a player'),
                    ),
                  ),
                ),
              for (var i = 0; i < children.length; i++)
                Positioned.fromRect(
                  rect: layout.badge(i),
                  child: _PlayerBadge(
                    profile: children[i],
                    onTap: () => _choose(context, children[i]),
                  ),
                ),
              // INTERNAL BUILDS ONLY. `kDevProfileCompiledIn` is a const:
              // in a release-flavoured build this branch, and everything
              // only it reaches, is not compiled in at all.
              if (kDevProfileCompiledIn && showDevProfile)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: _DevBadge(onTap: () => _openDevProfile(context)),
                    ),
                  ),
                ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: AdultDoor(
                    icon: Icons.settings_outlined,
                    semanticLabel: 'For grown-ups',
                    onTap: () => _openAdultDoor(context),
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

  /// The dev profile: behind the reading gate, re-asked every time.
  static Future<void> _openDevProfile(BuildContext context) async {
    final deps = _deps(context);
    if (!await ReadingGate.ask(context)) return;
    final dev = await deps.profiles.ensureDevProfile();
    if (dev != null) await _enter(deps, dev);
  }

  static Future<void> _addChild(BuildContext context) async {
    final deps = _deps(context);
    final answers = await SetupQuizScreen.run(context);
    if (answers == null) return;
    await deps.profiles.addChild(answers);
  }

  /// The adult door: the reading gate, then the parent area.
  static Future<void> _openAdultDoor(BuildContext context) async {
    final deps = _deps(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    if (!await ReadingGate.ask(context)) return;
    if (!navigator.mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => _ParentArea(profiles: deps.profiles),
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

  /// Where "Set up a player" sits before there are any: between the stumps.
  Rect get firstSetup => Rect.fromCenter(
    center: Offset(size.width / 2, stumpTop(0).dy - diameter * 0.3),
    width: size.width * 0.5,
    height: diameter,
  );
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

/// Cooper's dev profile on the picker — internal builds only; a plain
/// tool badge, unmistakably not a child's.
class _DevBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _DevBadge({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Dev profile (internal)',
    child: GestureDetector(
      key: const ValueKey('dev-profile'),
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface.withValues(alpha: 0.85),
          border: Border.all(color: AppColors.cardEdge, width: 2),
        ),
        child: const Icon(Icons.build_rounded, color: AppColors.warmGray),
      ),
    ),
  );
}

/// Behind the adult door: the parent area, as it stands today — adding a
/// child, re-taking a child's setup (card 202), the credits. The fuller
/// settings area (exporting the tracking log, card 128; editing and
/// removing children) is not built; it slots in here.
class _ParentArea extends StatelessWidget {
  final ProfileState profiles;

  const _ParentArea({required this.profiles});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: profiles,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('For grown-ups'),
          backgroundColor: AppColors.background,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            ListTile(
              key: const ValueKey('parent-add-child'),
              leading: const Icon(Icons.person_add_alt_1_rounded),
              title: const Text('Add a child'),
              onTap: () async {
                final answers = await SetupQuizScreen.run(context);
                if (answers != null) await profiles.addChild(answers);
              },
            ),
            for (final child in profiles.childProfiles)
              ListTile(
                key: ValueKey('parent-retake-${child.id}'),
                leading: SizedBox.square(
                  dimension: 40,
                  child: AvatarBadge(index: child.avatarIndex),
                ),
                title: Text('Redo setup for ${child.name}'),
                subtitle: const Text(
                  'Name, picture, dragging, age. Their progress stays.',
                ),
                onTap: () async {
                  final answers = await SetupQuizScreen.run(
                    context,
                    initial: SetupAnswers.of(child),
                  );
                  if (answers != null) {
                    await profiles.retakeSetup(child, answers);
                  }
                },
              ),
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

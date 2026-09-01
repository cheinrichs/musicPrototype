import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/config.dart';
import '../../../app/router.dart';
import '../../../app/state/dev_settings_state.dart';
import '../../../app/state/progress_state.dart';
import '../../../app/state/skill_state.dart';
import '../../../models/agency_stage.dart';
import '../../../models/musical_skill.dart';
import '../../../models/game_status.dart';
import '../../../ui/components/circle_icon_button.dart';
import '../../../ui/components/dev_setup_overlay.dart';
import '../../../ui/components/game_screen_layout.dart';
import '../../../ui/components/glow_wiggle_character.dart';
import '../../../ui/components/progress_dots.dart';
import '../../../ui/theme/theme.dart';
import '../state/high_low_game_state.dart';

/// Main game screen for High/Low ear training.
///
/// Piper (the fox) and Clef (the animated treble clef) sit either side of
/// an illustrated forest clearing (assets/images/backgrounds/Forest.png),
/// flanking a randomized pair of instrument characters. The screen's
/// behavior is entirely driven by [HighLowGameState.agencyStage] (Trello
/// card 91): Observe narrates and never scores, Participate hints with a
/// sparkle, Trigger asks the child to drag Clef onto the answer. See
/// [HighLowGameState]'s class doc for the full stage breakdown — this
/// screen only renders what that state exposes, it doesn't duplicate the
/// stage logic.
///
/// A debug-only setup gate (Trello card 92) lets a developer pick the
/// stage/tier/round-order before the round starts; it only ever mounts
/// under [kDevMode] (`--dart-define=DEV_MODE=true`, e.g. `make
/// run-ios-dev`), so a shipping build always goes straight to the
/// production defaults.
class HighLowScreen extends StatefulWidget {
  const HighLowScreen({super.key});

  @override
  State<HighLowScreen> createState() => _HighLowScreenState();
}

class _HighLowScreenState extends State<HighLowScreen> {
  late HighLowGameState _gameState;
  bool _showDevGate = kDevMode;

  @override
  void initState() {
    super.initState();
    _gameState = HighLowGameState();
    _gameState.addListener(_onGameStateChanged);

    if (!kDevMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _gameState.startGame();
      });
    }
  }

  @override
  void dispose() {
    _gameState.removeListener(_onGameStateChanged);
    _gameState.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    if (_gameState.status == GameStatus.completed) {
      final progressState = context.read<ProgressState>();
      progressState.completeSession(
        gameType: 'high_low',
        correctCount: _gameState.correctCount,
        totalCount: _gameState.totalPrompts,
      );
      if (_gameState.correctCount >= 4) {
        context.read<SkillState>().awardXp(
          MusicalSkill.pitchAwareness,
          _gameState.correctCount * 10,
        );
      }

      final routeExtra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
      context.go(
        AppRoutes.reward,
        extra: {
          'correctCount': _gameState.correctCount,
          'totalCount': _gameState.totalPrompts,
          'gameType': 'high_low',
          'fromPath': routeExtra?['fromPath'] ?? false,
          'nodeId': routeExtra?['nodeId'],
        },
      );
    }
    setState(() {});
  }

  void _startFromDevGate() {
    final devSettings = context.read<DevSettingsState>();
    _gameState
      ..agencyStage = devSettings.agencyStage
      ..conceptTier = devSettings.conceptTier
      ..roundOrder = devSettings.roundOrder;
    setState(() => _showDevGate = false);
    _gameState.startGame();
  }

  /// Tapping an instrument is always exploration — see
  /// [HighLowGameState.tapInstrument].
  void _onInstrumentTap(int side) => _gameState.tapInstrument(side);

  /// Estimated fixed height of [_buildHeader]. Used to budget how much
  /// vertical space is actually left for the scrollable [GameScreenLayout]
  /// body so it can be scaled to fit instead of scrolling — see
  /// [_buildBody].
  static const double _headerHeight = 56;

  @override
  Widget build(BuildContext context) {
    if (_showDevGate) {
      // Debug-only pre-game gate (Trello card 92) — never reachable
      // outside kDevMode, so a shipping build never shows this.
      return Scaffold(body: DevSetupOverlay(onStart: _startFromDevGate));
    }

    return GameScreenLayout(
      background: Image.asset(
        'assets/images/backgrounds/Forest.png',
        fit: BoxFit.cover,
      ),
      header: _buildHeader(),
      body: _buildBody(context),
    );
  }

  /// The app is landscape-only, so the available height for everything
  /// between the header and the footer is tight and varies a lot by
  /// device. [GameScreenLayout] falls back to scrolling if the body
  /// overflows that space, but a kid mid-round shouldn't have to scroll to
  /// see the rest of the scene — so instead we measure the real budget and
  /// scale the whole scene down to fit it, uniformly, rather than letting
  /// any one piece get clipped or overlap its neighbors.
  Widget _buildBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final budget =
            media.size.height -
            media.padding.vertical -
            AppSpacing.sm * 2 -
            _headerHeight;

        return SizedBox(
          width: constraints.maxWidth,
          height: budget.clamp(160.0, 900.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPromptArea(),
                const SizedBox(height: AppSpacing.sm),
                _buildListenAgainButton(),
                const SizedBox(height: AppSpacing.sm),
                // FittedBox always lays its child out with unbounded (0..∞)
                // constraints, so pass the outer LayoutBuilder's real,
                // finite width down explicitly rather than re-measuring it
                // with a nested LayoutBuilder (see _buildScene's doc).
                _buildScene(constraints.maxWidth),
                const SizedBox(height: AppSpacing.xs),
                _buildStatusText(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CircleIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          onTap: () {
            final extra =
                GoRouterState.of(context).extra as Map<String, dynamic>?;
            if (extra?['fromPath'] == true) {
              context.read<ProgressState>().requestPathReturn();
            }
            context.go(AppRoutes.home);
          },
        ),
        ProgressDots(
          totalDots: _gameState.totalPrompts,
          currentIndex: _gameState.currentPromptIndex,
          results: _gameState.results.map((r) => r.isCorrect).toList(),
        ),
        // Move-on arrow: available from the very start of every round, at
        // every stage — it exists so an adult can advance a tiring child
        // past a round that (in Observe/Participate) never auto-advances
        // on its own. Never gated on game phase (Trello card 91).
        CircleIconButton(
          icon: Icons.arrow_forward_rounded,
          tooltip: 'Move on',
          onTap: _gameState.status == GameStatus.completed
              ? null
              : _gameState.moveOn,
        ),
      ],
    );
  }

  /// The current round's spoken-line placeholder (Observe's live
  /// narration, or the constant Participate/Trigger prompt, or a brief
  /// retry line) — see [VoiceLine] for why this is text today.
  Widget _buildPromptArea() {
    final text = _gameState.captionText;
    return SizedBox(
      height: 64,
      child: Center(
        child: AnimatedSwitcher(
          duration: AppAnimations.medium,
          child: text == null
              ? const SizedBox.shrink(key: ValueKey('caption-empty'))
              : Container(
                  key: ValueKey('caption-$text'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.cardGradient,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: AppColors.cardEdge, width: 2),
                  ),
                  child: Text(
                    text,
                    style: AppTypography.heading3,
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildListenAgainButton() {
    final canReplay =
        _gameState.status != GameStatus.completed &&
        _gameState.status != GameStatus.showingFeedback;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: canReplay ? _gameState.replay : null,
          child: AnimatedOpacity(
            opacity: canReplay ? 1 : 0.5,
            duration: AppAnimations.fast,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardEdge, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.volume_up_rounded,
                color: AppColors.secondary,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text('Listen Again', style: AppTypography.label),
      ],
    );
  }

  /// [width] is the *real* available width, measured by the outer
  /// LayoutBuilder in [_buildBody] — see the original implementation note
  /// this preserves: a LayoutBuilder nested inside the FittedBox subtree
  /// below would see `maxWidth: infinity` regardless of the real layout,
  /// silently corrupting the Stack's sizing (Trello card 46).
  Widget _buildScene(double width) {
    final screenHeight = MediaQuery.of(context).size.height;
    final charSize = screenHeight * 0.66;
    final piperHeight = screenHeight * 0.47;
    final clefHeight = screenHeight * 0.29;
    // How far above the ground line (Piper/Clef's feet) the stump tops
    // sit, measured off a rendered screenshot of Forest.png.
    final stumpLift = screenHeight * 0.16;
    final sceneHeight = charSize + stumpLift;
    final isTrigger = _gameState.agencyStage == AgencyStage.trigger;
    final prompt = _gameState.currentPrompt;

    return SizedBox(
      width: width,
      height: sceneHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Piper (fox) — fixed far-left, always. Which instrument she
          // "belongs to" (the low one) is a matter of the instrument's own
          // wiggle/glow and the caption, not her screen position — see
          // the class doc.
          Positioned(
            left: 0,
            bottom: 0,
            child: Image.asset(
              'assets/images/characters/Piper_Encouraging.png',
              height: piperHeight,
              fit: BoxFit.contain,
            ).animate().fade(duration: AppAnimations.medium),
          ),
          _buildClef(clefHeight, isTrigger),
          Positioned(
            left: width * 0.30 - charSize / 2,
            bottom: stumpLift,
            child: _wrapDragTarget(
              side: 0,
              child: _InstrumentButton(
                key: ValueKey('left-${_gameState.leftInstrument.name}'),
                assetPath: _gameState.leftInstrument.leftAssetPath,
                size: charSize,
                glowing: _gameState.playingIndex == 0,
                feedback: _feedbackFor(0),
                showSparkle: _gameState.showHint && prompt?.targetSide == 0,
                onTap: () => _onInstrumentTap(0),
              ),
            ),
          ),
          Positioned(
            left: width * 0.735 - charSize / 2,
            bottom: stumpLift,
            child: _wrapDragTarget(
              side: 1,
              child: _InstrumentButton(
                key: ValueKey('right-${_gameState.rightInstrument.name}'),
                assetPath: _gameState.rightInstrument.rightAssetPath,
                size: charSize,
                glowing: _gameState.playingIndex == 1,
                feedback: _feedbackFor(1),
                showSparkle: _gameState.showHint && prompt?.targetSide == 1,
                onTap: () => _onInstrumentTap(1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Clef: fixed far-right (Observe/Participate) or a centered, draggable
  /// answer (Trigger — starting centered rather than on either side keeps
  /// the drag distance to both instruments equal, per the design brief).
  Widget _buildClef(double clefHeight, bool isTrigger) {
    final clefImage = Image.asset(
      'assets/images/characters/Clef.png',
      height: clefHeight,
    );
    final bobbing = clefImage
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: -6,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOut,
        );

    if (!isTrigger) {
      return Positioned(right: 0, bottom: 0, child: bobbing);
    }

    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Draggable<Object>(
          data: 'clef',
          feedback: Opacity(opacity: 0.85, child: clefImage),
          childWhenDragging: Opacity(opacity: 0.3, child: clefImage),
          child: bobbing,
        ),
      ),
    );
  }

  Widget _wrapDragTarget({required int side, required Widget child}) {
    if (_gameState.agencyStage != AgencyStage.trigger) return child;
    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) => _gameState.canDropClef,
      onAcceptWithDetails: (_) => _gameState.dropClef(side),
      builder: (context, candidateData, rejectedData) {
        return AnimatedScale(
          scale: candidateData.isNotEmpty ? 1.06 : 1.0,
          duration: AppAnimations.fast,
          child: child,
        );
      },
    );
  }

  /// Drop feedback for a side, from [HighLowGameState.dragFeedback] +
  /// [HighLowGameState.lastDropSide] — Trigger-only.
  _CharacterFeedback? _feedbackFor(int side) {
    if (_gameState.dragFeedback == DragFeedback.none) return null;
    if (_gameState.lastDropSide != side) return null;
    return _gameState.dragFeedback == DragFeedback.correct
        ? _CharacterFeedback.correct
        : _CharacterFeedback.retry;
  }

  Widget _buildStatusText() {
    String text;
    switch (_gameState.status) {
      case GameStatus.notStarted:
        text = 'Get ready...';
      case GameStatus.playing:
        text = 'Listen carefully...';
      case GameStatus.awaitingInput:
        text = '';
      case GameStatus.showingFeedback:
        text = _gameState.dragFeedback == DragFeedback.correct
            ? 'Great job!'
            : '';
      case GameStatus.completed:
        text = 'Well done!';
    }

    return Text(text, style: AppTypography.bodyMedium)
        .animate(
          key: ValueKey('${_gameState.status}-${_gameState.dragFeedback}'),
        )
        .fade(duration: AppAnimations.fast);
  }
}

enum _CharacterFeedback { correct, retry }

/// An instrument character sitting on a stump — glows and wiggles (via the
/// shared [GlowWiggleCharacter] treatment, same as the Sound Playground)
/// while its note plays, always tappable (tapping is pure exploration —
/// see [HighLowGameState]), and optionally sparkling as a Participate-stage
/// hint.
class _InstrumentButton extends StatelessWidget {
  final String assetPath;
  final double size;
  final bool glowing;
  final _CharacterFeedback? feedback;
  final bool showSparkle;
  final VoidCallback onTap;

  const _InstrumentButton({
    super.key,
    required this.assetPath,
    required this.size,
    required this.glowing,
    required this.feedback,
    required this.showSparkle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color glowColor;
    if (feedback == _CharacterFeedback.correct) {
      glowColor = AppColors.correct;
    } else if (feedback == _CharacterFeedback.retry) {
      // Gentle amber, not the harsh "incorrect" rose — a wrong drop is
      // never a failure state (Trello card 91).
      glowColor = AppColors.gold;
    } else {
      glowColor = AppColors.gold;
    }
    final showGlow = glowing || feedback != null;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            GlowWiggleCharacter(
              size: size,
              isActive: showGlow,
              glowColor: glowColor,
              wiggleWhenIdle: false,
              child: feedback == _CharacterFeedback.retry
                  ? Image.asset(assetPath, fit: BoxFit.contain)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .shake(hz: 3, offset: const Offset(6, 0))
                  : Image.asset(assetPath, fit: BoxFit.contain),
            ),
            Positioned(
              top: -size * 0.15,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: glowing ? 1 : 0,
                  duration: AppAnimations.fast,
                  child: _DriftingNotes(size: size),
                ),
              ),
            ),
            if (showSparkle)
              Positioned(
                top: -size * 0.1,
                right: -size * 0.05,
                child: IgnorePointer(
                  child: Text('✨', style: TextStyle(fontSize: size * 0.22))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1.15, 1.15),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeInOut,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Two small music notes that drift up and fade while an instrument's note
/// is sounding. Deliberately understated — this is a listening game for
/// young children, so the motion must read as a light echo of the sound,
/// not compete with it for attention.
class _DriftingNotes extends StatelessWidget {
  final double size;

  const _DriftingNotes({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _note(left: size * 0.12, delay: Duration.zero, dx: -size * 0.12),
          _note(
            left: size * 0.58,
            delay: const Duration(milliseconds: 400),
            dx: size * 0.12,
          ),
        ],
      ),
    );
  }

  Widget _note({
    required double left,
    required Duration delay,
    required double dx,
  }) {
    return Positioned(
      left: left,
      bottom: 0,
      child:
          Text(
                '♪',
                style: TextStyle(fontSize: size * 0.2, color: AppColors.gold),
              )
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(delay: delay, duration: const Duration(milliseconds: 250))
              .moveY(
                begin: 0,
                end: -size * 0.5,
                delay: delay,
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOut,
              )
              .moveX(
                begin: 0,
                end: dx,
                delay: delay,
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOut,
              )
              .fadeOut(
                delay: delay + const Duration(milliseconds: 700),
                duration: const Duration(milliseconds: 400),
              ),
    );
  }
}

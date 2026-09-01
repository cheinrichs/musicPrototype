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
import '../../../ui/components/drifting_notes.dart';
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
/// sparkle, Trigger asks the child to drag the target's narrator (Piper or
/// Clef, whichever owns that round's pole — Trello card 101) onto the
/// answer. See
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
      // The scene (stumps' instruments + flanking Piper/Clef) is composed
      // into the *background* layer, not the body — see [_buildScene] for
      // why: it needs to be sized and positioned straight off the real,
      // unscaled screen so it lines up with where Forest.png's own stumps
      // land under BoxFit.cover, immune to whatever the caption/controls
      // above it need to shrink to (Trello card 56 — this rendered fine at
      // roomy heights and drifted apart from the background at tight
      // ones, which is exactly the "shrinks toward center while the
      // background doesn't" signature of the old approach).
      background: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/Forest.png',
            fit: BoxFit.cover,
          ),
          _buildScene(context),
        ],
      ),
      header: _buildHeader(),
      body: _buildBody(context),
    );
  }

  /// The app is landscape-only, so the available height for everything
  /// between the header and the footer is tight and varies a lot by
  /// device. [GameScreenLayout] falls back to scrolling if the body
  /// overflows that space, but a kid mid-round shouldn't have to scroll to
  /// see the rest of it — so instead we measure the real budget and scale
  /// the caption/listen-again/status group down to fit it, uniformly,
  /// rather than letting any one piece get clipped or overlap its
  /// neighbors. The scene itself isn't part of this Column any more — see
  /// [_buildScene].
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
            // Top-aligned, not the default center (Trello card S1v6sbrK):
            // this box claims the full body height, and centering the
            // scaled-down content within it put the caption right across
            // the play area, blocking the drag path to the instruments and
            // covering the Listen Again label. Hugging the top keeps it
            // tucked under the header, out of the stumps' space.
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPromptArea(),
                const SizedBox(height: AppSpacing.sm),
                _buildListenAgainButton(),
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

  /// The stumps' instruments, flanked by Piper and Clef further out —
  /// composed straight into [GameScreenLayout]'s full-bleed `background`
  /// layer (Trello card 56), sized and positioned directly off
  /// `MediaQuery.size` rather than off whatever width/height the caption
  /// and controls above happen to leave in the body's flex layout. That
  /// distinction matters: this used to live inside the body's
  /// budget-constrained `FittedBox`, which scales its child down evenly
  /// around its *center* to make it fit — on a roomy screen that shrink
  /// was mild and this looked fine, but on a short one it shrank hard
  /// enough that the scene's own "ground" drifted noticeably up and away
  /// from Forest.png's actual, un-shrunk stumps (which live in a sibling
  /// layer the FittedBox never touches), leaving instruments visibly
  /// floating above them and pulling Piper/Clef in over the stumps
  /// instead of outside them. Sizing and positioning here directly off
  /// the real screen makes the scene invariant to that shrink entirely.
  Widget _buildScene(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    // Proportions of screen height, per the concept art (Trello card 56).
    // Instruments stay put on the stumps (Trello card S1v6sbrK — "in the
    // right place, don't move them"); Piper and Clef are doubled (Trello
    // card OCv6kVmd) from their original roughly-a-third/roughly-a-fifth
    // sizing.
    final charSize = screenHeight * 0.50;
    final piperHeight = screenHeight * 0.72;
    final clefHeight = screenHeight * 0.44;
    // Distance from the screen's bottom edge up to the stumps' flat top
    // surface, calibrated against an actual ~2.17:1 render of Forest.png
    // under BoxFit.cover (Trello card 56 — analytical crop math from the
    // source painting's own measurements kept landing off by a wide
    // margin, so this is read directly off the rendered frame instead).
    final stumpLift = screenHeight * 0.205;
    // How far above the screen's bottom edge (and, for the fixed home
    // spots, how far further outward past the screen's side edge) Piper
    // and Clef sit — raised and pushed outward from their old flush-corner
    // spots (Trello card S1v6sbrK: Piper's home was circled up-and-left of
    // where she stood, Clef's up-and-right of hers; the drag round's
    // centered character was sitting below the stump line entirely).
    final homeLift = screenHeight * 0.08;
    final homeShift = screenWidth * 0.04;
    final isTrigger = _gameState.agencyStage == AgencyStage.trigger;
    final prompt = _gameState.currentPrompt;
    // Trigger-only: whichever character owns this round's target pole is
    // the one centered and dragged (Trello card 101) — the other stays put
    // at its normal fixed spot, same as Observe/Participate.
    final piperIsDragged = isTrigger && _gameState.draggedIsPiper;
    final clefIsDragged = isTrigger && !_gameState.draggedIsPiper;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildPiper(
          piperHeight,
          piperIsDragged,
          homeLift,
          homeShift,
          stumpLift,
        ),
        _buildClef(clefHeight, clefIsDragged, homeLift, homeShift, stumpLift),
        Positioned(
          left: screenWidth * 0.29 - charSize / 2,
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
          left: screenWidth * 0.72 - charSize / 2,
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
    );
  }

  /// Clef: fixed far-right, unless she's this round's dragged answer
  /// ([isDragged] — Clef owns the high pole, Trello card 101), in which
  /// case she starts centered rather than on either side, which keeps the
  /// drag distance to both instruments equal, per the design brief. Bobs
  /// continuously either way — that idle motion is Clef's own character
  /// beat, not a "you can drag me" cue.
  Widget _buildClef(
    double clefHeight,
    bool isDragged,
    double homeLift,
    double homeShift,
    double dragLift,
  ) {
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

    if (!isDragged) {
      return Positioned(right: -homeShift, bottom: homeLift, child: bobbing);
    }
    return _buildDragHandle(image: clefImage, bobbing: bobbing, lift: dragLift);
  }

  /// Piper: fixed far-left, unless she's this round's dragged answer
  /// ([isDragged] — Piper owns the low pole, Trello card 101) — see
  /// [_buildClef] for why the dragged character starts centered. Unlike
  /// Clef, Piper doesn't idle-bob while fixed; only picks up motion once
  /// she's the one being dragged.
  Widget _buildPiper(
    double piperHeight,
    bool isDragged,
    double homeLift,
    double homeShift,
    double dragLift,
  ) {
    final piperImage = Image.asset(
      'assets/images/characters/Piper_Encouraging.png',
      height: piperHeight,
      fit: BoxFit.contain,
    );

    if (!isDragged) {
      return Positioned(
        left: -homeShift,
        bottom: homeLift,
        child: piperImage.animate().fade(duration: AppAnimations.medium),
      );
    }

    final bobbing = piperImage
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: -6,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOut,
        );
    return _buildDragHandle(
      image: piperImage,
      bobbing: bobbing,
      lift: dragLift,
    );
  }

  /// Wraps a character as the centered, draggable answer — shared by
  /// [_buildClef] and [_buildPiper] (Trello card 101: either can be this
  /// round's dragged character, depending on the target pole). [image] is
  /// the plain (unanimated) art used for the drag feedback/left-behind
  /// ghost; [bobbing] is the same art with the idle bob, used at rest.
  /// [lift] raises it off the very bottom edge to the same stump-top line
  /// the instruments sit on (Trello card S1v6sbrK — it used to sit flush
  /// against the bottom edge, below the stump line).
  Widget _buildDragHandle({
    required Widget image,
    required Widget bobbing,
    required double lift,
  }) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: lift,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Draggable<Object>(
          data: 'narrator',
          feedback: Opacity(opacity: 0.85, child: image),
          childWhenDragging: Opacity(opacity: 0.3, child: image),
          child: bobbing,
        ),
      ),
    );
  }

  Widget _wrapDragTarget({required int side, required Widget child}) {
    if (_gameState.agencyStage != AgencyStage.trigger) return child;
    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) => _gameState.canDrop,
      onAcceptWithDetails: (_) => _gameState.dropOnSide(side),
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

/// An instrument character sitting on a stump — grows and releases drifting
/// notes (via the shared [GlowWiggleCharacter]/[DriftingNotes] treatment,
/// same as the Sound Playground — Trello card 96) while its note plays,
/// always tappable (tapping is pure exploration — see [HighLowGameState]),
/// and optionally sparkling as a Participate-stage hint.
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
    final isActive = glowing || feedback != null;

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
              isActive: isActive,
              wiggleWhenIdle: false,
              child: feedback == _CharacterFeedback.retry
                  ? Image.asset(assetPath, fit: BoxFit.contain)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .shake(hz: 3, offset: const Offset(6, 0))
                  : Image.asset(assetPath, fit: BoxFit.contain),
            ),
            Positioned(
              top: -size * 0.15,
              child: DriftingNotes(size: size, active: glowing),
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

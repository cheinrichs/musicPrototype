import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/router.dart';
import '../../../app/state/progress_state.dart';
import '../../../app/state/skill_state.dart';
import '../../../models/musical_skill.dart';
import '../../../models/game_status.dart';
import '../../../models/pitch_direction.dart';
import '../../../ui/components/circle_icon_button.dart';
import '../../../ui/components/game_screen_layout.dart';
import '../../../ui/components/glow_wiggle_character.dart';
import '../../../ui/components/progress_dots.dart';
import '../../../ui/theme/theme.dart';
import '../models/high_low_instrument.dart';
import '../state/high_low_game_state.dart';

/// Main game screen for High/Low ear training.
///
/// Redesigned per the Trello concept art: two characters sit on stumps in
/// an illustrated forest clearing (SongStone-UI-Kit/Assets/Backgrounds/
/// Forest.png). Piper (the fox) and Clef (the animated treble clef —
/// replacement for the deprecated "blob" character) flank the scene. The
/// left character always plays the first note, the right character the
/// second; the child taps whichever one they think played the higher note
/// instead of choosing from Higher/Lower buttons. Which instrument pair
/// shows (guitar, piano, violin, ...) is randomized each round — see
/// [HighLowInstrument].
class HighLowScreen extends StatefulWidget {
  const HighLowScreen({super.key});

  @override
  State<HighLowScreen> createState() => _HighLowScreenState();
}

class _HighLowScreenState extends State<HighLowScreen> {
  late HighLowGameState _gameState;

  @override
  void initState() {
    super.initState();
    _gameState = HighLowGameState();
    _gameState.addListener(_onGameStateChanged);

    // Start the game automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameState.startGame();
    });
  }

  @override
  void dispose() {
    _gameState.removeListener(_onGameStateChanged);
    _gameState.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    if (_gameState.status == GameStatus.completed) {
      // Record progress
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

      // Navigate to reward screen, forwarding path context if present.
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

  /// Tapping a character submits an answer. Left = "the first note was
  /// higher" (PitchDirection.lower, since correctness is defined relative
  /// to whether the *second* note was higher). Right = "the second note
  /// was higher" (PitchDirection.higher).
  void _onCharacterTap(int side) {
    if (_gameState.status != GameStatus.awaitingInput) return;
    _gameState.submitAnswer(
      side == 0 ? PitchDirection.lower : PitchDirection.higher,
    );
  }

  /// Estimated fixed height of [_buildHeader]. Used to budget how much
  /// vertical space is actually left for the scrollable [GameScreenLayout]
  /// body so it can be scaled to fit instead of scrolling — see
  /// [_buildBody].
  static const double _headerHeight = 56;

  @override
  Widget build(BuildContext context) {
    return GameScreenLayout(
      // Illustrated forest clearing — SongStone-UI-Kit
      // Assets/Backgrounds/Forest.png (two stumps, matches the concept
      // art 1:1).
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
                _buildQuestionText(),
                const SizedBox(height: AppSpacing.sm),
                _buildListenAgainButton(),
                const SizedBox(height: AppSpacing.sm),
                // FittedBox always lays its child out with unbounded (0..∞)
                // constraints so it can measure a "natural" size to scale —
                // that's true no matter how tightly *this* LayoutBuilder is
                // itself constrained. _buildScene used to read its own
                // width from a LayoutBuilder nested in here, which saw
                // maxWidth: infinity and silently produced a degenerate
                // layout (see _buildScene's doc comment). Pass the real,
                // finite width down from this outer LayoutBuilder instead.
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
        // Close button
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
        // Progress stepper
        ProgressDots(
          totalDots: _gameState.totalPrompts,
          currentIndex: _gameState.currentPromptIndex,
          results: _gameState.results.map((r) => r.isCorrect).toList(),
        ),
        // Skip button
        CircleIconButton(
          icon: Icons.skip_next_rounded,
          tooltip: 'Skip',
          onTap: _gameState.status == GameStatus.awaitingInput
              ? _gameState.skipPrompt
              : null,
        ),
      ],
    );
  }

  Widget _buildQuestionText() {
    final name = _gameState.currentInstrument.displayName;
    return Column(
      children: [
        Text(
              'Which $name played\na higher note?',
              style: AppTypography.heading3,
              textAlign: TextAlign.center,
            )
            .animate(key: ValueKey('question-$name'))
            .fade(duration: AppAnimations.medium)
            .slideY(begin: -0.1, end: 0, duration: AppAnimations.medium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Listen carefully and touch the $name\nthat played the higher note.',
          style: AppTypography.label,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildListenAgainButton() {
    final canReplay = _gameState.status == GameStatus.awaitingInput;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: canReplay ? _gameState.replayPrompt : null,
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
  /// LayoutBuilder in [_buildBody] — not by a LayoutBuilder nested in here.
  ///
  /// This whole subtree sits inside a FittedBox (see [_buildBody]), and
  /// FittedBox always lays its child out with unbounded constraints so it
  /// can measure an unconstrained "natural" size to scale down. A
  /// LayoutBuilder nested inside that subtree would see `maxWidth:
  /// infinity` no matter how this screen is actually laid out on a real
  /// device — that was the card-35 regression (card 46): it silently
  /// corrupted this method's own width-based sizing, *and* left the
  /// returned [Stack] below with no explicit width for the same reason
  /// (every child is `Positioned`, so with no non-positioned child to size
  /// off, Stack falls back to `constraints.biggest`, which is infinite
  /// here — and then to `constraints.smallest`, i.e. zero). A zero-width
  /// Stack squeezes the `Positioned(left: 0, right: 0, ...)` instrument Row
  /// to zero, which is what painted the stray overflow bar on the left
  /// edge, and corrupted the whole Column's measured size that FittedBox
  /// uses to place everything else. Giving the SizedBox below an explicit,
  /// finite width breaks that dependency on ambient constraints.
  Widget _buildScene(double width) {
    // Sizing and layout below are lifted from Cooper's Trello concept art
    // (card 56), measured as fractions of *screen* height — the concept
    // art is ~4:3 and this screen is much wider once landscape, so only
    // the vertical proportions transfer; horizontal placement is instead
    // measured directly off Forest.png as actually rendered (BoxFit.cover
    // crops its top/bottom on this aspect ratio, so the stumps don't sit
    // where a naive fraction of the *source* image would suggest).
    // Nominal fractions are bumped above the concept art's raw numbers
    // (0.51 / 0.36 / 0.22 / 0.12) to compensate for this Column being
    // scaled down by the FittedBox in _buildBody to fit under the
    // heading/subtitle/button above it — verified empirically on the
    // simulator against Forest.png's actual rendered stump position, not
    // derived analytically.
    final screenHeight = MediaQuery.of(context).size.height;
    final charSize = screenHeight * 0.66;
    final piperHeight = screenHeight * 0.47;
    final clefHeight = screenHeight * 0.29;
    // How far above the ground line (Piper/Clef's feet) the stump tops
    // sit, measured off a rendered screenshot of Forest.png.
    final stumpLift = screenHeight * 0.16;
    final instrument = _gameState.currentInstrument;
    final sceneHeight = charSize + stumpLift;

    return SizedBox(
      width: width,
      height: sceneHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Piper (fox) — full-body "Encouraging" pose, far left edge,
          // feet on the ground line (bottom of this box).
          Positioned(
            left: 0,
            bottom: 0,
            child: Image.asset(
              'assets/images/characters/Piper_Encouraging.png',
              height: piperHeight,
              fit: BoxFit.contain,
            ).animate().fade(duration: AppAnimations.medium),
          ),
          // Clef — far right edge, same ground line as Piper.
          Positioned(
            right: 0,
            bottom: 0,
            child:
                Image.asset(
                      'assets/images/characters/Clef.png',
                      height: clefHeight,
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(
                      begin: 0,
                      end: -6,
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeInOut,
                    ),
          ),
          // Instrument pair, each centered on its stump — lifted above
          // the Piper/Clef ground line by [stumpLift] so they sit *on
          // top of* the stumps instead of in the gap between them.
          // x-fractions measured off the rendered background, not evenly
          // split, since the stumps aren't perfectly centered.
          Positioned(
            left: width * 0.30 - charSize / 2,
            bottom: stumpLift,
            child: _InstrumentButton(
              key: ValueKey('left-${instrument.name}'),
              assetPath: instrument.leftAssetPath,
              size: charSize,
              glowing: _gameState.playingIndex == 0,
              feedback: _feedbackFor(0),
              enabled: _gameState.status == GameStatus.awaitingInput,
              onTap: () => _onCharacterTap(0),
            ),
          ),
          Positioned(
            left: width * 0.735 - charSize / 2,
            bottom: stumpLift,
            child: _InstrumentButton(
              key: ValueKey('right-${instrument.name}'),
              assetPath: instrument.rightAssetPath,
              size: charSize,
              glowing: _gameState.playingIndex == 1,
              feedback: _feedbackFor(1),
              enabled: _gameState.status == GameStatus.awaitingInput,
              onTap: () => _onCharacterTap(1),
            ),
          ),
        ],
      ),
    );
  }

  /// Correct/incorrect glow for a character side while feedback is showing.
  _CharacterFeedback? _feedbackFor(int side) {
    if (_gameState.status != GameStatus.showingFeedback) return null;
    final result = _gameState.lastResult;
    if (result == null) return null;

    // side 0 (left) is correct when the answer was "lower" (first note
    // higher); side 1 (right) is correct when the answer was "higher".
    final correctSide = result.prompt.correctAnswer == PitchDirection.higher
        ? 1
        : 0;
    if (side == correctSide) return _CharacterFeedback.correct;
    if (side == (result.userAnswer == PitchDirection.higher ? 1 : 0)) {
      return _CharacterFeedback.incorrect;
    }
    return null;
  }

  Widget _buildStatusText() {
    String text;
    switch (_gameState.status) {
      case GameStatus.notStarted:
        text = 'Get ready...';
      case GameStatus.playing:
        text = 'Listen carefully...';
      // No hint text once awaiting input (Trello card 56) — the question
      // heading above already tells the child what to listen for.
      case GameStatus.awaitingInput:
        text = '';
      case GameStatus.showingFeedback:
        final isCorrect = _gameState.lastResult?.isCorrect ?? false;
        text = isCorrect ? 'Great job!' : 'Try the next one!';
      case GameStatus.completed:
        text = 'Well done!';
    }

    return Text(text, style: AppTypography.bodyMedium)
        .animate(key: ValueKey(_gameState.status))
        .fade(duration: AppAnimations.fast);
  }
}

enum _CharacterFeedback { correct, incorrect }

/// An instrument character sitting on a stump — glows and wiggles (via the
/// shared [GlowWiggleCharacter] treatment, same as the Sound Playground)
/// while its note plays, and tappable once the round is awaiting an
/// answer.
class _InstrumentButton extends StatelessWidget {
  final String assetPath;
  final double size;
  final bool glowing;
  final _CharacterFeedback? feedback;
  final bool enabled;
  final VoidCallback onTap;

  const _InstrumentButton({
    super.key,
    required this.assetPath,
    required this.size,
    required this.glowing,
    required this.feedback,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color glowColor;
    if (feedback == _CharacterFeedback.correct) {
      glowColor = AppColors.correct;
    } else if (feedback == _CharacterFeedback.incorrect) {
      glowColor = AppColors.incorrect;
    } else {
      glowColor = AppColors.gold;
    }
    final showGlow = glowing || feedback != null;

    return GestureDetector(
      onTap: enabled ? onTap : null,
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
              child: Image.asset(assetPath, fit: BoxFit.contain),
            ),
            // Always mounted (so its endless-loop animation isn't
            // restarted — and re-timered — on every play/stop cycle) but
            // only visible while this side's note is actually sounding —
            // a light visual echo of the audio, not the answer feedback.
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
          ],
        ),
      ),
    );
  }
}

/// Two small music notes that drift up and fade while an instrument's note
/// is sounding (Trello card 58). Deliberately understated — this is a
/// listening game for young children, so the motion must read as a light
/// echo of the sound, not compete with it for attention.
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

  Widget _note({required double left, required Duration delay, required double dx}) {
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

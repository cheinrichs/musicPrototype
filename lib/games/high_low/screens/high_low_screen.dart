import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/build_info.dart';
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
import '../models/round_report.dart';
import '../services/round_report_service.dart';
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
/// when `devToolsEnabled` (see `app/config.dart` — true for TestFlight and
/// local debug runs, false for a public App Store build) is true, so a
/// public build always goes straight to the production defaults.
class HighLowScreen extends StatefulWidget {
  const HighLowScreen({super.key});

  @override
  State<HighLowScreen> createState() => _HighLowScreenState();
}

class _HighLowScreenState extends State<HighLowScreen> {
  late HighLowGameState _gameState;
  bool _showDevGate = devToolsEnabled;

  /// Which side (0/1) a drag is currently hovering over, for the
  /// instrument's little "you're about to drop here" scale-up — purely a
  /// transient UI cue, not game state, so it lives here rather than on
  /// [HighLowGameState]. See [_buildDropZone].
  int? _hoveredDropSide;

  /// Boundary for "Report this round"'s screenshot — see
  /// [RoundReportService.shareReport]. Wraps the whole screen (below), not
  /// just the scene, so the captured image matches what's actually on
  /// screen when the button is tapped.
  final GlobalKey _screenshotKey = GlobalKey();

  /// The report button's own render box — its on-screen rect is where the
  /// iOS share sheet pops over from on iPad/Mac Catalyst. See
  /// [_onReportRound].
  final GlobalKey _reportButtonKey = GlobalKey();

  /// True while [_onReportRound] is capturing/writing/opening the share
  /// sheet — drives the button's spinner (Cooper: "a tap with no immediate
  /// visual acknowledgement feels broken").
  bool _sharingReport = false;

  @override
  void initState() {
    super.initState();
    _gameState = HighLowGameState();
    _gameState.addListener(_onGameStateChanged);

    if (!devToolsEnabled) {
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

  @override
  Widget build(BuildContext context) {
    if (_showDevGate) {
      // Debug-only pre-game gate (Trello card 92) — never reachable
      // unless devToolsEnabled, so a public App Store build never shows
      // this.
      return Scaffold(body: DevSetupOverlay(onStart: _startFromDevGate));
    }

    return RepaintBoundary(
      key: _screenshotKey,
      child: GameScreenLayout(
        // The scene (stumps' instruments + flanking Piper/Clef) is
        // composed into the *background* layer, not the body — see
        // [_buildScene] for why: it needs to be sized and positioned
        // straight off the real, unscaled screen so it lines up with
        // where Forest.png's own stumps land under BoxFit.cover, immune
        // to whatever the caption/controls above it need to shrink to
        // (Trello card 56 — this rendered fine at roomy heights and
        // drifted apart from the background at tight ones, which is
        // exactly the "shrinks toward center while the background
        // doesn't" signature of the old approach).
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/backgrounds/MeadowWidescreen.png',
              fit: BoxFit.cover,
            ),
            _buildScene(context),
          ],
        ),
        header: _buildHeader(),
        body: _buildBody(context),
        footer: ProgressDots(
          totalDots: _gameState.totalPrompts,
          currentIndex: _gameState.currentPromptIndex,
          completedCount: _gameState.results.length,
        ),
        // _buildBody already guarantees it never overflows its own budget
        // (FittedBox(fit: scaleDown) inside a SizedBox sized off the real
        // available height) — GameScreenLayout's scroll-fallback isn't
        // needed here, and worse, actively broke the drag-to-answer
        // interaction: a Scrollable hit-tests its whole viewport, not
        // just where it paints, so it sat in front of `background` and
        // silently ate every touch meant for the characters/instruments
        // underneath before Trigger's drag gesture could ever start. See
        // [GameScreenLayout.scrollableBody].
        scrollableBody: false,
      ),
    );
  }

  /// The app is landscape-only, so the available height for everything
  /// between the header and the footer is tight and varies a lot by
  /// device. Now that the caption lives in [_buildHeader] instead of here
  /// (Trello card "Separate the stumps from the background art" — it used
  /// to sit stacked directly on top of the Listen Again button and the
  /// "Listen carefully..." status line), this body is just Listen
  /// Again + status, and [constraints.maxHeight] from the enclosing
  /// `Expanded` is already the accurate leftover space between the
  /// header and the [ProgressDots] footer — no need to re-derive it from
  /// `MediaQuery` and a guessed header height. Still scaled down to fit
  /// via [FittedBox] rather than scrolling, for the same reason as before:
  /// a kid mid-round shouldn't have to scroll to see Listen Again.
  ///
  /// Top-aligned, not the default center: [GameScreenLayout] centers this
  /// whole body vertically in the space between the header and the
  /// footer, and Trigger's centered, dragged narrator (Clef or Piper,
  /// [_buildDragHandle]) stands tall enough — up to 72% of the screen
  /// height — to reach exactly that vertical middle too. Centering here
  /// sat Listen Again right behind the dragged character's head; hugging
  /// the top instead keeps it tucked under the header, above where either
  /// character's head reaches.
  Widget _buildBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final budget = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height * 0.3;

        return SizedBox(
          width: constraints.maxWidth,
          height: budget.clamp(80.0, 900.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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

  /// Close (left), the round's caption (center, see [_buildPromptArea]),
  /// and the child's move-on/skip pill plus (dev builds only) the report
  /// button (right) — [ProgressDots] used to sit in this row's center slot,
  /// but moved down to [GameScreenLayout]'s `footer` (see `build`) to make
  /// room for the caption, matching the mockup layout (Trello card
  /// "Separate the stumps from the background art"): question at the top,
  /// progress dots along the bottom.
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        Expanded(child: _buildPromptArea()),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dev-only report button (Trello card on0EymSu) — gated the
            // same way as the dev gate above, so a public App Store build
            // never shows it.
            if (devToolsEnabled) ...[
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleIconButton(
                    key: _reportButtonKey,
                    icon: Icons.ios_share_rounded,
                    tooltip: 'Report this round',
                    onTap: _gameState.currentPrompt == null || _sharingReport
                        ? null
                        : _onReportRound,
                  ),
                  // Immediate acknowledgement that the tap landed — a slow
                  // capture-and-share otherwise gives no feedback at all
                  // until (or unless) the share sheet finally appears.
                  if (_sharingReport)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            _buildSkipPill(),
          ],
        ),
      ],
    );
  }

  /// Captures the current round's full state (Trello card on0EymSu) and
  /// opens the share sheet — see [RoundReportService.shareReport]. Never
  /// reachable outside devToolsEnabled (same guard as the dev gate), and
  /// never touches the network: local JSON + PNG, handed off through
  /// whatever the grown-up picks in the OS share sheet.
  ///
  /// Wrapped in try/catch/finally (Cooper: "when I click the send button,
  /// nothing appears to happen") — before this, any failure anywhere in the
  /// chain propagated out of a fire-and-forget `onTap` and was silently
  /// dropped by Flutter's default unhandled-Future-error handling: no
  /// crash, no dialog, nothing on screen. The actual failure turned out to
  /// be `Share.shareXFiles` never getting a `sharePositionOrigin` — on
  /// iPad/Mac Catalyst, `share_plus`'s iOS side presents the share sheet as
  /// a popover and returns a hard error instead of showing anything when
  /// it has no source rect to anchor to. This now always passes the report
  /// button's own on-screen rect (harmless on iPhone, where the parameter
  /// has no effect either way), and surfaces any *other* failure as a
  /// SnackBar instead of failing silently — plus the spinner above gives
  /// the tap itself an immediate, visible response regardless of how long
  /// the capture/share takes.
  Future<void> _onReportRound() async {
    if (_sharingReport) return;
    final prompt = _gameState.currentPrompt;
    if (prompt == null) return;

    setState(() => _sharingReport = true);
    try {
      final buildInfo = await BuildInfo.current();
      final respondsToDrops = _gameState.agencyStage == AgencyStage.trigger;
      final report = RoundReport(
        capturedAt: DateTime.now(),
        build: buildInfo,
        conceptTier: _gameState.conceptTier,
        agencyStage: _gameState.agencyStage,
        roundOrder: _gameState.roundOrder,
        roundNumber: _gameState.currentPromptIndex + 1,
        totalRounds: _gameState.totalPrompts,
        targetDirection: prompt.targetDirection,
        left: RoundReportSide(
          instrument: _gameState.leftInstrument,
          midi: prompt.firstMidi,
        ),
        right: RoundReportSide(
          instrument: _gameState.rightInstrument,
          midi: prompt.secondMidi,
        ),
        response: RoundReportResponse(
          applicable: respondsToDrops,
          side: respondsToDrops ? _gameState.lastDropSide : null,
          markedCorrect: !respondsToDrops
              ? null
              : switch (_gameState.dragFeedback) {
                  DragFeedback.correct => true,
                  DragFeedback.retry => false,
                  DragFeedback.none => null,
                },
        ),
      );

      final buttonBox =
          _reportButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final sharePositionOrigin = buttonBox != null && buttonBox.attached
          ? buttonBox.localToGlobal(Offset.zero) & buttonBox.size
          : null;

      await RoundReportService.shareReport(
        report: report,
        boundaryKey: _screenshotKey,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e, stackTrace) {
      debugPrint('Report this round failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't share this round's report.")),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingReport = false);
    }
  }

  /// The child's move-on/skip control — a parchment pill in the header's
  /// top-right corner, opposite the close X (Trello card "Move Skip back to
  /// the top right as an icon-plus-text pill"). This reverses an earlier
  /// decision (Trello card: "the move-on arrow is no longer adult-only"),
  /// which had moved this control to a bottom-right arrow specifically so
  /// skipping wasn't an adult-only, header-only affordance. Cooper reviewed
  /// a mockup and preferred the top-right pill instead — it's still sized
  /// generously (see [AppSpacing.largeTapTarget] below) so a child can
  /// still find and hit it even though it reads visually quieter than the
  /// old arrow did.
  ///
  /// Available from the very start of every round, at every stage, and
  /// never gated on game phase — a child who wants to move on should be
  /// able to, same as before (Trello card 91).
  Widget _buildSkipPill() {
    final enabled = _gameState.status != GameStatus.completed;
    return Tooltip(
      message: 'Skip',
      child: GestureDetector(
        onTap: enabled ? _gameState.moveOn : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.4,
          duration: AppAnimations.fast,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.largeTapTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
              border: Border.all(color: AppColors.cardEdge, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fast_forward_rounded,
                  color: AppColors.textSecondary,
                  size: 26,
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skip',
                      style: AppTypography.bodyLarge.copyWith(fontSize: 18),
                    ),
                    Text(
                      "I'm ready to move on",
                      style: AppTypography.label.copyWith(letterSpacing: 0),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The current round's spoken-line placeholder (Observe's live
  /// narration, or the constant Participate/Trigger prompt, or a brief
  /// retry line) — see [VoiceLine] for why this is text today. Lives at
  /// the top of the screen now, in [_buildHeader]'s center slot, per the
  /// mockup (Trello card "Separate the stumps from the background art") —
  /// it used to sit mid-screen, directly on top of Listen Again and the
  /// "Listen carefully..." status line. Reserves two lines' worth of
  /// height even when empty so the header doesn't jump as [text] toggles
  /// on and off between rounds.
  Widget _buildPromptArea() {
    final text = _gameState.captionText;
    return SizedBox(
      height:
          AppTypography.heading3.fontSize! * AppTypography.heading3.height! * 2,
      child: Center(
        child: AnimatedSwitcher(
          duration: AppAnimations.medium,
          child: text == null
              ? const SizedBox.shrink(key: ValueKey('caption-empty'))
              : Text(
                  text,
                  key: ValueKey('caption-$text'),
                  style: AppTypography.heading3,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
  /// from the background's own art, leaving instruments visibly floating
  /// above it and pulling Piper/Clef in over the stumps instead of
  /// outside them. Sizing and positioning here directly off the real
  /// screen makes the scene invariant to that shrink entirely.
  ///
  /// The stumps themselves ([_buildStump]) are painted here too, not in
  /// the background art (Trello card "Separate the stumps from the
  /// background art"): `MeadowWidescreen.png` is stump-free scenery, and
  /// each stump prop shares [groundY] — the exact same anchor coordinate
  /// used to place the instrument standing on it. Every past "instrument
  /// floating off its stump" bug (the FittedBox drift above, the original
  /// scene anchoring, the floating cellos) came from the stump living in
  /// painted artwork while the instrument was placed by a number measured
  /// off that art — a number that goes stale the moment the viewport
  /// changes. Sharing one coordinate instead of matching two independent
  /// measurements makes that whole bug class impossible by construction.
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
    // The shared ground line: where each instrument's feet and its
    // stump's flat top surface meet — see the class doc above. Unlike the
    // old `stumpLift` this replaces, this is no longer calibrated against
    // a painted stump in the background art (there isn't one any more);
    // it's just a comfortable resting line near the bottom of the scene.
    final groundY = screenHeight * 0.16;
    final leftAnchorX = screenWidth * 0.29;
    final rightAnchorX = screenWidth * 0.72;
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
    // A correct drop sticks the dragged character onto the instrument it
    // landed on instead of springing back to center (Trello — "celebrate a
    // correct drop"); see [_buildDragHandle]. [_dropAlignX] converts the
    // target instrument's screen-space X into the -1..1 fraction
    // [AnimatedAlign] wants.
    final celebrating = _gameState.dragFeedback == DragFeedback.correct;
    final dropAnchorX = _gameState.lastDropSide == 1
        ? rightAnchorX
        : leftAnchorX;
    final dropAlignX = ((dropAnchorX / screenWidth) * 2 - 1).clamp(-1.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildStump(
          assetPath: 'assets/images/backgrounds/props/StumpA.png',
          naturalWidth: 1512,
          naturalHeight: 794,
          centerX: leftAnchorX,
          charSize: charSize,
          groundY: groundY,
        ),
        _buildStump(
          assetPath: 'assets/images/backgrounds/props/StumpB.png',
          naturalWidth: 1506,
          naturalHeight: 781,
          centerX: rightAnchorX,
          charSize: charSize,
          groundY: groundY,
        ),
        _buildPiper(
          piperHeight,
          piperIsDragged,
          homeLift,
          groundY,
          celebrating: celebrating && piperIsDragged,
          dropAlignX: dropAlignX,
        ),
        _buildClef(
          clefHeight,
          clefIsDragged,
          homeLift,
          homeShift,
          groundY,
          celebrating: celebrating && clefIsDragged,
          dropAlignX: dropAlignX,
        ),
        Positioned(
          left: leftAnchorX - charSize / 2,
          bottom: groundY,
          child: AnimatedScale(
            scale: _hoveredDropSide == 0 ? 1.06 : 1.0,
            duration: AppAnimations.fast,
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
          left: rightAnchorX - charSize / 2,
          bottom: groundY,
          child: AnimatedScale(
            scale: _hoveredDropSide == 1 ? 1.06 : 1.0,
            duration: AppAnimations.fast,
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
        // Two big, non-overlapping halves of the whole play area, not two
        // small boxes hugging each instrument (Trello — "forgiving drop
        // targets"): a four-year-old's aim is imprecise, and with only two
        // possible answers, "which half did you drop in" already *is*
        // "which one did you mean," so there's no accuracy lost by being
        // this generous. Painted last (on top of the stumps/Piper/Clef/
        // instruments) so they aren't occluded by those images' full
        // rectangular bounds — DragTarget defaults to
        // HitTestBehavior.translucent, so sitting on top like this doesn't
        // block the instruments' own tap-to-explore underneath.
        if (isTrigger) ...[
          _buildDropZone(side: 0, left: 0, width: screenWidth / 2),
          _buildDropZone(
            side: 1,
            left: screenWidth / 2,
            width: screenWidth / 2,
          ),
        ],
      ],
    );
  }

  /// One half of the whole play area as a drop target — see [_buildScene]'s
  /// class doc for why generous, non-overlapping halves replace two small
  /// boxes hugging each instrument. Invisible (a plain [SizedBox.expand]):
  /// the instrument's own [AnimatedScale] hover cue, driven by
  /// [_hoveredDropSide], is the only visual feedback a drag is over this
  /// zone.
  Widget _buildDropZone({
    required int side,
    required double left,
    required double width,
  }) {
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: width,
      child: DragTarget<Object>(
        onWillAcceptWithDetails: (_) => _gameState.canDrop,
        onAcceptWithDetails: (_) => _gameState.dropOnSide(side),
        onMove: (_) {
          if (_hoveredDropSide != side) {
            setState(() => _hoveredDropSide = side);
          }
        },
        onLeave: (_) {
          if (_hoveredDropSide == side) {
            setState(() => _hoveredDropSide = null);
          }
        },
        builder: (context, candidateData, rejectedData) =>
            const SizedBox.expand(),
      ),
    );
  }

  /// One stump prop, centered under an instrument at [centerX] and
  /// aligned to it at [groundY] — see [_buildScene]'s class doc for why
  /// sharing that exact coordinate (rather than a separate measurement)
  /// is the point. Sized off [charSize] (the instrument's own bounding
  /// box) rather than the stump art's native pixel size, so it scales
  /// down with the instrument on small screens instead of independently
  /// drifting out of proportion with it.
  ///
  /// [_stumpSurfaceFraction] accounts for the art itself: StumpA/B ([naturalWidth]x[naturalHeight])
  /// are photographed/rendered at an angle, so the flat top surface an
  /// instrument stands on isn't the very top pixel of the image — it's
  /// roughly a third of the way down, with the trunk's bark and the grass
  /// around its base filling the rest below. [groundY] anchors that
  /// surface line, not the image's bounding box.
  Widget _buildStump({
    required String assetPath,
    required int naturalWidth,
    required int naturalHeight,
    required double centerX,
    required double charSize,
    required double groundY,
  }) {
    // A "low, wide disc" per the mockup (Trello card "Separate the stumps
    // from the background art": "the stumps are too big ... match the
    // mockup's proportions"), scaled to the instrument standing on it
    // rather than the source art's own resolution.
    final width = charSize * 0.95;
    final height = width * naturalHeight / naturalWidth;
    final belowSurface = height * (1 - _stumpSurfaceFraction);

    return Positioned(
      left: centerX - width / 2,
      bottom: groundY - belowSurface,
      child: Image.asset(assetPath, width: width, height: height),
    );
  }

  /// Fraction of the stump art's height, from the top, down to the front
  /// rim of its flat top surface — read directly off StumpA.png/StumpB.png
  /// (both are cropped/composed the same way). Below this line is bark and
  /// grass; above it is the disc an instrument stands on.
  static const double _stumpSurfaceFraction = 0.37;

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
    double dragLift, {
    required bool celebrating,
    required double dropAlignX,
  }) {
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
    return _buildDragHandle(
      image: clefImage,
      bobbing: bobbing,
      lift: dragLift,
      size: clefHeight,
      celebrating: celebrating,
      dropAlignX: dropAlignX,
    );
  }

  /// Piper: fixed far-left, unless she's this round's dragged answer
  /// ([isDragged] — Piper owns the low pole, Trello card 101) — see
  /// [_buildClef] for why the dragged character starts centered. Unlike
  /// Clef, Piper doesn't idle-bob while fixed; only picks up motion once
  /// she's the one being dragged.
  ///
  /// Sits flush with the screen's left edge, not pushed past it like
  /// Clef's `-homeShift` on the right — that negative offset cropped
  /// Piper in half against the left edge (Trello card "Separate the
  /// stumps from the background art"). Clef's art apparently has enough
  /// transparent margin on that side to absorb the same shift without
  /// visibly cropping; Piper's doesn't.
  Widget _buildPiper(
    double piperHeight,
    bool isDragged,
    double homeLift,
    double dragLift, {
    required bool celebrating,
    required double dropAlignX,
  }) {
    final piperImage = Image.asset(
      'assets/images/characters/Piper_Encouraging.png',
      height: piperHeight,
      fit: BoxFit.contain,
    );

    if (!isDragged) {
      return Positioned(
        left: 0,
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
      size: piperHeight,
      celebrating: celebrating,
      dropAlignX: dropAlignX,
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
  ///
  /// [celebrating] is the fix for "right and wrong currently look
  /// identical" (Trello): previously nothing here ever moved, so a correct
  /// drop and a wrong one looked exactly the same — the character just
  /// reappeared centered either way, because the Draggable's real child was
  /// never removed from its slot. On a correct drop this now slides the
  /// character sideways to sit on the instrument it landed on
  /// ([dropAlignX]) instead of snapping back to center, and adds a little
  /// pulse plus a burst from the shared [DriftingNotes] component (already
  /// used elsewhere for "this instrument is sounding," reused here rather
  /// than inventing a second celebration effect). There's no alternate
  /// "excited" sprite for either character in SongStone-UI-Kit yet (only
  /// concept art) — this deliberately ships with the existing art rather
  /// than faking one.
  Widget _buildDragHandle({
    required Widget image,
    required Widget bobbing,
    required double lift,
    required double size,
    required bool celebrating,
    required double dropAlignX,
  }) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: lift,
      child: AnimatedAlign(
        alignment: celebrating
            ? Alignment(dropAlignX, 1.0)
            : Alignment.bottomCenter,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        child: celebrating
            ? Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  image
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.1, 1.1),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeInOut,
                      ),
                  Positioned(
                    top: -size * 0.15,
                    child: DriftingNotes(size: size, active: true),
                  ),
                ],
              )
            : Draggable<Object>(
                data: 'narrator',
                feedback: Opacity(opacity: 0.85, child: image),
                childWhenDragging: Opacity(opacity: 0.3, child: image),
                child: bobbing,
              ),
      ),
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

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
import '../models/high_low_instrument.dart';
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
/// sparkle, Trigger centers the target's narrator (Piper or Clef,
/// whichever owns that round's pole — Trello card 101) as a fixed drop
/// target and asks the child to drag the correct instrument to her.
/// (Reversed 2026-09 from an earlier design where the *character* was
/// dragged onto a fixed instrument — see [HighLowGameState]'s class doc
/// for why.) See [HighLowGameState]'s class doc for the full stage
/// breakdown — this screen only renders what that state exposes, it
/// doesn't duplicate the stage logic.
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

  /// Whether a dragged instrument is currently hovering over the drop
  /// zone, for the centered character's little "you're about to drop
  /// here" scale-up — purely a transient UI cue, not game state, so it
  /// lives here rather than on [HighLowGameState]. A single bool, not a
  /// per-side flag, since 2026-09's reversal made the drop zone one
  /// screen-spanning target (the character) rather than two per-instrument
  /// halves — see [_buildDropZone].
  bool _dragHovering = false;

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
  /// footer, and Trigger's centered target character (Clef or Piper,
  /// [_buildTargetCharacter]) stands tall enough — up to 72% of the screen
  /// height — to reach exactly that vertical middle too. Centering here
  /// sat Listen Again right behind the centered character's head; hugging
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
  ///
  /// [Expanded] alone isn't enough to keep the caption clear of the close
  /// button: it constrains the caption's *available* width, but nothing
  /// stopped the caption's own content from rendering flush against that
  /// boundary with zero margin (Trello card hIKjobsB, found driving the
  /// simulator — a long caption's centered text, wide enough to need
  /// nearly the full Expanded width, measured with its own left edge
  /// exactly touching the close button's right edge: no true overlap, but
  /// no breathing room either, which reads as "running underneath" it).
  /// Trigger's captions are the ones long enough to trigger this — e.g.
  /// "Drag the higher-sounding instrument to Clef." — Observe/
  /// Participate's shorter lines never got close enough to the edges to
  /// show it. The explicit [SizedBox] gaps below are the fix: they
  /// guarantee a minimum margin on both sides regardless of how wide the
  /// caption's own text needs to be.
  ///
  /// (A first attempt moved the caption to its own row below the icons
  /// instead, on the theory that *any* horizontal competition was the
  /// risk. That was reverted: it grew the header tall enough, on a tight
  /// landscape viewport, to push the body's Listen Again button down into
  /// the exact screen-center point the background's drop zone gets
  /// hit-tested at, regressing the drag interaction. Fixing the real,
  /// narrow cause — no margin, not "shares a row" — avoids that.)
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
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _buildPromptArea()),
        const SizedBox(width: AppSpacing.sm),
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
    // Piper and Clef share one home height (Trello card "Scale the waiting
    // character up at the screen edge for depth" — Cooper: "i like that
    // clef become bigger on the right hand side the same way Piper is
    // bigger over there. it creates some depth of field."). Clef used to
    // be noticeably smaller here (44% vs Piper's 72%), which read as an
    // inconsistency rather than a deliberate choice once Piper's edge
    // size was established — the fix is parity, not a new number for
    // Clef alone.
    final piperHomeHeight = screenHeight * 0.72;
    final clefHomeHeight = piperHomeHeight;
    // Trigger-only: whichever character is centered as the fixed drop
    // target uses this size instead of her own home size (Trello card
    // hIKjobsB — driving the simulator found Piper's home height
    // rendered enormous when centered and covered the Listen Again
    // button/status line beneath it).
    //
    // NOTE — this makes the centered target character *smaller* than
    // whichever character is standing at the edge. That's deliberate
    // perspective (the edge is foreground/nearer the viewer, the
    // centered drop target is background/further away), not a bug and
    // not an oversight left over from tuning each character separately.
    // Do not "fix" this by matching it to the home heights above —
    // that's exactly the naive instinct that would flatten the depth
    // this card asked for back out again.
    final targetCharacterHeight = screenHeight * 0.42;
    // The shared ground line: where each instrument's feet and its
    // stump's flat top surface meet — see the class doc above. Unlike the
    // old `stumpLift` this replaces, this is no longer calibrated against
    // a painted stump in the background art (there isn't one any more);
    // it's just a comfortable resting line near the bottom of the scene.
    final groundY = screenHeight * 0.16;
    final leftAnchorX = screenWidth * 0.29;
    final rightAnchorX = screenWidth * 0.72;
    // How far above the screen's bottom edge Piper and Clef's home spots
    // sit — raised from their old flush-corner spots (Trello card
    // S1v6sbrK: Piper's home was circled up-and-left of where she stood,
    // Clef's up-and-right of hers; the drag round's centered character
    // was sitting below the stump line entirely).
    final homeLift = screenHeight * 0.08;
    final isTrigger = _gameState.agencyStage == AgencyStage.trigger;
    final prompt = _gameState.currentPrompt;
    // Whichever character owns this round's target pole (Piper is low,
    // Clef is high — Trello card 101) stays centered, at every stage once
    // a round is underway: in Trigger she's the fixed drop target the
    // child feeds instruments to; in Observe/Participate she has nothing
    // to receive, but stands centered anyway as a second visual cue for
    // what the child is listening for, alongside the caption/narration
    // (Trello card 1SpHq2la — "add piper or clef appropriately to the
    // middle on A0 and A1"). Same character, same centered position and
    // size at every stage — only whether she's an interactive drop target
    // ([isTrigger], gating [_buildDropZone] below) changes.
    final piperIsTarget = prompt != null && _gameState.targetCharacterIsPiper;
    final clefIsTarget = prompt != null && !_gameState.targetCharacterIsPiper;
    // A correct drop slides the dragged instrument onto the centered
    // character instead of springing back to its stump (Trello —
    // "celebrate a correct drop"; see [_buildInstrumentSlot]).
    final celebrating = _gameState.dragFeedback == DragFeedback.correct;

    // Trello card NcVPjPZ5 — Cooper: "the pianos should not get the
    // stumps, they look weird sitting on top of a stump." A piano's own
    // art already reads as freestanding furniture, not something that
    // rests on a tree stump the way a guitar or a violin does.
    final leftIsPiano = _gameState.leftInstrument == HighLowInstrument.piano;
    final rightIsPiano = _gameState.rightInstrument == HighLowInstrument.piano;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (!leftIsPiano)
          _buildStump(
            assetPath: 'assets/images/backgrounds/props/StumpA.png',
            naturalWidth: 1512,
            naturalHeight: 794,
            centerX: leftAnchorX,
            charSize: charSize,
            groundY: groundY,
          ),
        if (!rightIsPiano)
          _buildStump(
            assetPath: 'assets/images/backgrounds/props/StumpB.png',
            naturalWidth: 1506,
            naturalHeight: 781,
            centerX: rightAnchorX,
            charSize: charSize,
            groundY: groundY,
          ),
        _buildPiper(
          piperHomeHeight,
          targetCharacterHeight,
          piperIsTarget,
          homeLift,
          groundY,
          celebrating: celebrating && piperIsTarget,
          hovering: _dragHovering && piperIsTarget,
        ),
        _buildClef(
          clefHomeHeight,
          targetCharacterHeight,
          clefIsTarget,
          homeLift,
          groundY,
          celebrating: celebrating && clefIsTarget,
          hovering: _dragHovering && clefIsTarget,
        ),
        _buildInstrumentSlot(
          side: 0,
          assetPath: _gameState.leftInstrument.leftAssetPath,
          instrumentName: _gameState.leftInstrument.name,
          isPiano: leftIsPiano,
          anchorX: leftAnchorX,
          screenWidth: screenWidth,
          charSize: charSize,
          groundY: groundY,
          isTrigger: isTrigger,
          celebratingThis: celebrating && _gameState.lastDropSide == 0,
          glowing: _gameState.playingIndex == 0,
          feedback: _feedbackFor(0),
          showSparkle: _gameState.showHint && prompt?.targetSide == 0,
        ),
        _buildInstrumentSlot(
          side: 1,
          assetPath: _gameState.rightInstrument.rightAssetPath,
          instrumentName: _gameState.rightInstrument.name,
          isPiano: rightIsPiano,
          anchorX: rightAnchorX,
          screenWidth: screenWidth,
          charSize: charSize,
          groundY: groundY,
          isTrigger: isTrigger,
          celebratingThis: celebrating && _gameState.lastDropSide == 1,
          glowing: _gameState.playingIndex == 1,
          feedback: _feedbackFor(1),
          showSparkle: _gameState.showHint && prompt?.targetSide == 1,
        ),
        // One drop zone spanning the whole scene, not two per-instrument
        // halves (Trello — "forgiving drop targets," now applied to the
        // character-as-target instead of the instruments): there's only
        // one place to drop any more — onto the centered character — so
        // the most generous possible hitbox is the entire play area; which
        // instrument was dragged (not where it landed) is what
        // [HighLowGameState.dropInstrument] judges. Painted last (on top
        // of the stumps/Piper/Clef/instruments) so it isn't occluded by
        // those images' full rectangular bounds — DragTarget defaults to
        // HitTestBehavior.translucent, so sitting on top like this doesn't
        // block the instruments' own tap-to-explore (or drag-start)
        // underneath.
        if (isTrigger) _buildDropZone(),
      ],
    );
  }

  /// The whole play area as a single drop target — see [_buildScene]'s
  /// comment for why one generous, screen-spanning zone replaces the old
  /// two per-instrument halves. Invisible (a plain [SizedBox.expand]): the
  /// centered character's own scale-up hover cue, driven by
  /// [_dragHovering], is the only visual feedback a drag is over this
  /// zone. Data type is `int` (the dragged instrument's [side]) to match
  /// the `Draggable<int>` each instrument wraps itself in — see
  /// [_buildInstrumentSlot].
  Widget _buildDropZone() {
    return Positioned.fill(
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) => _gameState.canDrop,
        onAcceptWithDetails: (details) =>
            _gameState.dropInstrument(details.data),
        onMove: (_) {
          if (!_dragHovering) setState(() => _dragHovering = true);
        },
        onLeave: (_) {
          if (_dragHovering) setState(() => _dragHovering = false);
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

  /// Clef: fixed far-right at [homeHeight], unless she's this round's fixed
  /// drop target ([isTarget] — Clef owns the high pole, Trello card 101),
  /// in which case she's centered at [targetHeight] instead — a distinct,
  /// smaller size (Trello card hIKjobsB), not [homeHeight] reused, since
  /// centering a character sized for standing off to the side is exactly
  /// what let Piper (see [_buildPiper]) grow large enough to cover the
  /// header/body controls once she took the same fixed target role.
  ///
  /// Stationary either way (Trello card NcVPjPZ5, reversing an earlier
  /// design where Clef bobbed continuously) — the idle motion moved to the
  /// instruments instead, see [_buildInstrumentSlot]. A character that
  /// never moves reads more clearly as "the one waiting to receive," and
  /// leaves motion as a signal that means one thing (an instrument you can
  /// interact with) rather than two.
  ///
  /// Home position mirrors Piper's exactly (flush with the screen's edge,
  /// `fit: BoxFit.contain`) — see [_buildPiper]'s doc comment for why the
  /// old `-homeShift` push past the edge is gone. It used to be there to
  /// compensate for Clef's home size being noticeably smaller than
  /// Piper's; now that they share [homeHeight] (Trello card "Scale the
  /// waiting character up at the screen edge for depth"), that
  /// compensation is not only unneeded but wrong — pushing a
  /// Piper-sized Clef past the edge would clip her the same way it once
  /// clipped Piper.
  Widget _buildClef(
    double homeHeight,
    double targetHeight,
    bool isTarget,
    double homeLift,
    double centerLift, {
    required bool celebrating,
    required bool hovering,
  }) {
    if (!isTarget) {
      final clefImage = Image.asset(
        'assets/images/characters/Clef.png',
        height: homeHeight,
        fit: BoxFit.contain,
      );
      return Positioned(right: 0, bottom: homeLift, child: clefImage);
    }

    final targetImage = Image.asset(
      'assets/images/characters/Clef.png',
      height: targetHeight,
    );
    return _buildTargetCharacter(
      characterImage: targetImage,
      lift: centerLift,
      size: targetHeight,
      celebrating: celebrating,
      hovering: hovering,
    );
  }

  /// Piper: fixed far-left at [homeHeight], unless she's this round's fixed
  /// drop target ([isTarget] — Piper owns the low pole, Trello card 101),
  /// in which case she's centered at [targetHeight] instead — see
  /// [_buildClef] for why that's a distinct, smaller size rather than
  /// [homeHeight] reused. Stationary either way, same as Clef — see
  /// [_buildClef]'s doc comment for why the idle motion moved to the
  /// instruments instead (Trello card NcVPjPZ5).
  ///
  /// Sits flush with the screen's left edge (Trello card "Separate the
  /// stumps from the background art" — an earlier `-homeShift` push past
  /// the edge cropped Piper in half). Clef's home position now mirrors
  /// this exactly — see [_buildClef]'s doc comment.
  Widget _buildPiper(
    double homeHeight,
    double targetHeight,
    bool isTarget,
    double homeLift,
    double centerLift, {
    required bool celebrating,
    required bool hovering,
  }) {
    if (!isTarget) {
      final piperImage = Image.asset(
        'assets/images/characters/Piper_Encouraging.png',
        height: homeHeight,
        fit: BoxFit.contain,
      );
      return Positioned(
        left: 0,
        bottom: homeLift,
        child: piperImage.animate().fade(duration: AppAnimations.medium),
      );
    }

    final piperImage = Image.asset(
      'assets/images/characters/Piper_Encouraging.png',
      height: targetHeight,
      fit: BoxFit.contain,
    );
    return _buildTargetCharacter(
      characterImage: piperImage,
      lift: centerLift,
      size: targetHeight,
      celebrating: celebrating,
      hovering: hovering,
    );
  }

  /// A character standing centered as this round's fixed drop target —
  /// shared by [_buildClef] and [_buildPiper] (Trello card 101: either can
  /// own this round's target pole). [lift] raises it off the very bottom
  /// edge to the same stump-top line the instruments sit on (Trello card
  /// S1v6sbrK).
  ///
  /// Never moves — both because she's the fixed anchor the *instrument*
  /// travels to since 2026-09's A2 reversal (Trello, "reverse the A2 drag
  /// interaction"; see [_buildInstrumentSlot]'s own celebration), and
  /// because Trello card NcVPjPZ5 made every character stationary,
  /// centered or at the edges, moving idle motion onto the instruments
  /// instead. All she needs is a little liveliness of her own:
  /// [hovering] scales her up slightly while a dragged instrument is over
  /// the drop zone (Trello — "you're about to drop here"), and
  /// [celebrating] adds the same pulse-plus-[DriftingNotes] burst used
  /// elsewhere for "something good just happened" (already used for "this
  /// instrument is sounding" and for the pre-reversal dragged character —
  /// reused again rather than inventing a third celebration effect).
  Widget _buildTargetCharacter({
    required Widget characterImage,
    required double lift,
    required double size,
    required bool celebrating,
    required bool hovering,
  }) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: lift,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedScale(
              scale: (celebrating || hovering) ? 1.08 : 1.0,
              duration: AppAnimations.fast,
              child: characterImage,
            ),
            if (celebrating)
              Positioned(
                top: -size * 0.15,
                child: DriftingNotes(size: size, active: true),
              ),
          ],
        ),
      ),
    );
  }

  /// One instrument, sitting on its stump at [anchorX] — always tappable
  /// (exploration, every stage), and during Trigger also draggable onto
  /// the centered character (Trello, "reverse the A2 drag interaction":
  /// the instrument used to just sit here as a fixed answer the dragged
  /// character landed on; now it's the thing the child picks up). Bobs
  /// gently while resting (side-to-side for [isPiano], up-and-down for
  /// everything else) — see the `else` branch below, Trello card
  /// NcVPjPZ5.
  ///
  /// [celebratingThis] mirrors the pre-reversal "celebrate a correct drop"
  /// fix, just on the instrument instead of the character: on this
  /// side's correct drop, it slides from its stump to the screen's exact
  /// horizontal center (matching where [_buildTargetCharacter] already
  /// sits, itself always centered regardless of its own width — see that
  /// method) instead of snapping back, and picks up the same pulse and
  /// [DriftingNotes] burst. [AnimatedPositioned] with a plain `left:`
  /// offset (not the `Alignment`-based approach [_buildTargetCharacter]
  /// uses) keeps the *resting* position pixel-identical to the pre-
  /// reversal fixed anchor — this instrument sits here in every stage, not
  /// just Trigger, so its everyday position can't shift by however much an
  /// alignment-fraction approximation would introduce.
  Widget _buildInstrumentSlot({
    required int side,
    required String assetPath,
    required String instrumentName,
    required bool isPiano,
    required double anchorX,
    required double screenWidth,
    required double charSize,
    required double groundY,
    required bool isTrigger,
    required bool celebratingThis,
    required bool glowing,
    required _CharacterFeedback? feedback,
    required bool showSparkle,
  }) {
    final targetLeft = celebratingThis
        ? screenWidth / 2 - charSize / 2
        : anchorX - charSize / 2;

    Widget button = _InstrumentButton(
      key: ValueKey('$side-$instrumentName'),
      assetPath: assetPath,
      size: charSize,
      glowing: glowing,
      feedback: feedback,
      showSparkle: showSparkle,
      onTap: () => _onInstrumentTap(side),
    );

    // Only draggable while this round is still answerable — once a side
    // has celebrated a correct drop the round is already wrapping up, same
    // as the pre-reversal character-Draggable disappearing in that branch.
    if (isTrigger &&
        !celebratingThis &&
        _gameState.dragFeedback != DragFeedback.correct) {
      button = Draggable<int>(
        data: side,
        feedback: Opacity(
          opacity: 0.85,
          child: Image.asset(
            assetPath,
            width: charSize,
            height: charSize,
            fit: BoxFit.contain,
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: button),
        child: button,
      );
    }

    if (celebratingThis) {
      button = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          button
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOut,
              ),
          Positioned(
            top: -charSize * 0.15,
            child: DriftingNotes(size: charSize, active: true),
          ),
        ],
      );
    } else {
      // Idle motion while resting on its stump — reversed from the old
      // design where Piper/Clef bobbed instead (Trello card NcVPjPZ5).
      // The instrument is now the thing the child can pick up and
      // interact with, so it's the one that reads as "alive"; the
      // characters are stationary throughout (see [_buildTargetCharacter]
      // and [_buildClef]/[_buildPiper]'s doc comments). Pianos don't get
      // a stump at all (see [_buildScene] — Cooper: "they look weird
      // sitting on top of a stump"), and a vertical bob would look like
      // they're floating in place above nothing without one to bounce
      // against, so they get a slight side-to-side drift instead — just
      // enough that they don't read as a frozen background prop.
      button = isPiano
          ? button
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveX(
                  begin: -4,
                  end: 4,
                  duration: const Duration(milliseconds: 1600),
                  curve: Curves.easeInOut,
                )
          : button
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(
                  begin: 0,
                  end: -6,
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeInOut,
                );
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      left: targetLeft,
      bottom: groundY,
      child: button,
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

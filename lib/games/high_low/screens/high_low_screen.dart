import 'package:confetti/confetti.dart';
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
import '../../../models/concept_tier.dart';
import '../../../models/musical_skill.dart';
import '../../../models/game_status.dart';
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
import '../ordering/ordering_screen.dart';
import '../widgets/high_low_header.dart';
import '../widgets/mouth_frames.dart';
import '../widgets/retry_settle.dart';
import '../widgets/speaking_pulse.dart';

/// Main game screen for High/Low ear training.
///
/// Piper (the fox) and Clef (the animated treble clef) sit either side of
/// an illustrated forest clearing (assets/images/backgrounds/Forest.png),
/// flanking a randomized pair of instrument characters. The screen's
/// behavior is entirely driven by [HighLowGameState.agencyStage] (Trello
/// card 91): Observe and Participate resolve via repeated correct taps
/// (Trello card RqdPFKLf), Trigger centers the target's narrator (Piper or Clef,
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

  /// True after the dev gate picks a [ConceptTier.noteCount] 3 tier
  /// (T5-T8) — those tiers are real in [ConceptTier]/[PromptGenerator]
  /// (Trello card "Rebuild the tier ladder as eight tiers (2x2x2)"), but
  /// no screen renders a three-note round yet: there's no design for
  /// where a third instrument sits without competing with the centered
  /// target character's own carefully-tuned position (Trello cards
  /// NcVPjPZ5/1SpHq2la). [_gameState.startGame] is deliberately never
  /// called in this case — see [_startFromDevGate] — so this shows a
  /// plain placeholder instead of a broken or cramped two-slot layout
  /// trying to represent a third note it has nowhere to put.
  bool _threeNoteTierNotBuilt = false;

  /// Set when the dev gate picks A4: ordering is its own screen with its
  /// own state (see [OrderingScreen]), so this one hands off entirely
  /// rather than running [_gameState] for it.
  ConceptTier? _orderingTier;

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

  /// Fires Participate's five-cumulative-correct-taps confetti burst
  /// (Cooper: "building to a confetti burst") — a real `ConfettiController`
  /// has to live here, not on [HighLowGameState], since it needs a
  /// `TickerProvider`. See [_onGameStateChanged] for how it's triggered
  /// from [HighLowGameState.confettiTrigger]'s one-shot bump-counter.
  late final ConfettiController _confettiController;

  /// The last [HighLowGameState.confettiTrigger] value this screen has
  /// already acted on — see [_onGameStateChanged].
  int _lastConfettiTrigger = 0;

  @override
  void initState() {
    super.initState();
    _gameState = HighLowGameState();
    _gameState.addListener(_onGameStateChanged);
    _confettiController = ConfettiController(
      duration: AppAnimations.confettiBurst,
    );

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
    _confettiController.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    if (_gameState.confettiTrigger != _lastConfettiTrigger) {
      _lastConfettiTrigger = _gameState.confettiTrigger;
      _confettiController.play();
    }
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
    if (devSettings.agencyStage == AgencyStage.order) {
      setState(() {
        _showDevGate = false;
        _orderingTier = devSettings.conceptTier;
      });
      return;
    }
    _gameState
      ..agencyStage = devSettings.agencyStage
      ..conceptTier = devSettings.conceptTier
      ..roundOrder = devSettings.roundOrder;
    final threeNote = devSettings.conceptTier.noteCount == 3;
    setState(() {
      _showDevGate = false;
      _threeNoteTierNotBuilt = threeNote;
    });
    if (!threeNote) _gameState.startGame();
  }

  /// Tapping an instrument is always exploration — see
  /// [HighLowGameState.tapInstrument].
  void _onInstrumentTap(int side) => _gameState.tapInstrument(side);

  /// One per side, on each instrument's slot, so a drop can measure how far
  /// the instrument actually travelled from where it rests.
  final List<GlobalKey> _instrumentSlotKeys = [GlobalKey(), GlobalKey()];

  /// A drop only answers the round if the instrument travelled at least
  /// this far ([_minAnswerDragFraction] of [charSize]) from its stump. The
  /// drop zone is the whole screen, so without this floor any drag past
  /// the ~18px touch slop — a small child's finger sliding during a tap —
  /// counted as a full answer and sent the instrument to the character
  /// (Trello card L00pxs7q). The trip to the centered character is about
  /// 0.9 x [charSize], so half of that is well clear of a slide and well
  /// short of a deliberate drag.
  static const double _minAnswerDragFraction = 0.5;

  /// A drag that ends short of the answer threshold is the tap it was
  /// meant to be: the drag gesture won the arena, so the instrument's own
  /// tap never fired, and this plays it instead.
  void _onInstrumentDropped(
    DragTargetDetails<int> details,
    List<double> charSizesBySide,
  ) {
    final side = details.data;
    final box = _instrumentSlotKeys[side].currentContext?.findRenderObject();
    var releasedFrom = Offset.zero;
    if (box is RenderBox && box.hasSize) {
      releasedFrom = details.offset - box.localToGlobal(Offset.zero);
      if (releasedFrom.distance <
          charSizesBySide[side] * _minAnswerDragFraction) {
        _onInstrumentTap(side);
        return;
      }
    }
    // Set before the drop so the rebuild it triggers already knows where a
    // wrong drop's return journey starts — see [RetrySettle].
    _lastDropFrom = releasedFrom;
    _dropSerial++;
    _gameState.dropInstrument(side);
  }

  /// Where the most recent counted drop released its instrument, relative
  /// to the stump it rests on — the start of a wrong drop's return
  /// journey ([RetrySettle]).
  Offset _lastDropFrom = Offset.zero;

  /// Bumped on every counted drop and used as [RetrySettle]'s key, so a
  /// second wrong drop during the same retry window replays the return
  /// from its own release point instead of reusing the first.
  int _dropSerial = 0;

  /// Shown instead of the real game when the dev gate picks a three-note
  /// tier (T5-T8) — see [_threeNoteTierNotBuilt]. Plain and honest rather
  /// than a broken attempt at the real scene: says what's missing, and
  /// lets a developer get back to the tier picker without leaving the
  /// game entirely.
  Widget _buildThreeNoteNotBuiltPlaceholder() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Three-note tiers aren\'t built yet',
                  style: AppTypography.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${_gameState.conceptTier.label} asks "which one is the '
                  'highest" across three notes. The tier and its prompt '
                  'generator are ready — the on-screen layout for a third '
                  'instrument isn\'t designed yet.',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => setState(() => _showDevGate = true),
                  child: const Text('Back to tier picker'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showDevGate) {
      // Debug-only pre-game gate (Trello card 92) — never reachable
      // unless devToolsEnabled, so a public App Store build never shows
      // this.
      return Scaffold(body: DevSetupOverlay(onStart: _startFromDevGate));
    }

    if (_orderingTier != null) {
      return OrderingScreen(tier: _orderingTier!);
    }

    if (_threeNoteTierNotBuilt) {
      return _buildThreeNoteNotBuiltPlaceholder();
    }

    return RepaintBoundary(
      key: _screenshotKey,
      child: Stack(
        children: [
          GameScreenLayout(
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
            header: HighLowHeader(
              onClose: () {
                final extra =
                    GoRouterState.of(context).extra as Map<String, dynamic>?;
                if (extra?['fromPath'] == true) {
                  context.read<ProgressState>().requestPathReturn();
                }
                context.go(AppRoutes.home);
              },
              // Secondary guidance overrides the primary caption once it
              // appears — Participate only (Trello card xpAkja5b):
              // Observe/Trigger's own secondary nudge died with the timed
              // move-on control; see
              // [HighLowGameState.secondaryCaptionText]'s doc comment.
              captionText:
                  _gameState.secondaryCaptionText ?? _gameState.captionText,
              reportButtonKey: devToolsEnabled ? _reportButtonKey : null,
              onReportTap: _gameState.currentPrompt == null
                  ? null
                  : _onReportRound,
              sharingReport: _sharingReport,
              skipEnabled: _gameState.status != GameStatus.completed,
              onSkip: _gameState.escape,
            ),
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
          // Participate's five-cumulative-correct-taps celebration
          // (Trello card RqdPFKLf) — a real screen-level overlay, not
          // part of `_buildScene`'s background layer, so it bursts on top
          // of the header/footer too, not just the scene. IgnorePointer:
          // gameplay continues immediately underneath (the next round
          // auto-starts in ~1.2s), so the burst must never intercept a
          // touch meant for it.
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.gold,
                  AppColors.correct,
                  AppColors.higherButton,
                  AppColors.lowerButton,
                ],
                numberOfParticles: 20,
                gravity: 0.3,
              ),
            ),
          ),
        ],
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
    // Per-instrument multiplier on the shared [charSize] (Trello, Cooper on
    // device: "the bells art should be like 50% as large") — see
    // [HighLowInstrument.displaySizeScale]'s doc for why this lives on the
    // instrument, not the asset. Applied as the *base* size each slot's own
    // depth/celebration scaling then multiplies on top of, same as before.
    final leftCharSize = charSize * _gameState.leftInstrument.displaySizeScale;
    final rightCharSize =
        charSize * _gameState.rightInstrument.displaySizeScale;
    // How far above the screen's bottom edge Piper and Clef's home spots
    // sit — raised from their old flush-corner spots (Trello card
    // S1v6sbrK: Piper's home was circled up-and-left of where she stood,
    // Clef's up-and-right of hers; the drag round's centered character
    // was sitting below the stump line entirely).
    final homeLift = screenHeight * 0.08;
    final isTrigger = _gameState.agencyStage == AgencyStage.trigger;
    final prompt = _gameState.currentPrompt;
    // Whichever character owns this round's target pole (Piper is low,
    // Clef is high — Trello card 101) stays centered at Participate and
    // Trigger: in Trigger she's the fixed drop target the child feeds
    // instruments to; in Participate she has nothing to receive, but
    // stands centered anyway as a visual cue for which pole the child is
    // listening for, alongside the caption/narration.
    //
    // Not at Observe, though — this revises Trello card 1SpHq2la ("add
    // piper or clef appropriately to the middle on A0 and A1"), which
    // Cooper walked back after seeing it running: "my reasoning for having
    // the character in the middle for A0 is flawed because we're not
    // asking them to listen for a high or low note at A0." Observe has no
    // pole to cue — the characters just narrate — so a centered character
    // there has nothing to do, and the middle is needed for the earned
    // arrow instead (Trello card xpAkja5b), which only ever appears at
    // Observe. The two therefore never compete for the center: Observe
    // shows the arrow and no character, Participate/Trigger show the
    // character and no arrow.
    final centerTargetCharacter =
        prompt != null && _gameState.agencyStage != AgencyStage.observe;
    final piperIsTarget =
        centerTargetCharacter && _gameState.targetCharacterIsPiper;
    final clefIsTarget =
        centerTargetCharacter && !_gameState.targetCharacterIsPiper;
    // A correct drop slides the dragged instrument onto the centered
    // character instead of springing back to its stump (Trello —
    // "celebrate a correct drop"; see [_buildInstrumentSlot]).
    final celebrating = _gameState.dragFeedback == DragFeedback.correct;

    // "The talker moves" (Trello card PIm7xE6n) — whichever of Piper/Clef
    // is currently speaking, home or centered, regardless of which one
    // happens to be this round's target (Observe's per-note narration is
    // about which *note* just sounded, not which pole this round is
    // asking about). And the transient "found it" character sparkle
    // (Trello card RqdPFKLf) — the two are mutually exclusive per
    // character by construction (see [HighLowGameState.speakingIsPiper]'s
    // doc comment), but each is independently false/false/true/true here
    // since only one of Piper/Clef can be speaking or sparkling at once.
    final piperSpeaking = _gameState.speakingIsPiper == true;
    final clefSpeaking = _gameState.speakingIsPiper == false;
    // Absence cue (Cooper: pair the speaking pulse with dimming whoever
    // *isn't* talking) — cheap, adds no new motion to a screen about to
    // have plenty, and keeps the speaker unambiguous even on a glance.
    // Neither is dimmed while nobody's speaking.
    final anyoneSpeaking = _gameState.speakingIsPiper != null;
    final piperDimmed = anyoneSpeaking && !piperSpeaking;
    final clefDimmed = anyoneSpeaking && !clefSpeaking;
    final speakingLineName = _gameState.speakingLine?.name;
    final speakingGeneration = _gameState.speakingGeneration;
    final piperSparkling = _gameState.characterSparkleIsPiper == true;
    final clefSparkling = _gameState.characterSparkleIsPiper == false;
    // How many cumulative correct taps Participate has banked (0-5) —
    // scales the sparkle's visual intensity so each tap reads as *more*
    // than the last (Cooper: "a flat sparkle is a reward; an escalating
    // one is a promise"). Only meaningful while sparkling; unused
    // otherwise.
    final sparkleLevel = _gameState.correctTapProgress;

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
          speaking: piperSpeaking,
          dimmed: piperDimmed,
          speakingLineName: speakingLineName,
          speakingGeneration: speakingGeneration,
          sparkling: piperSparkling,
          sparkleLevel: sparkleLevel,
        ),
        _buildClef(
          clefHomeHeight,
          targetCharacterHeight,
          clefIsTarget,
          homeLift,
          groundY,
          celebrating: celebrating && clefIsTarget,
          hovering: _dragHovering && clefIsTarget,
          speaking: clefSpeaking,
          dimmed: clefDimmed,
          speakingLineName: speakingLineName,
          speakingGeneration: speakingGeneration,
          sparkling: clefSparkling,
          sparkleLevel: sparkleLevel,
        ),
        _buildInstrumentSlot(
          side: 0,
          assetPath: _gameState.leftInstrument.leftAssetPath,
          instrumentName: _gameState.leftInstrument.name,
          anchorX: leftAnchorX,
          screenWidth: screenWidth,
          charSize: leftCharSize,
          groundY: groundY,
          isTrigger: isTrigger,
          celebratingThis: celebrating && _gameState.lastDropSide == 0,
          glowing: _gameState.playingIndex == 0,
          feedback: _feedbackFor(0),
        ),
        _buildInstrumentSlot(
          side: 1,
          assetPath: _gameState.rightInstrument.rightAssetPath,
          instrumentName: _gameState.rightInstrument.name,
          anchorX: rightAnchorX,
          screenWidth: screenWidth,
          charSize: rightCharSize,
          groundY: groundY,
          isTrigger: isTrigger,
          celebratingThis: celebrating && _gameState.lastDropSide == 1,
          glowing: _gameState.playingIndex == 1,
          feedback: _feedbackFor(1),
        ),
        // One drop zone spanning the whole scene, not two per-instrument
        // halves (Trello — "forgiving drop targets," now applied to the
        // character-as-target instead of the instruments): there's only
        // one place to drop any more — onto the centered character — so
        // the most generous possible hitbox is the entire play area; which
        // instrument was dragged (not where it landed) is what
        // [HighLowGameState.dropInstrument] judges. Painted before the
        // earned arrow below (on top of the stumps/Piper/Clef/
        // instruments, but under the arrow) so it isn't occluded by those
        // images' full rectangular bounds — DragTarget defaults to
        // HitTestBehavior.translucent, so sitting on top like this doesn't
        // block the instruments' own tap-to-explore (or drag-start)
        // underneath.
        if (isTrigger) _buildDropZone([leftCharSize, rightCharSize]),
        // The child's earned arrow (Trello card xpAkja5b, "Two controls:
        // the adult's persistent skip, and the child's earned arrow") —
        // Observe only, below the centered target character, visible
        // only once [HighLowGameState.showArrow] says the child has
        // earned it (both instruments tapped this round — never a
        // timer). Not built until then — conditionally mounted, not just
        // hidden, so it can't be hit-tested a moment early. Painted last
        // (on top of the drop zone above, though Observe never renders
        // that zone anyway since it's Trigger-only).
        if (_gameState.showArrow)
          Positioned(
            left: 0,
            right: 0,
            // groundY itself, not a fraction of it: the footer's own
            // parchment pill (ProgressDots) lives in a *separate* overlay
            // painted on top of this whole background layer (see
            // GameScreenLayout — header/body/footer stack above
            // `background` regardless of z-order chosen within it), so no
            // amount of paint-order juggling in here keeps this control
            // clear of it. groundY comfortably clears the footer's own
            // occupied height on the tightest viewport this screen
            // supports; a smaller fraction measured, on a widget test, as
            // sitting directly underneath the footer's pill and silently
            // eating the tap (found originally tuning the old move-on
            // control, which sat in this same spot).
            bottom: groundY,
            child: Center(child: _buildEarnedArrow()),
          ),
      ],
    );
  }

  /// The child's earned arrow — big and bright, the opposite visual
  /// language from the quiet, adult-facing controls elsewhere in this
  /// app (compare [AdultDoor]'s deliberately unshowy styling): this one
  /// is for the child, and it's meant to be found. Plays a one-shot
  /// entrance pop (elastic scale-in) when it first mounts, then holds
  /// still — no idle animation once settled, matching every other
  /// on-screen element now that idle motion has been retired entirely
  /// (Cooper, driving the simulator: "the instruments and the characters
  /// don't have any idle bobbing"). A second, ongoing pulse would also
  /// muddy the one thing motion means elsewhere on this screen: that a
  /// character is speaking.
  Widget _buildEarnedArrow() {
    return Tooltip(
      message: 'Tap when ready',
      child: GestureDetector(
        onTap: _gameState.tapArrow,
        child:
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                gradient: AppColors.ctaGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ctaShadow,
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 40,
              ),
            ).animate().scale(
              begin: const Offset(0.4, 0.4),
              end: const Offset(1, 1),
              duration: AppAnimations.medium,
              curve: Curves.elasticOut,
            ),
      ),
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
  Widget _buildDropZone(List<double> charSizesBySide) {
    return Positioned.fill(
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) => _gameState.canDrop,
        onAcceptWithDetails: (details) =>
            _onInstrumentDropped(details, charSizesBySide),
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

  /// Opacity for whichever character *isn't* speaking, while the other one
  /// is (Cooper: pair the speaking pulse with dimming the non-speaker) —
  /// quiet, cheap, and adds no new motion; makes the speaker unambiguous
  /// even on a glance. Neither character is dimmed while nobody's
  /// speaking — see [_buildScene]'s `anyoneSpeaking` computation.
  static const double _dimmedOpacity = 0.55;

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
    required bool speaking,
    required bool dimmed,
    required String? speakingLineName,
    required int speakingGeneration,
    required bool sparkling,
    required int sparkleLevel,
  }) {
    if (!isTarget) {
      return Positioned(
        right: 0,
        bottom: homeLift,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedOpacity(
              opacity: dimmed ? _dimmedOpacity : 1.0,
              duration: AppAnimations.fast,
              child: SpeakingPulse.builder(
                speaking: speaking,
                line: speakingLineName,
                generation: speakingGeneration,
                builder: _clefSprite(homeHeight),
              ),
            ),
            if (sparkling) _buildCharacterSparkle(homeHeight, sparkleLevel),
          ],
        ),
      );
    }

    return _buildTargetCharacter(
      characterBuilder: _clefSprite(targetHeight),
      lift: centerLift,
      size: targetHeight,
      celebrating: celebrating,
      hovering: hovering,
      speaking: speaking,
      dimmed: dimmed,
      speakingLineName: speakingLineName,
      speakingGeneration: speakingGeneration,
      sparkling: sparkling,
      sparkleLevel: sparkleLevel,
    );
  }

  /// Clef drawn from her registered mouth frames at [height], the mouth
  /// following the same envelope tick as the speaking pulse. She has no
  /// separate idle sprite: the closed frame *is* her resting pose, so
  /// starting to speak changes only the mouth, never swaps the art.
  MouthSpriteBuilder _clefSprite(double height) =>
      (context, amplitude, mouth) => MouthSprite(
        frames: clefMouthFrameAssets,
        frame: mouth,
        height: height,
      );

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
    required bool speaking,
    required bool dimmed,
    required String? speakingLineName,
    required int speakingGeneration,
    required bool sparkling,
    required int sparkleLevel,
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedOpacity(
              opacity: dimmed ? _dimmedOpacity : 1.0,
              duration: AppAnimations.fast,
              child: SpeakingPulse(
                speaking: speaking,
                line: speakingLineName,
                generation: speakingGeneration,
                child: piperImage.animate().fade(
                  duration: AppAnimations.medium,
                ),
              ),
            ),
            if (sparkling) _buildCharacterSparkle(homeHeight, sparkleLevel),
          ],
        ),
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
      speaking: speaking,
      dimmed: dimmed,
      speakingLineName: speakingLineName,
      speakingGeneration: speakingGeneration,
      sparkling: sparkling,
      sparkleLevel: sparkleLevel,
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
    Widget? characterImage,
    MouthSpriteBuilder? characterBuilder,
    required double lift,
    required double size,
    required bool celebrating,
    required bool hovering,
    required bool speaking,
    required bool dimmed,
    required String? speakingLineName,
    required int speakingGeneration,
    required bool sparkling,
    required int sparkleLevel,
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
              child: AnimatedOpacity(
                opacity: dimmed ? _dimmedOpacity : 1.0,
                duration: AppAnimations.fast,
                child: characterBuilder != null
                    ? SpeakingPulse.builder(
                        speaking: speaking,
                        line: speakingLineName,
                        generation: speakingGeneration,
                        builder: characterBuilder,
                      )
                    : SpeakingPulse(
                        speaking: speaking,
                        line: speakingLineName,
                        generation: speakingGeneration,
                        child: characterImage!,
                      ),
              ),
            ),
            if (celebrating)
              Positioned(
                top: -size * 0.15,
                child: DriftingNotes(size: size, active: true),
              ),
            if (sparkling) _buildCharacterSparkle(size, sparkleLevel),
          ],
        ),
      ),
    );
  }

  /// Fixed positions, each `(top, right)` as a fraction of the
  /// character's own size measured from its top-right corner (matching
  /// the single fixed sparkle this replaced: `top: -0.05, right: -0.05`),
  /// for up to four escalating sparkles — see [_buildCharacterSparkle].
  /// Four, not five: the fifth cumulative correct tap fires the confetti
  /// burst instead of a fifth sparkle (Cooper: "building to a confetti
  /// burst").
  static const List<(double top, double right)> _sparkleOffsets = [
    (-0.05, -0.05),
    (0.10, -0.20),
    (-0.05, -0.35),
    (0.22, -0.05),
  ];

  /// The "found it" character sparkle (Trello card RqdPFKLf) — same
  /// visual language as the instrument's own ✨ overlay
  /// ([_InstrumentButton]), anchored to a character instead. Callers
  /// guarantee this is never shown for the same character
  /// [SpeakingPulse] is animating at the same instant — see
  /// [HighLowGameState.speakingIsPiper]'s doc comment for why the two
  /// signals must not collide.
  ///
  /// [level] (Participate's cumulative correct-tap count, 1-4 here — see
  /// [_sparkleOffsets]) scales how many sparkles show at once, so each
  /// correct tap reads as visibly *more* than the last instead of a flat,
  /// repeated reward (Cooper: "a flat sparkle is a reward; an escalating
  /// one is a promise — that's what makes a child tap again without
  /// needing to be told").
  Widget _buildCharacterSparkle(double size, int level) {
    final count = level.clamp(1, _sparkleOffsets.length);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < count; i++)
          Positioned(
            top: size * _sparkleOffsets[i].$1,
            right: size * _sparkleOffsets[i].$2,
            child: IgnorePointer(
              child: Text('✨', style: TextStyle(fontSize: size * 0.2))
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
    );
  }

  /// One instrument, sitting on its stump at [anchorX] — always tappable
  /// (exploration, every stage), and during Trigger also draggable onto
  /// the centered character (Trello, "reverse the A2 drag interaction":
  /// the instrument used to just sit here as a fixed answer the dragged
  /// character landed on; now it's the thing the child picks up).
  /// Perfectly still while resting — idle motion was retired here
  /// entirely (Cooper, driving the simulator: "the instruments and the
  /// characters don't have any idle bobbing"), so nothing on screen
  /// idles any more; motion is reserved for [SpeakingPulse], which
  /// only ever means one thing.
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
    required double anchorX,
    required double screenWidth,
    required double charSize,
    required double groundY,
    required bool isTrigger,
    required bool celebratingThis,
    required bool glowing,
    required _CharacterFeedback? feedback,
  }) {
    // Traveling to the character (rather than pulsing in place) is a
    // Trigger-only distinction (Trello card xpAkja5b: "at A2+ travels to
    // the character") — Participate's five-cumulative-correct-taps
    // resolution has no drag concept to visually echo, so it only pulses
    // below.
    final targetLeft = (celebratingThis && isTrigger)
        ? screenWidth / 2 - charSize / 2
        : anchorX - charSize / 2;

    Widget button = _InstrumentButton(
      key: ValueKey('$side-$instrumentName'),
      assetPath: assetPath,
      size: charSize,
      glowing: glowing,
      feedback: feedback,
      retryFrom: _lastDropFrom,
      dropSerial: _dropSerial,
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
    }

    return AnimatedPositioned(
      key: _instrumentSlotKeys[side],
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
/// always tappable (tapping is pure exploration — see [HighLowGameState]).
/// Perfectly still otherwise — see [_buildInstrumentSlot]'s doc comment
/// for why idle motion was retired here entirely.
class _InstrumentButton extends StatelessWidget {
  final String assetPath;
  final double size;
  final bool glowing;
  final _CharacterFeedback? feedback;

  /// Where a wrong drop released this instrument, relative to its stump,
  /// and which drop that was — the start point and replay key for
  /// [RetrySettle]. Only read while [feedback] is retry.
  final Offset retryFrom;
  final int dropSerial;
  final VoidCallback onTap;

  const _InstrumentButton({
    super.key,
    required this.assetPath,
    required this.size,
    required this.glowing,
    required this.feedback,
    required this.retryFrom,
    required this.dropSerial,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Only a correct drop holds the grow-and-bob for its whole feedback
    // window. A retry's feedback is the brief [RetrySettle] alone — holding
    // the grow/bob for the retry line's full length made the "not that
    // one" gesture run as long as the clip.
    final isActive = glowing || feedback == _CharacterFeedback.correct;

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
                  ? RetrySettle(
                      key: ValueKey(dropSerial),
                      from: retryFrom,
                      child: Image.asset(assetPath, fit: BoxFit.contain),
                    )
                  : Image.asset(assetPath, fit: BoxFit.contain),
            ),
            Positioned(
              top: -size * 0.15,
              child: DriftingNotes(size: size, active: glowing),
            ),
          ],
        ),
      ),
    );
  }
}

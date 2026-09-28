import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/build_info.dart';
import '../../../app/config.dart';
import '../../../app/router.dart';
import '../../../app/state/dev_settings_state.dart';
import '../../../app/state/profile_state.dart';
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
import '../../../ui/theme/theme.dart';
import '../models/high_low_instrument.dart';
import '../models/round_report.dart';
import '../services/round_report_service.dart';
import '../state/high_low_game_state.dart';
import '../ordering/ordering_screen.dart';
import '../ordering/ordering_slot.dart';
import '../models/scene_layout.dart';
import '../widgets/character_art.dart';
import '../widgets/high_low_header.dart';
import '../widgets/retry_settle.dart';
import '../widgets/speaking_pulse.dart';

/// Main game screen for High/Low ear training.
///
/// A randomized pair of instrument characters stands on stumps at the left;
/// Clef (the animated treble clef) lives on the tree at the right, and
/// Piper (the fox) stands beside it on the ground, at foreground scale (see
/// [SceneLayout]'s class doc — one scene at every agency level, 2026-09-26,
/// extended 2026-09-27 to a slot on the tree as the drop target). The
/// screen's behavior is entirely driven by [HighLowGameState.agencyStage]
/// (Trello card 91): Observe and Explore resolve via repeated correct
/// taps (Trello card RqdPFKLf), Drag asks the child to drag the correct
/// instrument up to a slot on the tree, near whichever of Piper/Clef owns
/// that round's pole (Trello card 101). (Reversed 2026-09 from an earlier
/// design where the *character* was dragged onto a fixed instrument, then
/// revised again 2026-09-27 from dragging onto the character herself to
/// dragging onto a slot beside her — see [HighLowGameState]'s class doc for
/// why.) See [HighLowGameState]'s class doc for the full stage breakdown —
/// this screen only renders what that state exposes, it doesn't duplicate
/// the stage logic.
///
/// A debug-only setup gate (Trello card 92) lets a developer pick the
/// stage/tier/round-order before the round starts; it only ever mounts
/// when `devToolsEnabled` (see `app/config.dart` — true for TestFlight and
/// local debug runs, false for a public App Store build) is true, so a
/// public build always goes straight to the production defaults.
class HighLowScreen extends StatefulWidget {
  /// Supplied by tests so a round's outcome is known; otherwise the screen
  /// makes and disposes its own.
  final HighLowGameState? gameState;

  /// Whether the screen disposes an injected [gameState] along with itself
  /// (a screen always disposes one it made). For tests that also want to
  /// read the state, so its pending timers die with the tree.
  final bool ownsGameState;

  const HighLowScreen({super.key, this.gameState, this.ownsGameState = false});

  @override
  State<HighLowScreen> createState() => _HighLowScreenState();
}

class _HighLowScreenState extends State<HighLowScreen> {
  late HighLowGameState _gameState;
  late final bool _ownsGameState;

  /// Whether the dev gate can show at all — an internal build ([devToolsEnabled])
  /// AND the active profile being the adult's (Trello card 170: an internal
  /// build a child is using must not show dev tools either). Computed once
  /// in [initState], same lifecycle as [_ownsGameState].
  late final bool _canUseDevTools;
  late bool _showDevGate;

  /// [ProfileState.canUseDevTools], falling back to the pre-profile
  /// [devToolsEnabled] alone when no [ProfileState] is provided above this
  /// screen — most widget tests construct [HighLowScreen] directly, without
  /// the app's full provider stack, and don't care about profile gating at
  /// all; forcing every one of them to also wire up a [ProfileState] would
  /// be a lot of unrelated churn for no real safety gain, since the actual
  /// app always provides one at its root (see `EarTrainerApp`). Tests that
  /// DO care about the gating provide a [ProfileState] explicitly and get
  /// the real value.
  bool _resolveCanUseDevTools() {
    try {
      return context.read<ProfileState>().canUseDevTools;
    } on ProviderNotFoundException {
      return devToolsEnabled;
    }
  }

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

  /// Whether a dragged instrument is currently hovering over the tree slot
  /// — drives the slot's own [SlotState.hovering] look. Purely a transient
  /// UI cue, not game state, so it lives here rather than on
  /// [HighLowGameState]. A single bool, not a per-side flag: there is only
  /// ever one slot live at once (2026-09-27 — see [_buildTreeSlot]).
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
    _canUseDevTools = _resolveCanUseDevTools();
    _showDevGate = _canUseDevTools;
    _ownsGameState = widget.gameState == null || widget.ownsGameState;
    _gameState = widget.gameState ?? HighLowGameState();
    _gameState.addListener(_onGameStateChanged);
    _confettiController = ConfettiController(
      duration: AppAnimations.confettiBurst,
    );

    if (!_canUseDevTools) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _gameState.startGame();
      });
    }
  }

  @override
  void dispose() {
    _gameState.removeListener(_onGameStateChanged);
    if (_ownsGameState) _gameState.dispose();
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
    // Ordering is a separate skill (Trello card 168), selected by its own
    // toggle rather than a fourth AgencyStage value the way `.order` used
    // to work — see [DevSettingsState.orderingSelected].
    if (devSettings.orderingSelected) {
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

  /// Called only once the tree slot's own [DragTarget] has *accepted* a
  /// release — i.e. the drag genuinely reached the slot (Flutter only
  /// calls this when the release point is within the slot's positioned
  /// bounds). A short accidental slide (a finger sliding during a tap,
  /// Trello card L00pxs7q) can no longer reach a slot positioned up near
  /// the tree, so unlike the old screen-spanning drop zone this no longer
  /// needs its own distance heuristic to tell a real drag from a tap —
  /// geometry does that instead. A drop that misses the slot entirely
  /// isn't reported here at all: [Draggable]'s own "return to child" is
  /// silent and correct, since the instrument never visually left its
  /// stump during the drag (see [_buildInstrumentSlot]'s `childWhenDragging`).
  void _onInstrumentDropped(DragTargetDetails<int> details) {
    final side = details.data;
    final box = _instrumentSlotKeys[side].currentContext?.findRenderObject();
    // Where relative to the STUMP this landed — RetrySettle's start point
    // for a wrong-instrument-on-the-right-slot retry (see
    // [_buildInstrumentSlot]). Not used to gate whether this counts.
    _lastDropFrom = box is RenderBox && box.hasSize
        ? details.offset - box.localToGlobal(Offset.zero)
        : Offset.zero;
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
              reportButtonKey: _canUseDevTools ? _reportButtonKey : null,
              onReportTap: _gameState.currentPrompt == null
                  ? null
                  : _onReportRound,
              sharingReport: _sharingReport,
              // Skip top-right, Listen Again centred under the caption; no
              // progress indicator (it is always five rounds, so it told
              // the child nothing — see docs/product/HIGH_LOW_SCREEN_LAYOUT.md
              // for what would bring it back).
              skipEnabled: _gameState.status != GameStatus.completed,
              onSkip: _gameState.escape,
              below: _buildListenAgainButton(),
            ),
            // The middle holds only the caption and Listen Again (both in the
            // header); the scene is the background.
            body: const SizedBox.shrink(),
            // The body is empty, so GameScreenLayout's scroll-fallback isn't
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
      final respondsToDrops = _gameState.agencyStage == AgencyStage.drag;
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

  /// Listen Again, centred under the caption: the round button with its label
  /// beside it (not below — a label underneath reached down into the tips of
  /// tall instruments).
  Widget _buildListenAgainButton() {
    final canReplay =
        _gameState.status != GameStatus.completed &&
        _gameState.status != GameStatus.showingFeedback;
    return GestureDetector(
      onTap: canReplay ? _gameState.replay : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: canReplay ? 1 : 0.5,
        duration: AppAnimations.fast,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
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
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Listen Again', style: AppTypography.label),
          ],
        ),
      ),
    );
  }

  /// The scene: two instruments on stumps at the left, and the tree at the
  /// right with Clef on its top platform and Piper on its bottom one — the
  /// same composition as the three-instrument and ordering screens (see
  /// [SceneLayout]). Nothing on the tree is a receptacle here: at A0/A1 there
  /// is nothing to place, and even at A2 the drop target is the character,
  /// so drawing empty slots would only invite a drag that does nothing.
  ///
  /// Composed straight into [GameScreenLayout]'s full-bleed `background`
  /// layer (Trello card 56), sized and positioned directly off
  /// `MediaQuery.size` rather than off whatever room the header leaves in the
  /// body's flex layout: sizing here directly off the real screen makes the
  /// scene invariant to any shrink the header or body needs to do.
  ///
  /// The stumps themselves ([_buildStump]) are painted here too, not in the
  /// background art (Trello card "Separate the stumps from the background
  /// art"): each stump prop shares the layout's ground line with the
  /// instrument standing on it. Every past "instrument floating off its
  /// stump" bug came from the stump living in painted artwork while the
  /// instrument was placed by a number measured off that art — a number that
  /// goes stale the moment the viewport changes. Sharing one coordinate makes
  /// that whole bug class impossible by construction.
  Widget _buildScene(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final layout = SceneLayout(
      size,
      insets: MediaQuery.paddingOf(context),
      noteCount: 2,
    );
    final groundY = layout.groundY;
    final charSize = layout.instrumentSize;
    // Per-instrument multiplier on the shared [charSize] (Trello, Cooper on
    // device: "the bells art should be like 50% as large") — see
    // [HighLowInstrument.displaySizeScale]'s doc for why this lives on the
    // instrument, not the asset.
    final leftCharSize = charSize * _gameState.leftInstrument.displaySizeScale;
    final rightCharSize =
        charSize * _gameState.rightInstrument.displaySizeScale;
    // Bells hang from their ring, so they float slightly proud of the stump
    // instead of sinking into it (Cooper, on device).
    final leftFeetLift = leftCharSize * _gameState.leftInstrument.floatFraction;
    final rightFeetLift =
        rightCharSize * _gameState.rightInstrument.floatFraction;
    final isTrigger = _gameState.agencyStage == AgencyStage.drag;
    // Whichever character owns this round's pole (Piper is low, Clef is
    // high — Trello card 101) is the one asking at Participate and Trigger:
    // in Trigger, the tree slot near her is where the correct instrument
    // goes (2026-09-27 — the drop target is a slot on the tree, not a
    // character, see [SceneLayout]'s class doc); in Participate there is no
    // drag at all, but she's still the cue for which pole the child is
    // listening for. Not at Observe: there the characters just narrate and
    // nobody is asked anything. Both stay in their places throughout —
    // asking changes pose only, never size or position.
    final prompt = _gameState.currentPrompt;
    final hasAsker =
        prompt != null && _gameState.agencyStage != AgencyStage.observe;
    final piperIsAsking = hasAsker && _gameState.targetCharacterIsPiper;
    final clefIsAsking = hasAsker && !_gameState.targetCharacterIsPiper;
    // A correct drop slides the dragged instrument onto the slot instead of
    // springing back to its stump (Trello — "celebrate a correct drop"; see
    // [_buildInstrumentSlot]).
    final celebrating = _gameState.dragFeedback == DragFeedback.correct;

    // "The talker moves" (Trello card PIm7xE6n) — whichever of Piper/Clef
    // is currently speaking, regardless of which one happens to be this
    // round's target (Observe's per-note narration is about which *note*
    // just sounded, not which pole this round is asking about). And the
    // transient "found it" character sparkle (Trello card RqdPFKLf) — the
    // two are mutually exclusive per character by construction (see
    // [HighLowGameState.speakingIsPiper]'s doc comment).
    final piperSpeaking = _gameState.speakingIsPiper == true;
    final clefSpeaking = _gameState.speakingIsPiper == false;
    // The character who isn't speaking is NOT dimmed — see the class doc on
    // [_buildCharacter] for why that was tried and removed.
    final speakingLineName = _gameState.speakingLine?.name;
    final speakingGeneration = _gameState.speakingGeneration;
    final piperSparkling = _gameState.characterSparkleIsPiper == true;
    final clefSparkling = _gameState.characterSparkleIsPiper == false;
    // How many cumulative correct taps Participate has banked (0-5) —
    // scales the sparkle's visual intensity so each tap reads as *more*
    // than the last (Cooper: "a flat sparkle is a reward; an escalating
    // one is a promise"). Only meaningful while sparkling.
    final sparkleLevel = _gameState.correctTapProgress;

    // Trello card NcVPjPZ5 — Cooper: "the pianos should not get the
    // stumps, they look weird sitting on top of a stump." A piano's own
    // art already reads as freestanding furniture.
    final leftIsPiano = _gameState.leftInstrument == HighLowInstrument.piano;
    final rightIsPiano = _gameState.rightInstrument == HighLowInstrument.piano;

    // Which platform this round's slot sits on, and where a correct drop
    // lands — the top-adjacent platform for a high round, the bottom-most
    // for a low one (see [SceneLayout.slotPlatformFor]). Computed
    // unconditionally (cheap, pure) even outside Trigger; only Trigger
    // actually renders the slot or uses this as a landing spot.
    final slotPlatform = layout.slotPlatformFor(
      isPiperTarget: _gameState.targetCharacterIsPiper,
    );
    final landing = layout.platform(slotPlatform);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (!leftIsPiano)
          _buildStump(
            assetPath: 'assets/images/backgrounds/props/StumpA.png',
            naturalWidth: 1512,
            naturalHeight: 794,
            centerX: layout.stumpAnchorX(0),
            charSize: charSize,
            groundY: groundY,
          ),
        if (!rightIsPiano)
          _buildStump(
            assetPath: 'assets/images/backgrounds/props/StumpB.png',
            naturalWidth: 1506,
            naturalHeight: 781,
            centerX: layout.stumpAnchorX(1),
            charSize: charSize,
            groundY: groundY,
          ),
        Positioned.fromRect(
          rect: layout.treeRect,
          child: Image.asset(
            'assets/images/backgrounds/props/OrderingTree.png',
            fit: BoxFit.fill,
          ),
        ),
        // Instruments before characters: a correct drop slides the
        // instrument onto the slot, and painting characters on top would
        // hide the celebration pose. At rest nothing overlaps (see
        // [SceneLayout]), so the order only shows during that landing — the
        // asking character stands in front of the instrument it was just
        // handed.
        _buildInstrumentSlot(
          side: 0,
          assetPath: _gameState.leftInstrument.leftAssetPath,
          instrumentName: _gameState.leftInstrument.name,
          anchorX: layout.stumpAnchorX(0),
          landing: landing,
          layout: layout,
          screenHeight: size.height,
          charSize: leftCharSize,
          groundY: groundY + leftFeetLift,
          isTrigger: isTrigger,
          celebratingThis: celebrating && _gameState.lastDropSide == 0,
          glowing: _gameState.playingIndex == 0,
          feedback: _feedbackFor(0),
        ),
        _buildInstrumentSlot(
          side: 1,
          assetPath: _gameState.rightInstrument.rightAssetPath,
          instrumentName: _gameState.rightInstrument.name,
          anchorX: layout.stumpAnchorX(1),
          landing: landing,
          layout: layout,
          screenHeight: size.height,
          charSize: rightCharSize,
          groundY: groundY + rightFeetLift,
          isTrigger: isTrigger,
          celebratingThis: celebrating && _gameState.lastDropSide == 1,
          glowing: _gameState.playingIndex == 1,
          feedback: _feedbackFor(1),
        ),
        // The tree slot — the actual drop target — painted before both
        // characters so a correct, landed instrument's celebration is never
        // hidden behind it (same reasoning as the instruments above), and
        // only while a round is answerable (Trigger): an empty slot at
        // A0/A1, where nothing is draggable, is a false affordance (see
        // [SceneLayout]'s class doc).
        if (isTrigger) _buildTreeSlot(layout, slotPlatform),
        _buildPiper(
          layout: layout,
          pose: _poseFor(isAsking: piperIsAsking, celebrating: celebrating),
          speaking: piperSpeaking,
          speakingLineName: speakingLineName,
          speakingGeneration: speakingGeneration,
          sparkling: piperSparkling,
          sparkleLevel: sparkleLevel,
        ),
        _buildClef(
          layout: layout,
          pose: _poseFor(isAsking: clefIsAsking, celebrating: celebrating),
          speaking: clefSpeaking,
          speakingLineName: speakingLineName,
          speakingGeneration: speakingGeneration,
          sparkling: clefSparkling,
          sparkleLevel: sparkleLevel,
        ),
        // The child's earned arrow (Trello card xpAkja5b) — Observe only,
        // in the free column between the instruments and the tree, visible
        // only once [HighLowGameState.showArrow] says the child has earned
        // it (both instruments tapped this round — never a timer). Not built
        // until then — conditionally mounted, not just hidden, so it can't be
        // hit-tested a moment early. Painted last.
        if (_gameState.showArrow)
          Positioned(
            left: layout.arrowCentre.dx - _arrowSize / 2,
            top: layout.arrowCentre.dy - _arrowSize / 2,
            child: _buildEarnedArrow(),
          ),
      ],
    );
  }

  /// Diameter of the child's earned arrow.
  static const double _arrowSize = 72;

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
              width: _arrowSize,
              height: _arrowSize,
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

  /// The tree slot — the actual drop target (2026-09-27, superseding the
  /// "drop onto the character" mechanic; see [SceneLayout]'s class doc).
  /// One slot only, on the platform [platformIndex] gives for this round's
  /// pole ([SceneLayout.slotPlatformFor]) — never two, which would quietly
  /// become a two-item ordering task instead of a single choice.
  ///
  /// A generous hitbox, wider than the platform's own face (matching the
  /// A4 ordering screen's slots — a four-year-old's aim doesn't have to be
  /// exact), but no longer the *entire screen*: a release outside it is a
  /// genuine miss, not a counted attempt (see [_onInstrumentDropped]'s doc
  /// comment for why that needs no extra spring-back animation of its own).
  ///
  /// The slot itself hides once this round has been answered correctly —
  /// the landed, ticked instrument (see [_buildInstrumentSlot]) shows in
  /// its place, and painting both would double up the same information.
  Widget _buildTreeSlot(SceneLayout layout, int platformIndex) {
    final c = layout.platform(platformIndex);
    final w = layout.slotSize.width * 1.35;
    final h = layout.placedSize;
    final celebratingHere = _gameState.dragFeedback == DragFeedback.correct;
    return Positioned(
      left: c.dx - w / 2,
      top: c.dy - h * 0.8,
      width: w,
      height: h,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) => _gameState.canDrop,
        onAcceptWithDetails: (details) {
          setState(() => _dragHovering = false);
          _onInstrumentDropped(details);
        },
        onMove: (_) {
          if (!_dragHovering) setState(() => _dragHovering = true);
        },
        onLeave: (_) {
          if (_dragHovering) setState(() => _dragHovering = false);
        },
        builder: (context, candidateData, rejectedData) => celebratingHere
            ? const SizedBox.shrink()
            : Align(
                alignment: const Alignment(0, 0.6),
                child: OrderingSlot(
                  state: _dragHovering ? SlotState.hovering : SlotState.empty,
                  size: layout.slotSize,
                ),
              ),
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

  /// Which pose the character shows. Only the character whose pole this
  /// round asks about ([isAsking]) changes pose — the other one just
  /// speaks. A correct drop celebrates; a wrong drop, and the idle nudge
  /// (Participate's secondary caption), show her thinking. Celebration and
  /// thinking are discrete moments, so each is a single image; only the
  /// speaking pose has mouth frames.
  ///
  /// **The celebration is the social payoff, not just a correctness mark**
  /// (2026-09-27, Cooper: the voice line asks a favour — "bring the high
  /// one up here by me" — so the character being pleased afterwards is what
  /// makes it read as one; the tree slot durably marks *correct*, freeing
  /// the celebration to carry the warmth instead). It must fire reliably on
  /// every correct placement — see the "fires every time" test.
  CharacterPose _poseFor({required bool isAsking, required bool celebrating}) {
    if (!isAsking) return CharacterPose.speaking;
    if (celebrating) return CharacterPose.celebrating;
    if (_gameState.dragFeedback == DragFeedback.retry ||
        _gameState.secondaryCaptionText != null) {
      return CharacterPose.thinking;
    }
    return CharacterPose.speaking;
  }

  /// Piper or Clef — the shared inner content (pulse, pose, celebration
  /// burst, sparkle) common to both, with positioning left to the two thin
  /// callers below ([_buildClef], [_buildPiper]) since they anchor
  /// completely differently (Clef: centred on her perch; Piper: snug to the
  /// screen's right edge, at a much larger scale — see [SceneLayout]'s
  /// class doc).
  ///
  /// **The character who isn't speaking is never made transparent.** It was
  /// dimmed to 55% for a while as insurance while the scale pulse was the only
  /// speaking cue. Removed (Cooper: "i don't like that"): reduced opacity
  /// already means *unavailable* (a greyed control), which is wrong for a
  /// character who is present and simply not the one talking — it makes them
  /// look like they are leaving; and the mouth animation now carries the cue
  /// the dimming was covering. If de-emphasis is ever wanted, alpha is the
  /// wrong channel — a small drop in saturation or contrast keeps a character
  /// solid. Don't build that until someone asks. Until Piper's real mouth
  /// frames land her cue is the pulse alone and reads weaker than Clef's;
  /// the answer to that is her frames, not the dimming.
  Widget _characterCore({
    required CharacterArt art,
    required CharacterPose pose,
    required bool speaking,
    required String? speakingLineName,
    required int speakingGeneration,
    required bool sparkling,
    required int sparkleLevel,
    required double height,
  }) {
    final sprite = SpeakingPulse.builder(
      speaking: speaking,
      line: speakingLineName,
      generation: speakingGeneration,
      builder: (context, amplitude, mouth) =>
          CharacterSprite(art: art, pose: pose, mouth: mouth, height: height),
    );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        AnimatedScale(
          scale: pose == CharacterPose.celebrating ? 1.08 : 1.0,
          duration: AppAnimations.fast,
          alignment: Alignment.bottomCenter,
          child: sprite,
        ),
        if (pose == CharacterPose.celebrating)
          Positioned(
            top: -height * 0.15,
            child: DriftingNotes(size: height, active: true),
          ),
        if (sparkling) _buildCharacterSparkle(height, sparkleLevel),
      ],
    );
  }

  /// Clef, standing on his tree platform — centred on the perch, feet on
  /// the platform, same as before the tree-slot mechanic.
  Widget _buildClef({
    required SceneLayout layout,
    required CharacterPose pose,
    required bool speaking,
    required String? speakingLineName,
    required int speakingGeneration,
    required bool sparkling,
    required int sparkleLevel,
  }) {
    final height = layout.characterHeight;
    final feet = layout.clefPerch;
    final boxWidth = height * 2;
    return Positioned(
      left: feet.dx - boxWidth / 2,
      width: boxWidth,
      bottom: layout.screen.height - feet.dy,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _characterCore(
          art: CharacterArt.clef,
          pose: pose,
          speaking: speaking,
          speakingLineName: speakingLineName,
          speakingGeneration: speakingGeneration,
          sparkling: sparkling,
          sparkleLevel: sparkleLevel,
          height: height,
        ),
      ),
    );
  }

  /// Piper, standing beside the tree on the ground — foreground scale,
  /// anchored to the screen's right edge rather than centred on anything
  /// (she is no longer on a platform). Her feet may fall below the visible
  /// frame; that is by design, not a bug — see [SceneLayout.piperHeight]'s
  /// doc comment.
  Widget _buildPiper({
    required SceneLayout layout,
    required CharacterPose pose,
    required bool speaking,
    required String? speakingLineName,
    required int speakingGeneration,
    required bool sparkling,
    required int sparkleLevel,
  }) {
    final height = layout.piperHeight;
    return Positioned(
      right: layout.piperRightInset,
      bottom: layout.screen.height - layout.piperFeetY,
      child: _characterCore(
        art: CharacterArt.piper,
        pose: pose,
        speaking: speaking,
        speakingLineName: speakingLineName,
        speakingGeneration: speakingGeneration,
        sparkling: sparkling,
        sparkleLevel: sparkleLevel,
        height: height,
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
    required Offset landing,
    required SceneLayout layout,
    required double screenHeight,
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
    final travelling = celebratingThis && isTrigger;
    final targetLeft = travelling
        ? landing.dx - charSize / 2
        : anchorX - charSize / 2;
    final targetBottom = travelling ? screenHeight - landing.dy : groundY;

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
          // The durable "this was right" mark (2026-09-27: the slot is now
          // the drop target, so it carries the same tick the A4 ordering
          // screen puts on a correctly placed instrument) — nothing marks
          // a wrong one, in any colour or form. Only once it has actually
          // landed on the slot, not during Participate's in-place pulse
          // (which has no slot to tick).
          if (travelling)
            Positioned(
              right: -charSize * 0.06,
              top: charSize * 0.02,
              child: PlacementTick(
                key: ValueKey('tick-$side'),
                size: (charSize * 0.4).clamp(20.0, 34.0),
              ),
            ),
        ],
      );
    }

    return AnimatedPositioned(
      key: _instrumentSlotKeys[side],
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      left: targetLeft,
      bottom: targetBottom,
      // On the target's perch it shrinks to the size an instrument has on the
      // tree (as on the ordering screen), about its feet.
      child: AnimatedScale(
        scale: travelling ? layout.placedSize / charSize : 1.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        alignment: Alignment.bottomCenter,
        child: button,
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

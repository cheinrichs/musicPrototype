import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/router.dart';
import '../../../app/state/progress_state.dart';
import '../../../app/state/skill_state.dart';
import '../../../models/concept_tier.dart';
import '../../../models/game_status.dart';
import '../../../models/musical_skill.dart';
import '../../../ui/components/drifting_notes.dart';
import '../../../ui/components/game_screen_layout.dart';
import '../../../ui/components/progress_dots.dart';
import '../../../ui/theme/theme.dart';
import '../widgets/high_low_header.dart';
import '../widgets/mouth_frames.dart';
import '../widgets/retry_settle.dart';
import 'ordering_game_state.dart';
import 'ordering_layout.dart';
import 'ordering_slot.dart';

/// High/Low's A4 ordering screen (Trello card 11, Panel 3): drag each
/// instrument from its stump onto a platform of the tree, highest at the
/// top under Clef.
///
/// - An instrument **sounds as it lands**.
/// - **Nothing is checked until every platform in play is filled.** No
///   confirm button.
/// - Right placements get a **green tick that stays**. Wrong ones **wiggle
///   and travel back to their stumps** — the same [RetrySettle] a wrong drag
///   uses at A2, deliberately not a second wobble. **Nothing at all marks a
///   wrong one**: no cross, no red, no colour change ("describe the answer,
///   not the attempt").
/// - **The layout never reflows.** An instrument that leaves its stump leaves
///   a greyed ghost there, so children can re-find things by position.
class OrderingScreen extends StatefulWidget {
  /// The persistent hint for the adult (the reference app keeps one on
  /// screen the whole time — it is not triggered by a mistake).
  /// How visible the greyed ghost is on a stump whose instrument is away —
  /// enough to read against the meadow and bark, since it exists as a
  /// position cue for a child re-finding an instrument.
  static const ghostOpacity = 0.35;

  static const caption = 'Help them order the sounds, highest at the top.';

  final ConceptTier tier;

  /// Supplied by tests; otherwise the screen makes and disposes its own.
  final OrderingGameState? state;

  const OrderingScreen({super.key, required this.tier, this.state});

  @override
  State<OrderingScreen> createState() => _OrderingScreenState();
}

/// How an instrument is getting back to its stump: from the platform it was
/// sent back from, or from wherever a missed drop was released.
class _Journey {
  final int serial;
  final int? slot;
  final Offset? releasedFrom;
  const _Journey.fromSlot(this.serial, int this.slot) : releasedFrom = null;
  const _Journey.fromRelease(this.serial, Offset this.releasedFrom)
    : slot = null;
}

class _OrderingScreenState extends State<OrderingScreen> {
  late final OrderingGameState _state;
  late final bool _ownsState;
  late final ConfettiController _confetti;

  final GlobalKey _sceneKey = GlobalKey();
  int? _hoverSlot;
  final Set<int> _dragging = {};
  final Map<int, _Journey> _journeys = {};
  int _journeySerial = 0;
  int _lastReturnSerial = 0;
  GameStatus _lastStatus = GameStatus.notStarted;

  @override
  void initState() {
    super.initState();
    _ownsState = widget.state == null;
    _state = widget.state ?? OrderingGameState(tier: widget.tier);
    _state.addListener(_onChanged);
    _confetti = ConfettiController(duration: AppAnimations.confettiBurst);
    if (_state.status == GameStatus.notStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _state.startGame();
      });
    }
  }

  @override
  void dispose() {
    _state.removeListener(_onChanged);
    if (_ownsState) _state.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_state.returnSerial != _lastReturnSerial) {
      _lastReturnSerial = _state.returnSerial;
      for (final entry in _state.returnedFrom.entries) {
        _journeys[entry.key] = _Journey.fromSlot(++_journeySerial, entry.value);
      }
    }
    // Back on the tree again: the journey home is over.
    _journeys.removeWhere((note, _) => _state.isPlaced(note));

    final status = _state.status;
    if (status == GameStatus.showingFeedback &&
        _lastStatus != GameStatus.showingFeedback) {
      _confetti.play();
    }
    _lastStatus = status;

    if (status == GameStatus.completed) {
      _finishSession();
      return;
    }
    if (mounted) setState(() {});
  }

  void _finishSession() {
    context.read<ProgressState>().completeSession(
      gameType: 'high_low',
      correctCount: _state.correctCount,
      totalCount: _state.totalPrompts,
    );
    if (_state.correctCount >= 4) {
      context.read<SkillState>().awardXp(
        MusicalSkill.pitchAwareness,
        _state.correctCount * 10,
      );
    }
    final routeExtra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    context.go(
      AppRoutes.reward,
      extra: {
        'correctCount': _state.correctCount,
        'totalCount': _state.totalPrompts,
        'gameType': 'high_low',
        'fromPath': routeExtra?['fromPath'] ?? false,
        'nodeId': routeExtra?['nodeId'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameScreenLayout(
      background: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/MeadowWidescreen.png',
            fit: BoxFit.cover,
          ),
          LayoutBuilder(
            builder: (context, constraints) => _buildScene(constraints.biggest),
          ),
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.gold,
                  AppColors.correct,
                ],
                numberOfParticles: 20,
                gravity: 0.3,
              ),
            ),
          ),
        ],
      ),
      header: HighLowHeader(
        onClose: () => context.go(AppRoutes.home),
        captionText: OrderingScreen.caption,
        skipEnabled: _state.status != GameStatus.completed,
        onSkip: _state.escape,
      ),
      body: const SizedBox.shrink(),
      footer: ProgressDots(
        totalDots: _state.totalPrompts,
        currentIndex: _state.currentPromptIndex,
        completedCount: _state.results.length,
      ),
      scrollableBody: false,
    );
  }

  // ---- scene ----

  Widget _buildScene(Size screen) {
    final round = _state.round;
    if (round == null) return const SizedBox.shrink();
    final layout = OrderingLayout(screen, noteCount: round.notes.length);
    final n = round.notes.length;

    return Stack(
      key: _sceneKey,
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < n; i++) _buildStump(layout, i),
        Positioned.fromRect(
          rect: layout.treeRect,
          child: Image.asset(
            'assets/images/backgrounds/props/OrderingTree.png',
            fit: BoxFit.fill,
          ),
        ),
        _buildClef(layout),
        for (final slot in round.activeSlots) _buildSlot(layout, slot),
        for (var i = 0; i < n; i++) _buildGhost(layout, i),
        for (var i = 0; i < n; i++) _buildInstrument(layout, i),
        Positioned(
          right: AppSpacing.md,
          top: screen.height * 0.26,
          child: _buildReplay(),
        ),
      ],
    );
  }

  static const _stumpSurfaceFraction = 0.37; // see HighLowScreen

  Widget _buildStump(OrderingLayout layout, int note) {
    final feet = layout.stumpFeet(note);
    final width = layout.stumpInstrumentSize * 0.95;
    final isA = note.isEven;
    final height = width * (isA ? 794 / 1512 : 781 / 1506);
    return Positioned(
      left: feet.dx - width / 2,
      top: feet.dy - height * _stumpSurfaceFraction,
      child: Image.asset(
        isA
            ? 'assets/images/backgrounds/props/StumpA.png'
            : 'assets/images/backgrounds/props/StumpB.png',
        width: width,
        height: height,
      ),
    );
  }

  Widget _buildClef(OrderingLayout layout) {
    final feet = layout.clefFeet;
    final h = layout.clefHeight;
    return Positioned(
      left: feet.dx - h,
      width: h * 2,
      top: feet.dy - h,
      height: h,
      child: Center(
        child: MouthSprite(
          frames: clefMouthFrameAssets,
          frame: MouthFrame.closed,
          height: h,
        ),
      ),
    );
  }

  SlotState _slotState(int slot) {
    final occupant = _state.occupantOf(slot);
    if (_hoverSlot == slot && occupant == null) return SlotState.hovering;
    if (occupant == null) return SlotState.empty;
    return _state.lockedNotes.contains(occupant)
        ? SlotState.confirmed
        : SlotState.filled;
  }

  Widget _buildSlot(OrderingLayout layout, int slot) {
    final c = layout.slotCentre(slot);
    // A generous target — the whole band belonging to this platform, wider
    // than its face — so a small child's aim doesn't have to be exact.
    final w = layout.slotSize.width * 1.35;
    final h = layout.placedSize;
    return Positioned(
      left: c.dx - w / 2,
      top: c.dy - h * 0.8,
      width: w,
      height: h,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) => _state.occupantOf(slot) == null,
        onAcceptWithDetails: (d) {
          setState(() => _hoverSlot = null);
          _state.dropOnSlot(d.data, slot);
        },
        onMove: (_) {
          if (_hoverSlot != slot) setState(() => _hoverSlot = slot);
        },
        onLeave: (_) {
          if (_hoverSlot == slot) setState(() => _hoverSlot = null);
        },
        builder: (context, _, _) => Align(
          alignment: Alignment(0, 0.6),
          child: OrderingSlot(
            key: ValueKey('slot-$slot'),
            state: _slotState(slot),
            size: layout.slotSize,
          ),
        ),
      ),
    );
  }

  String _assetFor(OrderingLayout layout, int note) {
    final instrument = _state.round!.notes[note].instrument;
    return layout.stumpFeet(note).dx < layout.screen.width / 2
        ? instrument.leftAssetPath
        : instrument.rightAssetPath;
  }

  double _scaleOf(int note) =>
      _state.round!.notes[note].instrument.displaySizeScale;

  /// A greyed ghost left on a stump while its instrument is away, so the
  /// layout never reflows and small children can find where it lives.
  Widget _buildGhost(OrderingLayout layout, int note) {
    final away = _state.isPlaced(note) || _dragging.contains(note);
    final feet = layout.stumpFeet(note);
    final size = layout.stumpInstrumentSize * _scaleOf(note);
    return Positioned(
      left: feet.dx - size / 2,
      top: feet.dy - size,
      width: size,
      height: size,
      child: IgnorePointer(
        child: AnimatedOpacity(
          key: ValueKey('ghost-$note'),
          opacity: away ? OrderingScreen.ghostOpacity : 0.0,
          duration: AppAnimations.fast,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.33, 0.33, 0.33, 0, 0, //
              0.33, 0.33, 0.33, 0, 0,
              0.33, 0.33, 0.33, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: Image.asset(_assetFor(layout, note), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildInstrument(OrderingLayout layout, int note) {
    final placed = _state.placements[note];
    final locked = _state.lockedNotes.contains(note);
    final scale = _scaleOf(note);
    final stumpSize = layout.stumpInstrumentSize * scale;
    final placedSize = layout.placedSize * scale;
    final size = placed == null ? stumpSize : placedSize;
    final feet = placed == null
        ? layout.stumpFeet(note)
        : layout.slotCentre(placed);
    final asset = _assetFor(layout, note);
    final glowing = _state.playingIndex == note;

    Widget art = Image.asset(asset, fit: BoxFit.contain);

    // Home again after being sent back or missing a platform: the shared
    // wrong-drag return, plus a shrink-to-grow so it doesn't pop in size.
    final journey = placed == null ? _journeys[note] : null;
    if (journey != null) {
      final from = journey.slot != null
          ? layout.slotCentre(journey.slot!) - layout.stumpFeet(note)
          : journey.releasedFrom!;
      art = RetrySettle(
        key: ValueKey('journey-$note-${journey.serial}'),
        from: from,
        child: journey.slot != null
            ? TweenAnimationBuilder<double>(
                tween: Tween(begin: placedSize / stumpSize, end: 1),
                duration: RetrySettle.duration,
                curve: Curves.easeOut,
                builder: (context, s, child) => Transform.scale(
                  scale: s,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
                child: art,
              )
            : art,
      );
    } else if (placed != null && !locked) {
      // Landing: a small pop as it settles onto the platform.
      art = art
          .animate(key: ValueKey('land-$note-$placed'))
          .scale(
            begin: const Offset(1.18, 1.18),
            end: const Offset(1, 1),
            duration: AppAnimations.fast,
            curve: Curves.easeOutBack,
          );
    }

    Widget body = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: art),
          Positioned(
            top: -size * 0.15,
            child: DriftingNotes(size: size, active: glowing),
          ),
          if (locked)
            Positioned(
              right: -size * 0.04,
              top: size * 0.02,
              child: PlacementTick(
                key: ValueKey('tick-$note'),
                size: (size * 0.36).clamp(20.0, 34.0),
              ),
            ),
        ],
      ),
    );

    body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _state.tapInstrument(note),
      child: body,
    );

    if (!locked) {
      body = Draggable<int>(
        data: note,
        // The finger holds the instrument by its middle, whether it came
        // off a stump or off a platform.
        dragAnchorStrategy: (draggable, context, position) =>
            Offset(stumpSize / 2, stumpSize / 2),
        feedback: Opacity(
          opacity: 0.9,
          child: SizedBox(
            width: stumpSize,
            height: stumpSize,
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
        childWhenDragging: const SizedBox.shrink(),
        onDragStarted: () {
          setState(() => _dragging.add(note));
          _state.lift(note);
        },
        onDragEnd: (details) {
          setState(() => _dragging.remove(note));
          if (!details.wasAccepted) _returnMissed(layout, note, details.offset);
        },
        child: body,
      );
    }

    return Positioned(
      key: ValueKey('instrument-$note'),
      left: feet.dx - size / 2,
      top: feet.dy - size,
      child: body,
    );
  }

  /// A drag that ended nowhere a platform accepted it: the instrument goes
  /// home the way a wrong drop does — one spring back to its stump.
  void _returnMissed(OrderingLayout layout, int note, Offset feedbackTopLeft) {
    final scene = _sceneKey.currentContext?.findRenderObject();
    if (scene is! RenderBox) return;
    final local = scene.globalToLocal(feedbackTopLeft);
    final size = layout.stumpInstrumentSize * _scaleOf(note);
    final feet = layout.stumpFeet(note);
    final boxTopLeft = Offset(feet.dx - size / 2, feet.dy - size);
    setState(() {
      _journeys[note] = _Journey.fromRelease(
        ++_journeySerial,
        local - boxTopLeft,
      );
    });
  }

  Widget _buildReplay() {
    final used = _state.replaysUsed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Listen again',
          child: GestureDetector(
            onTap: _state.replay,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.paper,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.replay_rounded, color: AppColors.ink),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Three offered; the pips fill as they're used. Past three, replays
        // still work — the count is the signal, not a cap.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < OrderingGameState.freeReplays; i++)
              Container(
                key: ValueKey('replay-pip-$i'),
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < used ? AppColors.warmGray : AppColors.paper,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

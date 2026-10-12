import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/config.dart';
import '../../../app/router.dart';
import '../../../app/state/dev_settings_state.dart';
import '../../../app/state/profile_state.dart';
import '../../../app/state/progress_state.dart';
import '../../../models/agency_stage.dart';
import '../../../models/game_status.dart';
import '../../../ui/components/arc_flight.dart';
import '../../../ui/components/dev_setup_overlay.dart';
import '../../../ui/components/drifting_notes.dart';
import '../../../ui/components/game_screen_layout.dart';
import '../../../ui/theme/theme.dart';
import '../../high_low/ordering/ordering_slot.dart';
import '../../high_low/widgets/character_art.dart';
import '../../high_low/widgets/high_low_header.dart';
import '../../high_low/widgets/mouth_frames.dart';
import '../models/loud_quiet_layout.dart';
import '../state/loud_quiet_game_state.dart';

/// The Loud or Quiet screen (Trello card 162): Piper at the left, the
/// instruments on stumps through the middle, the dial on the right with Clef
/// on its middle platform. See [LoudQuietLayout] and [LoudQuietGameState].
///
/// **Built directly, not on a shared template** (card 162). Reused as-is from
/// High vs Low, as components: the header and caption (now taking a title),
/// the character sprites, the drop slot and tick, the shared flight arc,
/// the drifting notes. Duplicated here, to compare when a template is
/// extracted: the dev gate start-up, the stump drawing, the instrument
/// button, the sparkle, the earned arrow, the confetti.
///
/// **No Listen Again button** (card 195): tapping either character replays
/// the round, the character first and then the sounds.
class LoudQuietScreen extends StatefulWidget {
  /// Injected by tests; the screen makes its own otherwise.
  final LoudQuietGameState? gameState;

  const LoudQuietScreen({super.key, this.gameState});

  static const String title = 'Loud or Quiet';

  @override
  State<LoudQuietScreen> createState() => _LoudQuietScreenState();
}

class _LoudQuietScreenState extends State<LoudQuietScreen> {
  late final LoudQuietGameState _game;
  late final bool _ownsGame;
  late final ConfettiController _confetti;
  int _lastConfetti = 0;
  bool _showDevGate = false;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ownsGame = widget.gameState == null;
    _game = widget.gameState ?? LoudQuietGameState();
    _game.addListener(_onChanged);
    _confetti = ConfettiController(duration: AppAnimations.confettiBurst);

    final canUseDevTools = _profileState()?.canUseDevTools ?? devToolsEnabled;
    _showDevGate = canUseDevTools && widget.gameState == null;
    if (!_showDevGate) {
      if (widget.gameState == null) {
        // The child's own agency capability, as High vs Low does (card
        // 172). Not written back yet: Loud or Quiet doesn't run agency
        // advancement in this first build.
        _game.agencyStage =
            _profileState()?.activeProfile?.agencyOverride ??
            AgencyStage.observe;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _game.startGame());
    }
  }

  ProfileState? _profileState() {
    try {
      return context.read<ProfileState>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _startFromDevGate() {
    final dev = context.read<DevSettingsState>();
    _game
      ..agencyStage = dev.agencyStage
      ..conceptTier = dev.conceptTier
      ..roundOrder = dev.roundOrder;
    setState(() => _showDevGate = false);
    _game.startGame();
  }

  void _onChanged() {
    if (_game.confettiTrigger != _lastConfetti) {
      _lastConfetti = _game.confettiTrigger;
      _confetti.play();
    }
    if (_game.status == GameStatus.completed) {
      try {
        context.read<ProgressState>().completeSession(
          gameType: 'loud_quiet',
          correctCount: _game.correctCount,
          totalCount: _game.totalPrompts,
        );
      } on ProviderNotFoundException {
        // Tests without the app's providers.
      }
      context.go(
        AppRoutes.reward,
        extra: {
          'correctCount': _game.correctCount,
          'totalCount': _game.totalPrompts,
          'gameType': 'loud_quiet',
        },
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _game.removeListener(_onChanged);
    if (_ownsGame) _game.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showDevGate) {
      return Scaffold(body: DevSetupOverlay(onStart: _startFromDevGate));
    }
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);
    final layout = LoudQuietLayout(size, insets: insets);

    return Stack(
      children: [
        GameScreenLayout(
          background: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/backgrounds/MeadowWidescreen.png',
                fit: BoxFit.cover,
              ),
              _buildScene(layout),
            ],
          ),
          header: HighLowHeader(
            title: LoudQuietScreen.title,
            onClose: () => context.go(AppRoutes.home),
            captionText: _game.captionText,
            guidanceText: _game.guidanceText,
            skipEnabled: _game.status != GameStatus.completed,
            onSkip: _game.escape,
            captionPadding: HighLowHeader.meadowCaptionPadding(
              screen: size,
              insets: insets,
              meadowRight: layout.meadowRight,
            ),
          ),
          body: const SizedBox.shrink(),
          scrollableBody: false,
        ),
        IgnorePointer(
          child: Align(
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 20,
              gravity: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScene(LoudQuietLayout layout) {
    final round = _game.currentRound;
    final isDecide = _game.agencyStage == AgencyStage.decide;
    final slotPlatform = layout.slotPlatformFor(loud: _game.asksLoud);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: layout.dialRect,
          child: Image.asset(
            'assets/images/backgrounds/props/DialFace.png',
            fit: BoxFit.fill,
          ),
        ),
        _buildNeedle(layout),
        if (round != null)
          for (final side in [0, 1])
            if (round.instrumentOf(side).name != 'piano')
              _buildStump(layout, side),
        if (isDecide && _game.drop != LoudQuietDrop.correct)
          _buildSlot(layout, slotPlatform),
        if (round != null)
          for (final side in [0, 1])
            _buildInstrument(layout, side, slotPlatform),
        _buildPiper(layout),
        _buildClef(layout),
        if (_game.showArrow)
          Positioned(
            left: layout.arrowCentre.dx - LoudQuietLayout.arrowSize / 2,
            top: layout.arrowCentre.dy - LoudQuietLayout.arrowSize / 2,
            child: _buildArrow(),
          ),
      ],
    );
  }

  /// The needle, turning about its pivot on the dial's hub — never its
  /// image centre. Rest is straight up; it eases to where the child's tap
  /// puts it.
  Widget _buildNeedle(LoudQuietLayout layout) {
    final r = layout.needleRect;
    final pivot = Alignment(
      LoudQuietLayout.needlePivot.dx * 2 - 1,
      LoudQuietLayout.needlePivot.dy * 2 - 1,
    );
    return Positioned.fromRect(
      rect: r,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: const ValueKey('needle'),
          tween: Tween(end: _game.needle * LoudQuietLayout.sweepDegrees),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (context, degrees, child) => Transform.rotate(
            angle: degrees * 3.141592653589793 / 180,
            alignment: pivot,
            child: child,
          ),
          child: Image.asset(
            'assets/images/backgrounds/props/DialNeedle.png',
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }

  Widget _buildStump(LoudQuietLayout layout, int side) {
    const surface = 0.37;
    final width = layout.instrumentSize * 0.95;
    final isA = side == 0;
    final height = width * (isA ? 794 / 1512 : 781 / 1506);
    final groundTop = layout.screen.height - layout.groundY;
    return Positioned(
      left: layout.stumpAnchorX(side) - width / 2,
      top: groundTop - height * surface,
      child: Image.asset(
        isA
            ? 'assets/images/backgrounds/props/StumpA.png'
            : 'assets/images/backgrounds/props/StumpB.png',
        width: width,
        height: height,
      ),
    );
  }

  Widget _buildSlot(LoudQuietLayout layout, int platform) {
    return Positioned.fromRect(
      rect: layout.slotRect(platform),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) => _game.canDrop,
        onAcceptWithDetails: (d) {
          setState(() => _hovering = false);
          _game.dropInstrument(d.data);
        },
        onMove: (_) {
          if (!_hovering) setState(() => _hovering = true);
        },
        onLeave: (_) {
          if (_hovering) setState(() => _hovering = false);
        },
        builder: (context, candidate, rejected) => Align(
          alignment: const Alignment(0, 0.6),
          child: OrderingSlot(
            state: _hovering ? SlotState.hovering : SlotState.empty,
            size: layout.slotSize,
          ),
        ),
      ),
    );
  }

  Widget _buildInstrument(LoudQuietLayout layout, int side, int slotPlatform) {
    final round = _game.currentRound!;
    final instrument = round.instrumentOf(side);
    final box = layout.instrumentSize * instrument.displaySizeScale;
    final lift = box * instrument.floatFraction;
    final asset = side == 0
        ? instrument.leftAssetPath
        : instrument.rightAssetPath;
    final feet = Offset(
      layout.stumpAnchorX(side),
      layout.screen.height - layout.groundY - lift,
    );
    final playing = _game.playingIndex == side;
    final sparkles = _game.sparkleSide == side ? _game.correctTapProgress : 0;

    Widget button = GestureDetector(
      key: ValueKey('lq-instrument-$side'),
      onTap: () => _game.tapInstrument(side),
      child: SizedBox.square(
        dimension: box,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedScale(
              scale: playing ? 1.12 : 1.0,
              duration: AppAnimations.medium,
              curve: AppAnimations.bounceCurve,
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
            Positioned(
              top: -box * 0.15,
              child: DriftingNotes(size: box, active: playing),
            ),
            if (sparkles > 0)
              Positioned.fill(
                child: IgnorePointer(child: _sparkle(box, sparkles)),
              ),
          ],
        ),
      ),
    );

    final landed =
        _game.drop == LoudQuietDrop.correct && _game.lastDropSide == side;
    if (landed && _game.agencyStage == AgencyStage.decide) {
      return ArcFlight(
        key: ValueKey('lq-flight-$side'),
        from: feet,
        to: layout.platform(slotPlatform),
        size: Size.square(box),
        toScale: layout.placedSize / box,
        flying: true,
        duration: const Duration(milliseconds: 600),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            button,
            Positioned(
              right: -box * 0.06,
              top: box * 0.02,
              child: PlacementTick(size: (box * 0.4).clamp(20.0, 34.0)),
            ),
          ],
        ),
      );
    }

    if (_game.canDrop) {
      button = Draggable<int>(
        data: side,
        feedback: Opacity(
          opacity: 0.85,
          child: Image.asset(
            asset,
            width: box,
            height: box,
            fit: BoxFit.contain,
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: button),
        child: button,
      );
    }

    return Positioned(
      left: feet.dx - box / 2,
      top: feet.dy - box,
      child: button,
    );
  }

  static const List<(double top, double right)> _sparkleOffsets = [
    (0.02, 0.02),
    (0.22, -0.08),
    (0.02, 0.24),
    (0.42, 0.0),
  ];

  /// Explore's sparkle: one per correct tap, staying, still once there.
  Widget _sparkle(double size, int count) {
    final shown = count.clamp(1, _sparkleOffsets.length);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < shown; i++)
          Positioned(
            top: size * _sparkleOffsets[i].$1,
            right: size * _sparkleOffsets[i].$2,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppAnimations.fast,
              curve: Curves.easeOutBack,
              builder: (context, s, child) =>
                  Transform.scale(scale: s, child: child),
              child: Text('✨', style: TextStyle(fontSize: size * 0.18)),
            ),
          ),
      ],
    );
  }

  /// Which pose a character shows: only the one whose pole this round asks
  /// about changes — celebrating a correct answer, thinking while a nudge
  /// plays or a wrong drop settles back.
  CharacterPose _poseFor({required bool asking}) {
    if (!asking || _game.agencyStage == AgencyStage.observe) {
      return CharacterPose.speaking;
    }
    if (_game.drop == LoudQuietDrop.correct) return CharacterPose.celebrating;
    if (_game.isConsidering || _game.drop == LoudQuietDrop.retry) {
      return CharacterPose.thinking;
    }
    return CharacterPose.speaking;
  }

  Widget _character({
    required String key,
    required CharacterArt art,
    required CharacterPose pose,
    required double height,
  }) => GestureDetector(
    key: ValueKey(key),
    // Tap a character to hear the round again (card 195).
    onTap: _game.replay,
    child: CharacterSprite(
      art: art,
      pose: pose,
      mouth: MouthFrame.closed,
      height: height,
    ),
  );

  Widget _buildPiper(LoudQuietLayout layout) => Positioned(
    left: layout.piperLeftInset,
    bottom: layout.screen.height - layout.piperFeetY,
    child: _character(
      key: 'lq-piper',
      art: CharacterArt.piper,
      pose: _poseFor(asking: !_game.asksLoud),
      height: layout.piperHeight,
    ),
  );

  Widget _buildClef(LoudQuietLayout layout) {
    final h = layout.characterHeight;
    final feet = layout.clefPerch;
    return Positioned(
      left: feet.dx - h,
      width: h * 2,
      bottom: layout.screen.height - feet.dy,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _character(
          key: 'lq-clef',
          art: CharacterArt.clef,
          pose: _poseFor(asking: _game.asksLoud),
          height: h,
        ),
      ),
    );
  }

  Widget _buildArrow() => Tooltip(
    message: 'Tap when ready',
    child: GestureDetector(
      onTap: _game.tapArrow,
      child: Container(
        width: LoudQuietLayout.arrowSize,
        height: LoudQuietLayout.arrowSize,
        decoration: const BoxDecoration(
          gradient: AppColors.earnedArrowGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.earnedArrowShadow,
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
      ),
    ),
  );
}

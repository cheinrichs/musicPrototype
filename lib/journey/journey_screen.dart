import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../app/config.dart';
import '../app/rail_shell.dart';
import '../app/state/profile_state.dart';
import '../audio/audio_controller.dart';
import '../audio/sfx_type.dart';
import '../audio/sound_registry.dart';
import '../games/game_catalogue.dart';
import '../games/game_session.dart';
import '../games/high_low/models/round_instrumentation.dart';
import '../games/high_low/models/scene_layout.dart';
import '../games/high_low/widgets/character_art.dart';
import '../games/high_low/widgets/mouth_frames.dart';
import '../games/loud_quiet/models/loud_quiet_layout.dart';
import '../models/agency_stage.dart';
import '../ui/components/circle_icon_button.dart';
import 'journey_art.dart';
import 'journey_state.dart';
import 'map_decoration.dart';
import 'path_profile.dart';

/// Every beat's timing, in one place so Cooper's pacing notes are one-line
/// changes. ROUGH: first guesses, to be judged on a device.
abstract final class JourneyTiming {
  // Opening the map: pan to the chest if it's off screen, then settle.
  static const panToChest = Duration(milliseconds: 1200);
  static const holdOnChest = Duration(milliseconds: 700);
  static const panBack = Duration(milliseconds: 1000);

  // Between two games inside a stone, and after the last round.
  static const betweenGames = Duration(milliseconds: 400);
  static const afterLastRound = Duration(milliseconds: 600);

  // Both flows: the game fades, Piper stays and speaks.
  static const gameFade = Duration(milliseconds: 700);
  static const speech = Duration(milliseconds: 1600);

  // Regular stone.
  static const giftAppear = Duration(milliseconds: 600);
  static const giftGlowIn = Duration(milliseconds: 500);
  static const unwrapToReward = Duration(milliseconds: 450);
  static const rewardPop = Duration(milliseconds: 600);
  static const rewardHold = Duration(milliseconds: 600);
  static const rewardFlight = Duration(milliseconds: 900);
  static const backToMap = Duration(milliseconds: 600);

  // Milestone.
  static const arriveOnMap = Duration(milliseconds: 500);
  static const chestWake = Duration(milliseconds: 1000);
  static const chestOpenToPresents = Duration(milliseconds: 400);
  static const presentsPop = Duration(milliseconds: 600);
  static const presentsHold = Duration(milliseconds: 700);
  static const presentStagger = Duration(milliseconds: 250);

  // Both: back on the path.
  static const stoneTurns = Duration(milliseconds: 700);
  static const pinMoves = Duration(milliseconds: 700);
  static const newChestPan = Duration(milliseconds: 1000);
  static const newChestDrop = Duration(milliseconds: 700);
  static const newChestHold = Duration(milliseconds: 900);
}

/// Where the celebration is.
enum _Beat {
  none,
  playing,
  gameFading,
  speaking,
  giftAppearing,
  giftWaiting,
  giftOpen,
  chestWaking,
  chestWaiting,
  chestOpen,
  settling,
}

/// The Journey (cards 200, 203, 204, 206): the child's path of stones on one
/// horizontal painted surface, a stone played in place, and the two
/// celebrations.
///
/// **ROUGH BUILD for judging timing and sequence.** Placeholders: every
/// reward item, the rail's category icons, the decorations and the painted
/// path (a dashed line). No iris transition yet (card 218).
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  final ScrollController _scroll = ScrollController();
  late final ConfettiController _sparkles;
  late final JourneyState _journey;

  /// The opening pan runs untouchable.
  bool _panning = true;

  _Beat _beat = _Beat.none;

  // Playing a stone.
  int _segment = 0;
  final List<SetReport> _reports = [];
  String _lastGame = JourneyState.games.first;

  // Regular stone.
  bool _gameVisible = true;

  /// The stone's layer (game, Piper, gift) is mounted; [_gameVisible] fades
  /// it, and it comes down once faded.
  bool _layerUp = false;

  /// A game is mounted in the layer — false for the dev shortcut, which
  /// celebrates without playing.
  bool _hasGame = false;
  bool _giftShown = false;
  bool _giftGlow = false;

  // Milestone chest. [_chestAt] holds it where it is while its own stone is
  // celebrated; null puts it at the journey's chest stone.
  int? _chestAt;
  bool _chestAwake = false;
  bool _chestOpened = false;
  bool _chestHidden = false;
  bool _chestDropping = false;

  /// Decorations landed on the map but not yet banked.
  final List<Reward> _decorationsLanded = [];

  /// The shell's rail; standalone (tests) the screen keeps its own, and
  /// draws the flights itself.
  late final RailController _rail;
  RailController? _ownRail;

  /// The stone the arrow points on from, once a stone is done.
  int? _arrowFrom;

  Completer<void>? _tap;

  @override
  void initState() {
    super.initState();
    _sparkles = ConfettiController(duration: const Duration(seconds: 1));
    _journey = context.read<JourneyState>()
      ..useProfile(_profiles()?.activeProfile?.id);
    try {
      _rail = context.read<RailController>();
    } on ProviderNotFoundException {
      _rail = _ownRail = RailController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _openingPan());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _sparkles.dispose();
    _ownRail?.dispose();
    super.dispose();
  }

  ProfileState? _profiles() {
    try {
      return context.read<ProfileState>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  AgencyStage get _agency =>
      _profiles()?.activeProfile?.agencyOverride ?? AgencyStage.observe;

  _MapGeometry _geometry() =>
      _MapGeometry(MediaQuery.sizeOf(context), MediaQuery.paddingOf(context));

  Future<void> _wait(Duration d) => Future.delayed(d);

  /// A decoration's poke: its non-pitched sound, if one is recorded —
  /// silent otherwise, never an error.
  void _pokeSound(String soundId) {
    final path = Sounds.pathOf(soundId);
    if (path == null) return;
    unawaited(
      AudioController.instance.playClip(path).catchError((Object _) {}),
    );
  }

  void _sfx(SfxType type) {
    unawaited(AudioController.instance.playSfx(type).catchError((Object _) {}));
  }

  // ---------------------------------------------------------------------------
  // Panning
  // ---------------------------------------------------------------------------

  double _offsetFor(_MapGeometry g, int stone, {double at = 0.4}) {
    final max = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    return (g.stoneX(stone) - g.visibleWidth * at).clamp(0.0, max);
  }

  bool _onScreen(_MapGeometry g, double x) {
    final o = _scroll.offset;
    return x > o + g.margin && x < o + g.visibleWidth - g.margin;
  }

  Future<void> _panTo(double offset, Duration d) => _scroll.hasClients
      ? _scroll.animateTo(offset, duration: d, curve: Curves.easeInOutCubic)
      : Future.value();

  /// Card 204: on opening, pan to the chest if it is off screen, then settle
  /// on the child's stone.
  Future<void> _openingPan() async {
    if (!mounted || !_scroll.hasClients) return;
    final g = _geometry();
    final home = _offsetFor(g, _journey.current);
    _scroll.jumpTo(home);
    if (!_onScreen(g, g.stoneX(_journey.chestStone))) {
      await _panTo(
        _offsetFor(g, _journey.chestStone, at: 0.55),
        JourneyTiming.panToChest,
      );
      await _wait(JourneyTiming.holdOnChest);
      if (!mounted) return;
      await _panTo(home, JourneyTiming.panBack);
    }
    if (mounted) setState(() => _panning = false);
  }

  // ---------------------------------------------------------------------------
  // Playing a stone
  // ---------------------------------------------------------------------------

  void _startStone() {
    if (_beat != _Beat.none || _panning) return;
    _sfx(SfxType.tap);
    _journey.meet(_part.gameId);
    setState(() {
      _arrowFrom = null;
      _gameVisible = true;
      _layerUp = true;
      _hasGame = true;
      _segment++;
      _beat = _Beat.playing;
    });
  }

  StonePart get _part {
    final plan = _journey.planFor(_agency);
    return plan[_journey.partsDone.clamp(0, plan.length - 1)];
  }

  /// The stone's progress for the part being played: every round of the
  /// stone is one step, whichever game it belongs to.
  ProgressSource get _stoneProgress {
    final plan = _journey.planFor(_agency);
    final index = _journey.partsDone.clamp(0, plan.length - 1);
    return ProgressSource.stone(
      total: plan.fold(0, (n, p) => n + p.rounds),
      doneBefore: plan.take(index).fold(0, (n, p) => n + p.rounds),
    );
  }

  /// The X: back to the map, the stone keeps its place.
  void _leaveStone() => setState(() {
    _beat = _Beat.none;
    _layerUp = false;
    _hasGame = false;
  });

  Future<void> _onPartFinished(SetReport report) async {
    _reports.add(report);
    _lastGame = report.gameType;
    _journey.finishPart();
    final plan = _journey.planFor(_agency);
    if (_journey.partsDone < plan.length) {
      await _wait(JourneyTiming.betweenGames);
      _journey.meet(_part.gameId);
      if (mounted) setState(() => _segment++);
      return;
    }
    // The whole stone counts toward agency, as one set (cards 198/199).
    if (mounted) {
      GameSession.recordFinishedSet(
        context,
        SetReport(
          gameType: 'journey_stone',
          agency: _agency,
          rounds: <RoundInstrumentation>[for (final r in _reports) ...r.rounds],
          correctCount: _reports.fold(0, (n, r) => n + r.correctCount),
        ),
      );
    }
    _reports.clear();
    await _wait(JourneyTiming.afterLastRound);
    await _celebrate();
  }

  // ---------------------------------------------------------------------------
  // The celebrations
  // ---------------------------------------------------------------------------

  Future<void> _celebrate() async {
    if (!mounted) return;
    final stone = _journey.current;
    final milestone = JourneyState.isMilestone(stone);
    final rewards = _journey.rewardsForCurrent();

    // 1–2. The game fades, Piper stays; she speaks.
    setState(() => _beat = _Beat.gameFading);
    await _wait(JourneyTiming.gameFade);
    if (!mounted) return;
    setState(() => _beat = _Beat.speaking);
    _sfx(SfxType.correct);
    await _wait(JourneyTiming.speech);
    if (!mounted) return;

    if (milestone) {
      await _milestone(stone, rewards);
    } else {
      await _regular(stone, rewards);
    }
    if (!mounted) return;
    await _settle(stone, rewards, milestone: milestone);
  }

  /// Regular stone: gift appears, the child taps to unwrap, the reward flies
  /// to its category in the rail; then back to the path.
  Future<void> _regular(int stone, List<Reward> rewards) async {
    setState(() {
      _beat = _Beat.giftAppearing;
      _giftShown = true;
    });
    await _wait(JourneyTiming.giftAppear);
    if (!mounted) return;
    setState(() {
      _giftGlow = true;
      _beat = _Beat.giftWaiting;
    });
    await _waitForTap();
    if (!mounted) return;

    _sfx(SfxType.reward);
    setState(() => _beat = _Beat.giftOpen);
    await _wait(JourneyTiming.unwrapToReward);
    if (!mounted) return;

    final g = _geometry();
    await _presentsOut(g.giftCentre, rewards, g);
    if (!mounted) return;

    setState(() {
      _gameVisible = false;
      _beat = _Beat.settling;
    });
    await _wait(JourneyTiming.backToMap);
  }

  /// Milestone: back on the map, the chest behind this stone wakes and lifts
  /// off; the child taps it; presents come out and fly to their places.
  Future<void> _milestone(int stone, List<Reward> rewards) async {
    final g = _geometry();
    setState(() {
      _chestAt = stone;
      _gameVisible = false;
      _beat = _Beat.chestWaking;
    });
    _scroll.jumpTo(_offsetFor(g, stone, at: 0.45));
    await _wait(JourneyTiming.backToMap);
    if (!mounted) return;
    setState(() => _layerUp = false);
    await _wait(JourneyTiming.arriveOnMap);
    if (!mounted) return;

    // Plain → glow crossfade (the same artwork), lifting in sparkles.
    setState(() => _chestAwake = true);
    _sparkles.play();
    await _wait(JourneyTiming.chestWake);
    if (!mounted) return;
    setState(() => _beat = _Beat.chestWaiting);
    await _waitForTap();
    if (!mounted) return;

    _sfx(SfxType.reward);
    setState(() {
      _chestOpened = true;
      _beat = _Beat.chestOpen;
    });
    _sparkles.play();
    await _wait(JourneyTiming.chestOpenToPresents);
    if (!mounted) return;
    // Out of the chest's opening, not its middle.
    final r = g.chestRect(stone, lifted: true);
    final chest =
        Offset(r.center.dx, r.top + r.height * OpenChestArt.mouth) -
        _scrollOffset;
    await _presentsOut(chest, rewards, g);
  }

  Offset get _scrollOffset =>
      Offset(_scroll.hasClients ? _scroll.offset : 0, 0);

  /// Each reward pops out of [from] into a fan, holds, then flies: to its
  /// rail category, or (a decoration) onto the map by the stone.
  Future<void> _presentsOut(
    Offset from,
    List<Reward> rewards,
    _MapGeometry g,
  ) async {
    final n = rewards.length;
    // Kept clear of the top edge at its popped (1.2×) size: on a phone the
    // lifted chest is high enough to push the fan off screen.
    final topmost = g.padding.top + g.rewardSize * 0.6 + 8;
    final fan = [
      for (var i = 0; i < n; i++)
        from +
            Offset(
              (i - (n - 1) / 2) * g.rewardSize * 1.4,
              -g.rewardSize *
                  (n == 1 ? 1.3 : 1.6 - 0.3 * (i - (n - 1) / 2).abs()),
            ),
    ].map((p) => Offset(p.dx, math.max(p.dy, topmost))).toList();
    final pops = [
      for (var i = 0; i < n; i++)
        RewardFlight(
          child: _rewardItem(rewards[i], g),
          from: from,
          to: fan[i],
          duration: JourneyTiming.presentsPop,
          size: g.rewardSize,
          fromScale: 0.2,
          toScale: 1.2,
          lift: 0,
        ),
    ];
    pops.forEach(_rail.fly);
    await _wait(JourneyTiming.presentsPop + JourneyTiming.presentsHold);
    if (!mounted) return;

    final rail = RailLayout(g.size, g.padding);
    for (var i = 0; i < n; i++) {
      final r = rewards[i];
      final dest = r.type.destination;
      final to = dest == null
          ? g.decorationSpot(r) - _scrollOffset
          : rail.landingOf(dest);
      late final RewardFlight flight;
      flight = RewardFlight(
        child: _rewardItem(r, g),
        from: fan[i],
        to: to,
        duration: JourneyTiming.rewardFlight,
        size: g.rewardSize,
        fromScale: 1.2,
        toScale: dest == null ? 1 : 0.45,
        lift: g.rewardSize * 1.5,
        trail: dest != null,
        onLanded: () {
          _rail.land(flight);
          if (dest != null) _rail.pulse(dest);
          if (dest == null && mounted) {
            setState(() => _decorationsLanded.add(r));
          }
        },
      );
      _rail
        ..land(pops[i])
        ..fly(flight);
      if (i < n - 1) await _wait(JourneyTiming.presentStagger);
      if (!mounted) return;
    }
    await _wait(JourneyTiming.rewardFlight + JourneyTiming.rewardHold);
  }

  Widget _rewardItem(Reward r, _MapGeometry g) =>
      RewardItem(reward: r, size: g.rewardSize);

  /// Back on the path: the stone turns rainbow, the pin steps on, an arrow
  /// points onward; after a milestone a new chest appears at the next one.
  Future<void> _settle(
    int stone,
    List<Reward> rewards, {
    required bool milestone,
  }) async {
    setState(() {
      _beat = _Beat.settling;
      if (milestone) _chestHidden = true;
    });
    _journey.completeStone(rewards);
    setState(() {
      _layerUp = false;
      _hasGame = false;
      _decorationsLanded.clear();
      _giftShown = false;
      _giftGlow = false;
      _chestAt = null;
      _chestAwake = false;
      _chestOpened = false;
    });
    await _wait(JourneyTiming.stoneTurns);
    if (!mounted) return;

    if (milestone) {
      final g = _geometry();
      final next = _journey.chestStone;
      final back = _offsetFor(g, _journey.current);
      if (!_onScreen(g, g.stoneX(next))) {
        await _panTo(_offsetFor(g, next, at: 0.55), JourneyTiming.newChestPan);
      }
      if (!mounted) return;
      setState(() {
        _chestHidden = false;
        _chestDropping = true;
      });
      await _wait(JourneyTiming.newChestDrop + JourneyTiming.newChestHold);
      if (!mounted) return;
      setState(() => _chestDropping = false);
      await _panTo(back, JourneyTiming.newChestPan);
    }
    if (!mounted) return;
    setState(() {
      _arrowFrom = stone;
      _beat = _Beat.none;
    });
  }

  Future<void> _waitForTap() {
    _tap = Completer<void>();
    return _tap!.future;
  }

  void _tapped() {
    final tap = _tap;
    if (tap == null || tap.isCompleted) return;
    _sfx(SfxType.tap);
    tap.complete();
  }

  // ---------------------------------------------------------------------------
  // Dev
  // ---------------------------------------------------------------------------

  /// Dev only: celebrate the current stone without playing it.
  void _devFinishStone() {
    if (_beat != _Beat.none || _panning) return;
    setState(() {
      _arrowFrom = null;
      _gameVisible = true;
      _layerUp = true;
      _hasGame = false;
    });
    _celebrate();
  }

  /// Dev only: bank stones until the child stands on the next milestone.
  void _devToMilestone() {
    if (_beat != _Beat.none || _panning) return;
    while (!JourneyState.isMilestone(_journey.current)) {
      _journey.completeStone(_journey.rewardsForCurrent());
    }
    setState(() => _arrowFrom = null);
    final g = _geometry();
    _panTo(_offsetFor(g, _journey.current), JourneyTiming.panBack);
  }

  void _devReset() {
    if (_beat != _Beat.none) return;
    _journey.reset();
    setState(() => _arrowFrom = null);
    _panTo(0, JourneyTiming.panBack);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    context.watch<JourneyState>();
    final g = _geometry();
    final inStone = _beat != _Beat.none;
    // The rail slides away while a game plays.
    final immersive = _beat == _Beat.playing;
    if (_rail.immersive != immersive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rail.immersive = immersive;
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            // The chest is tapped on the map.
            ignoring: _panning || (inStone && _beat != _Beat.chestWaiting),
            child: _buildMap(g),
          ),
          if (_layerUp)
            IgnorePointer(
              ignoring: !(_beat == _Beat.playing || _beat == _Beat.giftWaiting),
              child: AnimatedOpacity(
                opacity: _gameVisible ? 1 : 0,
                duration: JourneyTiming.backToMap,
                child: _buildStoneLayer(g),
              ),
            ),
          if (_ownRail != null)
            ListenableBuilder(
              listenable: _ownRail!,
              builder: (context, _) => Stack(
                fit: StackFit.expand,
                children: [
                  for (final f in _ownRail!.flights)
                    RewardFlightView(key: ObjectKey(f), flight: f),
                ],
              ),
            ),
          if (!inStone)
            Positioned(
              left: g.padding.left + 12,
              top: g.padding.top + 12,
              child: const BackToLandingButton(),
            ),
          if (devToolsEnabled && !inStone && !_panning) _buildDevBar(g),
        ],
      ),
    );
  }

  Widget _buildMap(_MapGeometry g) {
    final current = _journey.current;
    final count = math.max(_journey.chestStone + 3, current + 6);
    final chestStone = _chestAt ?? _journey.chestStone;
    final width = g.stoneX(count - 1) + g.size.width * 0.6;

    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: g.size.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _Backdrop(width: width, g: g),
            for (final d in [..._journey.decorations, ..._decorationsLanded])
              _placed(
                Rect.fromCenter(
                  center: g.decorationSpot(d),
                  width: g.decorationSize,
                  height: g.decorationSize,
                ),
                // Tappable: it reacts when poked and returns to rest.
                MapDecoration(
                  key: ValueKey('decoration-${d.stone}-${d.index}'),
                  name: MapDecoration.nameOf(d.artId),
                  size: g.decorationSize,
                  onPoke: _pokeSound,
                ).animate().scaleXY(begin: 1.4, end: 1, duration: 400.ms),
              ),
            // Clef stands beyond the path's far edge, and the chest behind
            // its stone: both drawn before the stones — until the chest
            // wakes and lifts off, when it is drawn over everything.
            _buildCompanion(g, current, clef: true),
            if (!_chestHidden && !_chestAwake) _buildChest(g, chestStone),
            for (var i = 0; i < count; i++) _buildStone(g, i, current),
            if (_arrowFrom != null && _arrowFrom! + 2 < count)
              _buildArrow(g, _arrowFrom!),
            _buildCompanion(g, current, clef: false),
            _buildPin(g, current),
            if (!_chestHidden && _chestAwake) _buildChest(g, chestStone),
          ],
        ),
      ),
    );
  }

  Widget _placed(Rect r, Widget child) =>
      Positioned.fromRect(rect: r, child: child);

  Widget _buildStone(_MapGeometry g, int i, int current) {
    final state = i < current
        ? StoneState.done
        : i == current
        ? StoneState.current
        : StoneState.locked;
    final stone = AnimatedSwitcher(
      duration: JourneyTiming.stoneTurns,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(
            begin: 1.25,
            end: 1.0,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
      child: StoneArt(
        key: ValueKey(state),
        state: state,
        variant: i % 3,
        size: g.stoneSize(i),
      ),
    );
    return _placed(
      g.stoneRect(i),
      GestureDetector(
        key: ValueKey('stone-$i'),
        behavior: HitTestBehavior.opaque,
        onTap: i == current ? _startStone : null,
        child: state == StoneState.current
            ? stone
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1, end: 1.05, duration: 900.ms)
            : stone,
      ),
    );
  }

  Widget _buildPin(_MapGeometry g, int stone) {
    final r = g.pinRect(stone);
    return AnimatedPositioned(
      duration: JourneyTiming.pinMoves,
      curve: Curves.easeInOutCubic,
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: GestureDetector(
        onTap: _startStone,
        child: AvatarPin(index: avatarIndexFor(_profiles()?.activeProfile?.id)),
      ),
    );
  }

  Widget _buildChest(_MapGeometry g, int stone) {
    final lifted = _chestAwake;
    final r = g.chestRect(stone, lifted: lifted);
    Widget chest = Stack(
      fit: StackFit.expand,
      children: [
        if (_chestOpened)
          const OpenChestArt().animate().scaleXY(
            begin: 0.85,
            end: 1,
            duration: 300.ms,
            curve: Curves.easeOutBack,
          )
        else ...[
          Image.asset(JourneyArt.chestPlain, fit: BoxFit.contain),
          // Same artwork: the glow crossfades in, nothing animates separately.
          AnimatedOpacity(
            opacity: _chestAwake ? 1 : 0,
            duration: JourneyTiming.chestWake,
            child: Image.asset(JourneyArt.chestGlow, fit: BoxFit.contain),
          ),
        ],
        Align(
          child: ConfettiWidget(
            confettiController: _sparkles,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 24,
            gravity: 0.15,
            maxBlastForce: 14,
            minBlastForce: 4,
            colors: const [
              Color(0xFFFFE07A),
              Color(0xFFFFF4C2),
              Color(0xFFFFC94D),
              Colors.white,
            ],
            createParticlePath: _starPath,
          ),
        ),
      ],
    );
    if (_beat == _Beat.chestWaiting) {
      chest = chest
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -r.height * 0.04, duration: 700.ms)
          .scaleXY(begin: 1, end: 1.04, duration: 700.ms);
    }
    if (_chestDropping) {
      chest = chest
          .animate()
          .fadeIn(duration: 250.ms)
          .moveY(
            begin: -g.size.height * 0.3,
            end: 0,
            duration: JourneyTiming.newChestDrop,
            curve: Curves.bounceOut,
          );
    }
    return AnimatedPositioned(
      key: const ValueKey('chest'),
      duration: JourneyTiming.chestWake,
      curve: Curves.easeOutBack,
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tapped,
        child: chest,
      ),
    );
  }

  /// Onward: from the child's new stone toward the one after it — the
  /// walked side behind is where Piper and Clef stand.
  Widget _buildArrow(_MapGeometry g, int from) {
    final a = g.stoneCentre(from + 1);
    final b = g.stoneCentre(from + 2);
    final st = g.stoneSize(from + 1);
    final mid = Offset.lerp(a, b, 0.5)! - Offset(0, st * 0.35);
    final s = st * 0.6;
    return _placed(
      Rect.fromCenter(center: mid, width: s, height: s),
      Transform.rotate(
            angle: (b - a).direction,
            child: Icon(
              Icons.double_arrow_rounded,
              size: s,
              color: Colors.white,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
            ),
          )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveX(begin: -s * 0.12, end: s * 0.12, duration: 600.ms),
    );
  }

  Widget _buildStoneLayer(_MapGeometry g) {
    final part = _part;
    final showGame = _beat == _Beat.playing;
    final piper = _piperSpot(g);
    final celebrating = _beat.index >= _Beat.gameFading.index;

    return Stack(
      fit: StackFit.expand,
      children: [
        // The games' own backdrop stays when the game fades.
        Image.asset(
          'assets/images/backgrounds/MeadowWidescreen.png',
          fit: BoxFit.cover,
        ),
        if (_hasGame && (_beat == _Beat.playing || _beat == _Beat.gameFading))
          AnimatedOpacity(
            opacity: showGame ? 1 : 0,
            duration: JourneyTiming.gameFade,
            child: IgnorePointer(
              ignoring: !showGame,
              child: KeyedSubtree(
                key: ValueKey('segment-$_segment'),
                child: gameScreens[part.gameId]!(
                  GameEntry(
                    agency: _agency,
                    rounds: part.rounds,
                    // The bar counts the stone, not this game's share.
                    progress: _stoneProgress,
                    onFinished: _onPartFinished,
                    onLeave: _leaveStone,
                  ),
                ),
              ),
            ),
          ),
        // Piper stays where the game had her, in her celebrating pose.
        if (celebrating)
          Positioned(
            left: piper.left,
            bottom: piper.bottom,
            child: CharacterSprite(
              art: CharacterArt.piper,
              pose: CharacterPose.celebrating,
              mouth: MouthFrame.closed,
              height: piper.height,
            ),
          ),
        if (_beat.index >= _Beat.speaking.index)
          Positioned(
            left: piper.left + (piper.right - piper.left) * 0.55,
            bottom: piper.bottom + piper.height * 0.9,
            child: const SpeechBubble(text: 'That was brilliant!')
                .animate()
                .scaleXY(
                  begin: 0.4,
                  end: 1,
                  duration: 300.ms,
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: 150.ms),
          ),
        if (_giftShown) _buildGift(g),
      ],
    );
  }

  Widget _buildGift(_MapGeometry g) {
    final c = g.giftCentre;
    final s = g.giftSize;
    final open =
        _beat == _Beat.giftOpen || (_beat == _Beat.settling && _giftShown);
    if (open) {
      return _placed(
        Rect.fromCenter(center: c, width: s * 1.5, height: s),
        Image.asset(JourneyArt.giftOpen, fit: BoxFit.contain).animate().scaleXY(
          begin: 0.85,
          end: 1,
          duration: 250.ms,
          curve: Curves.easeOutBack,
        ),
      );
    }
    Widget gift =
        Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(JourneyArt.giftPlain, fit: BoxFit.contain),
            AnimatedOpacity(
              opacity: _giftGlow ? 1 : 0,
              duration: JourneyTiming.giftGlowIn,
              child: Image.asset(JourneyArt.giftGlow, fit: BoxFit.contain),
            ),
          ],
        ).animate().scaleXY(
          begin: 0,
          end: 1,
          duration: JourneyTiming.giftAppear,
          curve: Curves.elasticOut,
        );
    if (_beat == _Beat.giftWaiting) {
      gift = gift
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -s * 0.03, duration: 650.ms)
          .scaleXY(begin: 1, end: 1.04, duration: 650.ms);
    }
    return _placed(
      Rect.fromCenter(center: c, width: s, height: s),
      GestureDetector(
        key: const ValueKey('gift'),
        behavior: HitTestBehavior.opaque,
        onTap: _tapped,
        child: gift,
      ),
    );
  }

  ({double left, double bottom, double height, double right}) _piperSpot(
    _MapGeometry g,
  ) {
    if (_lastGame == 'loud_quiet') {
      final l = LoudQuietLayout(g.size, insets: g.padding);
      final w =
          CharacterArt.piper.frameSize.width *
          l.piperHeight /
          CharacterArt.piper.frameSize.height;
      return (
        left: l.piperLeftInset,
        bottom: g.size.height - l.piperFeetY,
        height: l.piperHeight,
        right: l.piperLeftInset + w,
      );
    }
    final l = SceneLayout(g.size, insets: g.padding, noteCount: 2);
    return (
      left: l.piperLeftInset,
      bottom: g.size.height - l.piperFeetY,
      height: l.piperHeight,
      right: l.piperRight,
    );
  }

  /// Piper and Clef strung along the path with the child — a party walking
  /// it, not a huddle on one spot (Cooper, 2026-11). They walk on with the
  /// pin. Built to the cards (the composite's Journey was illustrative).
  Widget _buildCompanion(_MapGeometry g, int stone, {required bool clef}) {
    final art = clef ? CharacterArt.clef : CharacterArt.piper;
    final feet = clef ? g.clefFeet(stone) : g.piperFeet(stone);
    final h = clef ? g.companionHeight : g.piperHeight;
    final w = art.frameSize.width * h / art.frameSize.height;
    return AnimatedPositioned(
      key: ValueKey(clef ? 'map-clef' : 'map-piper'),
      duration: JourneyTiming.pinMoves,
      curve: Curves.easeInOutCubic,
      left: feet.dx - w / 2,
      top: feet.dy - h,
      width: w,
      height: h,
      child: IgnorePointer(
        child: CharacterSprite(
          art: art,
          pose: CharacterPose.speaking,
          mouth: MouthFrame.closed,
          height: h,
        ),
      ),
    );
  }

  Widget _buildDevBar(_MapGeometry g) {
    Widget button(String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onTap,
        backgroundColor: Colors.white.withValues(alpha: 0.75),
        visualDensity: VisualDensity.compact,
      ),
    );
    return Positioned(
      left: g.padding.left + 12,
      bottom: g.padding.bottom + 8,
      child: Row(
        children: [
          button('DEV: finish stone', _devFinishStone),
          button('DEV: to milestone', _devToMilestone),
          button('DEV: reset', _devReset),
        ],
      ),
    );
  }
}

/// The map's geometry, all from the screen size and the backdrop's painted
/// path (card 200: one horizontal surface). Stones are laid ALONG THE PATH,
/// on its centre line and sized to its width there, so they shrink as it
/// recedes and the far ones take less room. The chest stands behind its
/// stone, the pin on the child's, all clear of the rail's panel.
class _MapGeometry {
  final Size size;
  final EdgeInsets padding;
  _MapGeometry(this.size, this.padding);

  /// The backdrop's painted path (one backdrop for now).
  final PathProfile path = forestPath;

  // The backdrop: tiles of the strip, its painted band filling the screen,
  // mirrored every other one.
  double get tileHeight => size.height / path.bandHeight;
  double get tileWidth => tileHeight * path.aspect;
  double get tileTop => -tileHeight * path.bandTop;

  /// The path at map x: its centre line's y and its depth on screen.
  (double y, double depth) pathAt(double x) {
    final tile = (x / tileWidth).floor();
    var u = (x - tile * tileWidth) / tileWidth;
    if (tile.isOdd) u = 1 - u;
    final (c, d) = path.at(u);
    return (tileTop + c * tileHeight, d * tileHeight);
  }

  /// A stone's cell at a point of the path: the stone's ellipse is about
  /// 45% of its cell's height, and fills ~95% of the path's depth.
  double stoneSizeAt(double x) => pathAt(x).$2 / 0.45 * 0.95;

  /// Gap between stones, as a share of a stone's cell.
  static const double step = 1.15;

  /// Far enough in that Piper fits behind the first stone.
  double get startX =>
      padding.left + math.max(size.width * 0.16, size.height * 0.34);

  final List<double> _xs = [];

  double stoneX(int i) {
    if (_xs.isEmpty) _xs.add(startX);
    while (_xs.length <= i) {
      final x = _xs.last;
      _xs.add(x + stoneSizeAt(x) * step);
    }
    return _xs[i];
  }

  double stoneSize(int i) => stoneSizeAt(stoneX(i));

  Offset stoneCentre(int i) {
    final x = stoneX(i);
    return Offset(x, pathAt(x).$1);
  }

  Rect stoneRect(int i) => Rect.fromCenter(
    center: stoneCentre(i),
    width: stoneSize(i),
    height: stoneSize(i),
  );

  /// The stride from stone [i] to the next.
  double stride(int i) => stoneX(i + 1) - stoneX(i);

  /// A margin for "is it on screen".
  double get margin => size.height * 0.1;

  /// The chest stands BEHIND its milestone stone (card 204), anchored to
  /// it: centred on the stone, its body's foot (76% down its square art)
  /// just inside the stone's back edge, so the stone's front overlaps its
  /// base. Never out in the gap between stones — there, at about a stone's
  /// size, it half-read as one of them (Cooper); behind one it is an object
  /// BESIDE the path, not a thing ON it. LIFTED (awake,
  /// waiting for the tap, opening) it rises up and out to the right, clear
  /// of the pin — which is the biggest thing on the map and would otherwise
  /// cover the very chest the child has to tap.
  Rect chestRect(int i, {bool lifted = false}) {
    final st = stoneSize(i);
    final s = st * 1.35;
    if (lifted) {
      final pin = pinRect(i);
      final centre = Offset(pin.right + s * 0.45, pin.center.dy);
      return Rect.fromCenter(center: centre, width: s * 1.15, height: s * 1.15);
    }
    // The stone's ellipse is ~45% of its cell's height, so its back edge
    // is ~0.22 of a cell above the centre.
    final foot = stoneCentre(i) + Offset(st * 0.08, -st * 0.17);
    return Rect.fromLTWH(foot.dx - s / 2, foot.dy - s * 0.76, s, s);
  }

  /// The avatar pin: the child, so the dominant figure on screen — taller
  /// than Piper and Clef — its tip on the stone.
  Rect pinRect(int i) {
    // 0.257 of the screen: the avatar the size it was drawn at before its
    // slice was tightened from an even grid cell (0.28 of a 301 px cell).
    final h = size.height * 0.257;
    final w = h * JourneyArt.pinCell.width / JourneyArt.pinCell.height;
    final tip = stoneCentre(i) - Offset(0, stoneSize(i) * 0.08);
    return Rect.fromLTWH(tip.dx - w / 2, tip.dy - h * JourneyArt.pinTip, w, h);
  }

  /// Where an earned decoration lands: beside the stone it was earned on,
  /// just below the path. PROVISIONAL — placement is open, awaiting Cooper
  /// (whether walked ground should be visibly richer is his call).
  Offset decorationSpot(Reward r) {
    final x = stoneX(r.stone) - stride(r.stone) * 0.5;
    final (y, depth) = pathAt(x);
    return Offset(x, y + depth * 0.5 + decorationSize * 0.42);
  }

  double get decorationSize => math.max(56, size.height * 0.14);

  /// A token's box: the diamond fills its square, so a little larger than
  /// a square item would be.
  double get rewardSize => math.max(64, size.height * 0.16);

  // Piper and Clef strung along the path with the child: Piper on the
  // walked path just behind, Clef just ahead but BESIDE the path (its far
  // edge), so she never seems to stand on an unplayed stone.
  double get companionHeight => size.height * 0.22;

  /// Piper, a quarter bigger than Clef on the map (Cooper, 2026-11-13).
  double get piperHeight => companionHeight * 1.25;

  Offset piperFeet(int i) {
    final x = stoneX(i) - stoneSize(i) * 0.75;
    final (y, depth) = pathAt(x);
    return Offset(x, y + depth * 0.3);
  }

  Offset clefFeet(int i) {
    // A full stride on, past the far edge: clear of the pin, and standing
    // behind the next stone rather than on it.
    final x = stoneX(i) + stride(i) * 1.05;
    final (y, depth) = pathAt(x);
    return Offset(x, y - depth * 0.6);
  }

  /// The map width not under the rail's panel.
  double get visibleWidth => size.width - RailLayout(size, padding).panelWidth;

  // Regular stone's gift, right of Piper, clear of the rail.
  double get giftSize => math.min(size.height * 0.5, visibleWidth * 0.3);
  Offset get giftCentre => Offset(visibleWidth * 0.62, size.height * 0.6);
}

class _Backdrop extends StatelessWidget {
  final double width;
  final _MapGeometry g;
  const _Backdrop({required this.width, required this.g});

  @override
  Widget build(BuildContext context) {
    final n = (width / g.tileWidth).ceil() + 1;
    return Positioned(
      left: 0,
      top: g.tileTop,
      height: g.tileHeight,
      width: n * g.tileWidth,
      child: Row(
        children: [
          for (var i = 0; i < n; i++)
            SizedBox(
              width: g.tileWidth,
              height: g.tileHeight,
              // Mirrored every other tile so the seams meet themselves.
              child: Transform.flip(
                flipX: i.isOdd,
                child: Image.asset(g.path.asset, fit: BoxFit.fill),
              ),
            ),
        ],
      ),
    );
  }
}

Path _starPath(Size size) {
  final path = Path();
  final c = size.center(Offset.zero);
  final outer = size.width / 2, inner = outer * 0.45;
  for (var i = 0; i < 8; i++) {
    final r = i.isEven ? outer : inner;
    final a = i * math.pi / 4 - math.pi / 2;
    final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

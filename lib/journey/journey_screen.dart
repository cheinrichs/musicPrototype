import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../app/config.dart';
import '../app/state/profile_state.dart';
import '../audio/audio_controller.dart';
import '../audio/sfx_type.dart';
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

  // Rewards in flight, and those landed but not yet banked.
  final List<_Flight> _flights = [];
  final List<Reward> _landed = [];
  final Set<RewardCategory> _railIncoming = {};
  final List<Reward> _decorationsLanded = [];

  /// The stone the arrow points on from, once a stone is done.
  int? _arrowFrom;

  Completer<void>? _tap;

  @override
  void initState() {
    super.initState();
    _sparkles = ConfettiController(duration: const Duration(seconds: 1));
    _journey = context.read<JourneyState>()
      ..useProfile(_profiles()?.activeProfile?.id);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openingPan());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _sparkles.dispose();
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

  void _sfx(SfxType type) {
    unawaited(AudioController.instance.playSfx(type).catchError((Object _) {}));
  }

  // ---------------------------------------------------------------------------
  // Panning
  // ---------------------------------------------------------------------------

  double _offsetFor(_MapGeometry g, int stone, {double at = 0.4}) {
    final max = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    return (g.stoneX(stone) - g.size.width * at).clamp(0.0, max);
  }

  bool _onScreen(_MapGeometry g, double x) {
    final o = _scroll.offset;
    return x > o + g.stoneWidth * 0.5 && x < o + g.visibleWidth - g.stoneWidth;
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
    setState(() {
      for (var i = 0; i < n; i++) {
        _flights.add(
          _Flight(
            rewards[i],
            from,
            fan[i],
            JourneyTiming.presentsPop,
            fromScale: 0.2,
            toScale: 1.2,
            lift: 0,
          ),
        );
      }
    });
    await _wait(JourneyTiming.presentsPop + JourneyTiming.presentsHold);
    if (!mounted) return;

    for (var i = 0; i < n; i++) {
      final r = rewards[i];
      final to = r.category.onMap
          ? g.decorationSpot(r.stone) - _scrollOffset
          : g.railSlot(_railOrderWith(r.category));
      setState(() {
        _flights.removeWhere((f) => f.reward == r);
        if (!r.category.onMap) _railIncoming.add(r.category);
        _flights.add(
          _Flight(
            r,
            fan[i],
            to,
            JourneyTiming.rewardFlight,
            fromScale: 1.2,
            toScale: 0.6,
            lift: g.rewardSize * 1.5,
            onLanded: () {
              if (!mounted) return;
              setState(() {
                _flights.removeWhere((f) => f.reward == r);
                _landed.add(r);
                if (r.category.onMap) _decorationsLanded.add(r);
              });
            },
          ),
        );
      });
      if (i < n - 1) await _wait(JourneyTiming.presentStagger);
      if (!mounted) return;
    }
    await _wait(JourneyTiming.rewardFlight + JourneyTiming.rewardHold);
  }

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
      _landed.clear();
      _railIncoming.clear();
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

  int _railOrderWith(RewardCategory c) {
    final shown = _railShown();
    final i = shown.indexOf(c);
    return i == -1 ? shown.length : i;
  }

  List<RewardCategory> _railShown() => [
    ..._journey.railCategories,
    for (final c in _railIncoming)
      if (!_journey.railCategories.contains(c)) c,
  ];

  @override
  Widget build(BuildContext context) {
    context.watch<JourneyState>();
    final g = _geometry();
    final inStone = _beat != _Beat.none;

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
          for (final f in _flights)
            _FlightView(key: ObjectKey(f), flight: f, size: g.rewardSize),
          // The rail: hidden while a game plays.
          AnimatedOpacity(
            opacity: _beat == _Beat.playing ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(child: _buildRail(g)),
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
            _Backdrop(width: width, height: g.size.height),
            Positioned.fill(
              child: CustomPaint(
                painter: _PathPainter([
                  for (var i = 0; i < count; i++) g.stoneCentre(i),
                ]),
              ),
            ),
            for (final d in [..._journey.decorations, ..._decorationsLanded])
              _placed(
                Rect.fromCenter(
                  center: g.decorationSpot(d.stone),
                  width: g.rewardSize,
                  height: g.rewardSize,
                ),
                RewardPlaceholder(
                  category: d.category,
                  size: g.rewardSize,
                ).animate().scaleXY(begin: 1.4, end: 1, duration: 400.ms),
              ),
            // The chest sits behind its stone, so it is drawn first.
            if (!_chestHidden) _buildChest(g, chestStone),
            for (var i = 0; i < count; i++) _buildStone(g, i, current),
            if (_arrowFrom != null && _arrowFrom! + 1 < count)
              _buildArrow(g, _arrowFrom!),
            _buildPin(g, current),
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
        size: g.stoneWidth,
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

  Widget _buildArrow(_MapGeometry g, int from) {
    final a = g.stoneCentre(from);
    final b = g.stoneCentre(from + 1);
    final mid = Offset.lerp(a, b, 0.5)! - Offset(0, g.stoneWidth * 0.25);
    final s = g.stoneWidth * 0.45;
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

  Widget _buildRail(_MapGeometry g) {
    final shown = _railShown();
    return Stack(
      children: [
        for (var i = 0; i < shown.length; i++)
          Positioned.fromRect(
            rect: Rect.fromCenter(
              center: g.railSlot(i),
              width: g.railIcon,
              height: g.railIcon,
            ),
            child: RailIconPlaceholder(
              key: ValueKey('rail-${shown[i].name}'),
              category: shown[i],
              count:
                  _journey.countIn(shown[i]) +
                  _landed.where((r) => r.category == shown[i]).length,
            ),
          ),
      ],
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

/// The map's geometry, all from the screen size: stones on a gentle wave
/// along one horizontal surface (card 200), the chest behind its stone, the
/// pin above the child's, the rail down the right edge.
class _MapGeometry {
  final Size size;
  final EdgeInsets padding;
  _MapGeometry(this.size, this.padding);

  double get stoneWidth => size.height * 0.27;
  double get spacing => stoneWidth * 1.75;
  double get startX => padding.left + size.width * 0.22;

  double stoneX(int i) => startX + i * spacing;
  Offset stoneCentre(int i) =>
      Offset(stoneX(i), size.height * (0.68 + 0.1 * math.sin(i * 1.15)));

  Rect stoneRect(int i) => Rect.fromCenter(
    center: stoneCentre(i),
    width: stoneWidth,
    height: stoneWidth,
  );

  /// The chest stands behind and a little right of its stone, its body's
  /// foot (76% down its square art) on the stone's back edge. Lifted, it
  /// rises by half its height.
  Rect chestRect(int i, {bool lifted = false}) {
    final s = stoneWidth * 1.15;
    final foot = stoneCentre(i) + Offset(stoneWidth * 0.3, -stoneWidth * 0.12);
    final top = foot.dy - s * 0.76 - (lifted ? s * 0.45 : 0);
    return Rect.fromLTWH(foot.dx - s / 2, top, s, s);
  }

  /// The avatar pin: its tip on the stone's top, a little left of centre.
  Rect pinRect(int i) {
    final w = stoneWidth * 0.55;
    final h = w * JourneyArt.pinCell.height / JourneyArt.pinCell.width;
    final tip = stoneCentre(i) + Offset(-stoneWidth * 0.12, -stoneWidth * 0.08);
    return Rect.fromLTWH(tip.dx - w / 2, tip.dy - h * 0.9, w, h);
  }

  Offset decorationSpot(int stone) =>
      stoneCentre(stone) + Offset(-spacing * 0.45, stoneWidth * 0.42);

  double get rewardSize => math.max(56, size.height * 0.13);

  // Regular stone's gift, right of Piper.
  double get giftSize => math.min(size.height * 0.5, size.width * 0.3);
  Offset get giftCentre => Offset(size.width * 0.62, size.height * 0.6);

  // The rail: icons down the right edge, on the scene (no dark panel).
  double get railIcon => math.max(52, size.height * 0.12);
  double get railRight => size.width - padding.right - 12;
  Offset railSlot(int i) => Offset(
    railRight - railIcon / 2,
    padding.top + 16 + railIcon / 2 + i * (railIcon + 10),
  );

  /// The map width not under the rail.
  double get visibleWidth => size.width - railIcon - 24;
}

/// A reward on its way somewhere.
class _Flight {
  final Reward reward;
  final Offset from;
  final Offset to;
  final Duration duration;
  final double fromScale;
  final double toScale;
  final double lift;
  final VoidCallback? onLanded;
  _Flight(
    this.reward,
    this.from,
    this.to,
    this.duration, {
    required this.fromScale,
    required this.toScale,
    required this.lift,
    this.onLanded,
  });
}

class _FlightView extends StatelessWidget {
  final _Flight flight;
  final double size;
  const _FlightView({super.key, required this.flight, required this.size});

  @override
  Widget build(BuildContext context) {
    final f = flight;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: f.duration,
      curve: Curves.easeInOutCubic,
      onEnd: f.onLanded,
      builder: (context, t, child) {
        // A lifted arc: a quadratic through a point above the midpoint.
        final control = Offset.lerp(f.from, f.to, 0.5)! - Offset(0, f.lift);
        final p =
            f.from * ((1 - t) * (1 - t)) +
            control * (2 * (1 - t) * t) +
            f.to * (t * t);
        final s = f.fromScale + (f.toScale - f.fromScale) * t;
        return Positioned(
          left: p.dx - size / 2,
          top: p.dy - size / 2,
          width: size,
          height: size,
          child: IgnorePointer(
            child: Transform.scale(scale: s, child: child),
          ),
        );
      },
      child: RewardPlaceholder(category: f.reward.category, size: size),
    );
  }
}

class _Backdrop extends StatelessWidget {
  final double width;
  final double height;
  const _Backdrop({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    // The strip's painted band runs from about 24% to 78% of its height,
    // with white paper above and below: scale the band to fill the screen.
    final tileHeight = height / 0.54;
    final tile = tileHeight * 1.5;
    final n = (width / tile).ceil() + 1;
    return Positioned(
      left: 0,
      top: -tileHeight * 0.24,
      height: tileHeight,
      width: n * tile,
      child: Row(
        children: [
          for (var i = 0; i < n; i++)
            SizedBox(
              width: tile,
              height: tileHeight,
              // Mirrored every other tile so the seams meet themselves.
              child: Transform.flip(
                flipX: i.isOdd,
                child: Image.asset(
                  'assets/images/backgrounds/learning_paths/Forest.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// PLACEHOLDER for the painted path: a dashed trail stone to stone.
class _PathPainter extends CustomPainter {
  final List<Offset> points;
  _PathPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xCCF3E3C0)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i], b = points[i + 1];
      const dashes = 9;
      for (var d = 1; d < dashes; d += 2) {
        canvas.drawLine(
          Offset.lerp(a, b, d / dashes)!,
          Offset.lerp(a, b, (d + 0.6) / dashes)!,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.points != points;
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

import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/config.dart';
import '../app/rail_shell.dart';
import '../app/router.dart';
import '../app/state/profile_state.dart';
import '../audio/audio_controller.dart';
import '../audio/sfx_type.dart';
import '../audio/sound_registry.dart';
import '../games/game_catalogue.dart';
import '../games/game_session.dart';
import '../games/high_low/models/high_low_instrument.dart';
import '../games/high_low/models/round_instrumentation.dart';
import '../games/high_low/models/scene_layout.dart';
import '../games/high_low/widgets/character_art.dart';
import '../games/high_low/widgets/mouth_frames.dart';
import '../games/loud_quiet/models/loud_quiet_layout.dart';
import '../models/agency_stage.dart';
import '../ui/components/circle_icon_button.dart';
import 'journey_art.dart';
import 'journey_state.dart';
import 'journey_travel.dart';
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

  /// Moving on a stone (Trello 227): Piper walks, Clef hops, the pin
  /// arcs — all three together. Slower than an in-game move: the child is
  /// watching, not playing.
  static const pinMoves = Duration(milliseconds: 1100);
  static const newChestPan = Duration(milliseconds: 1000);
  static const newChestDrop = Duration(milliseconds: 700);
  static const newChestHold = Duration(milliseconds: 900);

  // The chest EVENT (Cooper, 2026-11-21: "much bigger like almost fill
  // the screen big and it could wiggle and make a twinkle sound in
  // addition to sparkling"). It comes forward from its stone, growing to
  // nearly fill the screen, then wiggles, sparkles and twinkles now and
  // then until tapped — never a voice line telling the child what to do.
  static const chestComeForward = Duration(milliseconds: 1100);
  static const chestInviteEvery = Duration(seconds: 5);
  static const chestWiggle = Duration(milliseconds: 750);
  static const chestClear = Duration(milliseconds: 400);

  // The next chest's intermittent glow while the child is on the map
  // (wayfinding): a brief warm glow, then quiet — "a few seconds between
  // bursts", never a constant shimmer. Paused whenever anything else moves.
  static const chestGlowCycle = Duration(milliseconds: 4800);
  static const chestGlowOn = Duration(milliseconds: 1400);
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

  /// Counts the waiting chest's invitations; each one replays its bigger
  /// hop. [_chestInvite] fires them while the chest waits untapped.
  int _chestNudges = 0;
  Timer? _chestInvite;

  /// The claimed chest shrinking away before anyone travels.
  bool _chestClearing = false;

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
    // Normally already this child's (the picker switched it); if not, switch
    // quietly — this is mid-build.
    _journey = context.read<JourneyState>()
      ..useProfile(_profiles()?.activeProfile?.id, notify: false);
    try {
      _rail = context.read<RailController>();
    } on ProviderNotFoundException {
      _rail = _ownRail = RailController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Decode the movement sheets now, so the first step never flashes.
      for (final g in [Gait.piperWalk, Gait.clefHop]) {
        unawaited(precacheImage(AssetImage(g.asset), context));
      }
      _openingPan();
    });
  }

  @override
  void dispose() {
    _chestInvite?.cancel();
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

  JourneyMapGeometry _geometry() => JourneyMapGeometry(
    MediaQuery.sizeOf(context),
    MediaQuery.paddingOf(context),
  );

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

  double _offsetFor(JourneyMapGeometry g, int stone, {double at = 0.4}) {
    final max = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    return (g.stoneX(stone) - g.visibleWidth * at).clamp(0.0, max);
  }

  bool _onScreen(JourneyMapGeometry g, double x) {
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
    if (!mounted) return;
    setState(() => _panning = false);
    // Left before tapping the chest: it is still there, still theirs.
    if (_journey.chestPending) await _resumeChest();
  }

  /// The child finished the stone before a chest and left before tapping
  /// it (the claim is saved, see [JourneyState.chestPending]): straight
  /// back to the hopping chest, then on as if they had never left.
  Future<void> _resumeChest() async {
    final stone = _journey.current;
    final rewards = _journey.rewardsForCurrent();
    setState(() {
      _chestAt = stone + 1;
      _beat = _Beat.chestWaking;
    });
    await _claimChest(stone, rewards);
    if (!mounted) return;
    await _settle(stone, rewards, milestone: true);
  }

  // ---------------------------------------------------------------------------
  // Playing a stone
  // ---------------------------------------------------------------------------

  void _startStone() {
    if (_beat != _Beat.none || _panning || _journey.chestPending) return;
    // A reward stone is never played: tapping it moves everyone on, and
    // the next stone's games start as they arrive.
    if (JourneyState.isRewardStone(_journey.current)) {
      unawaited(_passRewardStone());
      return;
    }
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

  Future<void> _passRewardStone() async {
    _sfx(SfxType.tap);
    setState(() {
      _arrowFrom = null;
      _beat = _Beat.settling;
    });
    _journey.passRewardStone();
    await _wait(JourneyTiming.pinMoves + JourneyTiming.arriveOnMap);
    if (!mounted) return;
    setState(() => _beat = _Beat.none);
    _startStone();
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
    // The stone before a chest: its claim is saved NOW, so leaving at any
    // point of the celebration still finds the chest waiting.
    if (JourneyState.isMilestone(_journey.current)) _journey.awaitChest();
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

  /// Milestone (Cooper, 2026-11-21): the child has finished the stone
  /// BEFORE a chest stone. Back on the map, the chest on the next stone
  /// hops up (the existing wake: plain → glow, lifting in sparkles); the
  /// child taps it; the presents fly to their places. Only after that does
  /// anyone travel ([_settle]), so the chest is claimed and gone before the
  /// avatar steps onto its stone — nothing moves into an occupied spot.
  Future<void> _milestone(int stone, List<Reward> rewards) async {
    final g = _geometry();
    // Saved first: leaving from here on keeps the chest theirs.
    if (!_journey.chestPending) _journey.awaitChest();
    setState(() {
      _chestAt = stone + 1;
      _gameVisible = false;
      _beat = _Beat.chestWaking;
    });
    _scroll.jumpTo(_offsetFor(g, stone, at: 0.4));
    await _wait(JourneyTiming.backToMap);
    if (!mounted) return;
    setState(() => _layerUp = false);
    await _wait(JourneyTiming.arriveOnMap);
    if (!mounted) return;
    await _claimChest(stone, rewards);
  }

  /// The chest EVENT: the chest on stone+1 wakes (plain → glow) and comes
  /// forward, growing to nearly fill the screen; it wiggles, sparkles and
  /// twinkles until tapped, the gesture escalating gently if ignored and
  /// the twinkle fading away; it opens, its presents fly, and it clears.
  Future<void> _claimChest(int stone, List<Reward> rewards) async {
    final g = _geometry();
    setState(() => _chestAwake = true);
    _sparkles.play();
    await _wait(JourneyTiming.chestComeForward);
    if (!mounted) return;
    setState(() {
      _beat = _Beat.chestWaiting;
      _chestNudges = 1; // a first wiggle on arrival
    });
    _twinkle(0);
    _chestInvite = Timer.periodic(JourneyTiming.chestInviteEvery, (_) {
      if (!mounted || _beat != _Beat.chestWaiting) return;
      setState(() => _chestNudges++);
      _sparkles.play();
      _twinkle(_chestNudges - 1);
    });
    await _waitForTap();
    _chestInvite?.cancel();
    _chestInvite = null;
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
    final r = g.chestEventRect(_scrollOffset.dx).shift(-_scrollOffset);
    final chest = Offset(r.center.dx, r.top + r.height * OpenChestArt.mouth);
    await _presentsOut(chest, rewards, g);
    if (!mounted) return;
    // Cleared before anyone travels: nothing moves into an occupied spot.
    setState(() => _chestClearing = true);
    await _wait(JourneyTiming.chestClear);
  }

  /// The chest's twinkle: three real handbell notes (InspectorJ, already
  /// in the app; nothing synthesised), high and quick, ringing over one
  /// another. Sounded on arrival and then only on some invitations, ever
  /// quieter — the 2nd, 4th, 7th and 11th, then never again — so a parent
  /// does not hear it on a loop. Never over a voice line.
  void _twinkle(int invitation) {
    const volumes = {0: 0.55, 2: 0.4, 4: 0.3, 7: 0.22, 11: 0.16};
    final volume = volumes[invitation];
    if (volume == null) return;
    final audio = AudioController.instance;
    if (audio.isClipPlaying) return;
    final bells = HighLowInstrument.bells.availableMidis;
    final notes = [
      for (final m in [96, 91, 88]) _nearest(bells, m),
    ];
    for (var i = 0; i < notes.length; i++) {
      Future.delayed(Duration(milliseconds: 95 * i), () {
        if (!mounted || audio.isClipPlaying) return;
        unawaited(
          audio
              .playChime(
                HighLowInstrument.bells.assetPathForMidi(notes[i]),
                volume: volume * (1 - 0.18 * i),
              )
              .catchError((Object _) {}),
        );
      });
    }
  }

  static int _nearest(List<int> midis, int target) =>
      midis.reduce((a, b) => (a - target).abs() <= (b - target).abs() ? a : b);

  Offset get _scrollOffset =>
      Offset(_scroll.hasClients ? _scroll.offset : 0, 0);

  /// Each reward pops out of [from] into a fan, holds, then flies: to its
  /// rail category, or (a decoration) onto the map by the stone.
  Future<void> _presentsOut(
    Offset from,
    List<Reward> rewards,
    JourneyMapGeometry g,
  ) async {
    final n = rewards.length;
    // Kept clear of the top edge at its popped (1.2×) size: on a phone the
    // chest event is high enough to push the fan off screen.
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

  Widget _rewardItem(Reward r, JourneyMapGeometry g) =>
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
      _chestNudges = 0;
      _chestClearing = false;
    });
    // After a chest, the pan to the next chest waits for all three to
    // arrive on its stone, so the arrival is never panned off screen.
    await _wait(
      milestone
          ? JourneyTiming.pinMoves + JourneyTiming.arriveOnMap
          : JourneyTiming.stoneTurns,
    );
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
          // Back to the player picker, UNGATED (Cooper, 2026-11-15):
          // switching children is the commonest adult action, and a stray
          // round in the wrong profile is annoying, not serious.
          if (!inStone)
            Positioned(
              left: g.padding.left + 12,
              top: g.padding.top + 12,
              child: CircleIconButton(
                key: const ValueKey('journey-back'),
                icon: Icons.arrow_back_rounded,
                tooltip: 'Players',
                onTap: () => GoRouter.of(context).go(AppRoutes.profilePicker),
              ),
            ),
          // The dev profile only, on an internal build (Cooper, 2026-11-21:
          // they showed on a child's journey, where "reset" would wipe her
          // progress and "finish stone" would skip play and corrupt the
          // data promotion reads). The same gate as the games' dev setup;
          // without a ProfileState (widget tests only) the build flag.
          if ((_profiles()?.canUseDevTools ?? devToolsEnabled) &&
              !inStone &&
              !_panning)
            _buildDevBar(g),
        ],
      ),
    );
  }

  Widget _buildMap(JourneyMapGeometry g) {
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
            // Clef stands beyond the path's far edge, drawn before the
            // stones. The chest sits ON its stone, so after them — and
            // over everything once it wakes and lifts off.
            _buildCompanion(g, current, clef: true),
            for (var i = 0; i < count; i++) _buildStone(g, i, current),
            if (!_chestHidden && !_chestAwake) _buildChest(g, chestStone),
            if (_arrowFrom != null && _arrowFrom! + 2 < count)
              _buildArrow(g, _arrowFrom!),
            _buildCompanion(g, current, clef: false),
            _buildPin(g, current),
            if (!_chestHidden && _chestAwake) _buildChestScrim(g),
            if (!_chestHidden && _chestAwake) _buildChest(g, chestStone),
          ],
        ),
      ),
    );
  }

  Widget _placed(Rect r, Widget child) =>
      Positioned.fromRect(rect: r, child: child);

  Widget _buildStone(JourneyMapGeometry g, int i, int current) {
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

  Widget _buildPin(JourneyMapGeometry g, int stone) => Traveller(
    key: const ValueKey('map-pin'),
    rect: g.pinRect(stone),
    duration: JourneyTiming.pinMoves,
    // The pin has no legs, so the arc carries its motion. Cooper: "a
    // little arc", so a modest one.
    arc: 0.15,
    rest: GestureDetector(
      onTap: _startStone,
      // The avatar THIS child chose at setup (card 202).
      child: AvatarPin(index: _profiles()?.activeProfile?.avatarIndex ?? 0),
    ),
  );

  Widget _buildChest(JourneyMapGeometry g, int stone) {
    final event = _chestAwake;
    final r = event ? g.chestEventRect(_scrollOffset.dx) : g.chestRect(stone);
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
            numberOfParticles: event ? 40 : 24,
            gravity: 0.15,
            maxBlastForce: event ? 30 : 14,
            minBlastForce: event ? 8 : 4,
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
      // A slow breath between wiggles.
      chest = chest
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.02, duration: 900.ms);
      // The wiggle: rotation and squash on the glow frame, no new art. On
      // arrival and at every invitation; after three ignored, it hops too.
      if (_chestNudges > 0) {
        final hop = _chestNudges > 3;
        chest = KeyedSubtree(
          key: ValueKey('chest-invite-$_chestNudges'),
          child: chest.animate().custom(
            duration: JourneyTiming.chestWiggle,
            builder: (context, t, child) {
              final fade = 1 - t;
              final angle = math.sin(t * math.pi * 6) * 0.07 * fade;
              final squash = math.sin(t * math.pi * 4) * 0.05 * fade;
              final lift = hop ? -math.sin(t * math.pi) * r.height * 0.1 : 0;
              return Transform.translate(
                offset: Offset(0, lift.toDouble()),
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(1 + squash, 1 - squash, 1)
                    ..rotateZ(angle),
                  child: child,
                ),
              );
            },
          ),
        );
      }
    }
    if (_chestClearing) {
      chest = chest
          .animate()
          .fadeOut(duration: JourneyTiming.chestClear)
          .scaleXY(begin: 1, end: 0.6, duration: JourneyTiming.chestClear);
    }
    // Wayfinding: the next unclaimed chest glows now and then while the
    // child is on the map — quieter than the pin, and only while nothing
    // else moves (the pin itself is still at rest).
    if (!_chestAwake && !_chestDropping && _beat == _Beat.none && !_panning) {
      chest = Stack(
        fit: StackFit.expand,
        children: [
          chest,
          IgnorePointer(
            child: Image.asset(JourneyArt.chestGlow, fit: BoxFit.contain)
                .animate(onPlay: (c) => c.repeat())
                .custom(
                  duration: JourneyTiming.chestGlowCycle,
                  builder: (context, t, child) {
                    final on =
                        JourneyTiming.chestGlowOn.inMilliseconds /
                        JourneyTiming.chestGlowCycle.inMilliseconds;
                    final v = t < on ? math.sin(math.pi * t / on) : 0.0;
                    return Opacity(opacity: 0.6 * v, child: child);
                  },
                ),
          ),
        ],
      );
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
    // Coming forward: from its stone to nearly the whole screen, overshooting
    // a little as it lands — the hop and the growth in one move.
    return AnimatedPositioned(
      key: const ValueKey('chest'),
      duration: JourneyTiming.chestComeForward,
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

  /// Dims the map behind the chest event, so the chest reads as come
  /// forward, out of the landscape.
  Widget _buildChestScrim(JourneyMapGeometry g) {
    final x = _scrollOffset.dx;
    return Positioned(
      left: x,
      top: 0,
      width: g.size.width,
      height: g.size.height,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _chestClearing ? 0 : 1,
          duration: JourneyTiming.chestClear,
          child: const ColoredBox(
            color: Color(0x66000000),
          ).animate().fadeIn(duration: JourneyTiming.chestComeForward),
        ),
      ),
    );
  }

  /// Onward: from the child's new stone toward the one after it — the
  /// walked side behind is where Piper and Clef stand.
  Widget _buildArrow(JourneyMapGeometry g, int from) {
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

  Widget _buildStoneLayer(JourneyMapGeometry g) {
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

  Widget _buildGift(JourneyMapGeometry g) {
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
    JourneyMapGeometry g,
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
  Widget _buildCompanion(
    JourneyMapGeometry g,
    int stone, {
    required bool clef,
  }) {
    final art = clef ? CharacterArt.clef : CharacterArt.piper;
    final feet = clef ? g.clefFeet(stone) : g.piperFeet(stone);
    final h = clef ? g.clefHeightAt(feet.dx) : g.piperHeightAt(feet.dx);
    final w = art.frameSize.width * h / art.frameSize.height;
    // The travelling body, matched to the resting one: Piper's body is her
    // frame; Clef's is her talking body (12% grown), and her hop frames
    // are head-matched to it (hop at 0.73H, talking at 0.63H).
    final body = clef
        ? h * CharacterArt.clefGrowth * 719 / 723 * 0.73 / 0.63
        : h;
    return Traveller(
      key: ValueKey(clef ? 'map-clef' : 'map-piper'),
      rect: Rect.fromLTWH(feet.dx - w / 2, feet.dy - h, w, h),
      duration: JourneyTiming.pinMoves,
      gait: clef ? Gait.clefHop : Gait.piperWalk,
      bodyHeight: body,
      rest: IgnorePointer(
        child: CharacterSprite(
          art: art,
          pose: CharacterPose.speaking,
          mouth: MouthFrame.closed,
          height: h,
        ),
      ),
    );
  }

  Widget _buildDevBar(JourneyMapGeometry g) {
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
class JourneyMapGeometry {
  final Size size;
  final EdgeInsets padding;
  JourneyMapGeometry(this.size, this.padding);

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

  /// Far enough in that Piper — at her depth-scaled size, clear of the
  /// pin — fits on screen behind the first stone.
  double get startX {
    final least = padding.left + size.width * 0.16;
    var x = least;
    for (var pass = 0; pass < 4; pass++) {
      final piperX = x - pinWidth * (0.5 + _piperGap);
      final w = _widthFor(CharacterArt.piper, piperHeightAt(piperX));
      x = math.max(
        least,
        padding.left + size.height * 0.02 + w + pinWidth * (0.5 + _piperGap),
      );
    }
    return x;
  }

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
  /// The chest EVENT's rect in map coordinates, for a map scrolled to
  /// [scrollX]: nearly the whole visible height (a square chest in
  /// landscape is capped by height), centred in the map's visible width.
  Rect chestEventRect(double scrollX) {
    final s = math.min(size.height * 0.92, visibleWidth * 0.9);
    final centre = Offset(scrollX + visibleWidth / 2, size.height * 0.5);
    return Rect.fromCenter(center: centre, width: s, height: s);
  }

  /// The chest ON stone [i] (Cooper, 2026-11-21: "the treasure chest
  /// should sit on the stone"): its base on the stone's top, a little wider
  /// than the stone. Scenery; the claim is [chestEventRect].
  Rect chestRect(int i) {
    final st = stoneSize(i);
    final s = st * 1.05;
    // The stone's ellipse is ~45% of its cell's height; its top surface is
    // about a tenth of a cell above the centre.
    final foot = stoneCentre(i) + Offset(0, -st * 0.04);
    return Rect.fromLTWH(foot.dx - s / 2, foot.dy - s * 0.82, s, s);
  }

  // 0.257 of the screen: the avatar the size it was drawn at before its
  // slice was tightened from an even grid cell (0.28 of a 301 px cell).
  double get pinHeight => size.height * 0.257;
  double get pinWidth =>
      pinHeight * JourneyArt.pinCell.width / JourneyArt.pinCell.height;

  /// The avatar pin: the child, its tip on the stone.
  Rect pinRect(int i) {
    final h = pinHeight;
    final w = pinWidth;
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

  // Piper and Clef walk the path WITH the child: Piper close behind the
  // pin, Clef a scout further ahead, beside the path's far edge so he never
  // seems to stand on an unplayed stone. Direction and travel — never a
  // trio posed either side of the hero.
  //
  // They obey the path's DEPTH exactly as the stones do (stoneSizeAt): a
  // figure's height is its nominal height scaled by the path's depth where
  // it stands, relative to the path's mean depth. So Clef, further along
  // where the path narrows away, draws smaller than Piper — figures
  // standing IN the painting, not cutouts laid on it.
  double get companionHeight => size.height * 0.22;

  /// Piper's nominal height: half as big again as the quarter-bigger she
  /// was (Cooper, 2026-11-13, then 2026-11-14).
  double get piperHeight => companionHeight * 1.25 * 1.5;

  /// The path's depth at [x] relative to its mean — the stones' scaling.
  double depthScaleAt(double x) => pathAt(x).$2 / (path.meanDepth * tileHeight);

  double piperHeightAt(double x) => piperHeight * depthScaleAt(x);
  double clefHeightAt(double x) => companionHeight * depthScaleAt(x);

  static double _widthFor(CharacterArt art, double h) =>
      art.frameSize.width * h / art.frameSize.height;

  /// Clear space between Piper and the pin, as a share of the pin's width.
  static const double _piperGap = 0.04;

  /// Piper's feet: her frame's right edge just clear of the pin's left
  /// edge — never under it — on the near side of the walked path. Her size
  /// depends on where she stands, so this settles it in a few passes.
  Offset piperFeet(int i) {
    final pin = pinRect(i);
    var x = pin.left - pin.width * _piperGap;
    for (var pass = 0; pass < 4; pass++) {
      final w = _widthFor(CharacterArt.piper, piperHeightAt(x));
      x = pin.left - pin.width * _piperGap - w / 2;
    }
    final (y, depth) = pathAt(x);
    return Offset(x, y + depth * 0.3);
  }

  /// Clef's feet (Cooper, 2026-11-21: "Clef should [not] line up directly
  /// behind a stone, it feels like she's then associated with that stone").
  ///
  /// THE RULE, in map coordinates so it holds at every scroll position (the
  /// whole map pans together; nothing here reads the screen):
  /// - **x: in a GAP, never at a stone.** Midway between stones i+2 and
  ///   i+3, well ahead of the pin. If the resting chest is there, the next
  ///   gap on. A gap is a gap at any scroll, so she can never drift over a
  ///   stone.
  /// - **y: off the path, in the verge beyond its far edge**, as Piper
  ///   stands in the grass on the near side. Her feet sit [_clefVerge] of
  ///   the path's depth beyond the far edge, so she reads as a bystander,
  ///   not a second avatar on the walkway.
  Offset clefFeet(int i) {
    double gap(int k) => (stoneX(k) + stoneX(k + 1)) / 2;
    final chest = chestRect(JourneyState.nextChestFrom(i + 1));
    double half(double at) =>
        _widthFor(CharacterArt.clef, clefHeightAt(at)) / 2;
    var k = i + 2;
    var x = gap(k);
    while (x + half(x) > chest.left && x - half(x) < chest.right) {
      x = gap(++k);
    }
    final (y, depth) = pathAt(x);
    return Offset(x, y - depth * (0.5 + _clefVerge));
  }

  /// How far beyond the path's far edge Clef's feet stand, as a share of
  /// the path's depth: clearly in the grass.
  static const double _clefVerge = 0.35;

  /// The map width not under the rail's panel.
  double get visibleWidth => size.width - RailLayout(size, padding).panelWidth;

  // Regular stone's gift, right of Piper, clear of the rail.
  double get giftSize => math.min(size.height * 0.5, visibleWidth * 0.3);
  Offset get giftCentre => Offset(visibleWidth * 0.62, size.height * 0.6);
}

class _Backdrop extends StatelessWidget {
  final double width;
  final JourneyMapGeometry g;
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

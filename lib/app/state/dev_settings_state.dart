import 'package:flutter/foundation.dart';
import '../../models/agency_stage.dart';
import '../../models/concept_tier.dart';
import '../../models/round_order.dart';
import '../../models/round_set_length.dart';

/// Developer-only overrides for the generic Agency/Concept-Tier/Round-Order
/// knobs (Trello card 92). Any activity screen can read this to let a dev
/// pick a stage/tier/ordering before a session starts — see
/// `DevSetupOverlay`, the generic UI for it.
///
/// This is registered in the app's provider tree unconditionally (it's a
/// cheap, inert ChangeNotifier), but nothing ever *shows* the UI to change
/// it outside `devToolsEnabled` (see `app/config.dart` — true for
/// TestFlight/debug, false for a public App Store build) — see
/// `DevSetupOverlay` — so a public build has no path to reach anything
/// other than these defaults, which are chosen to match the production
/// experience.
class DevSettingsState extends ChangeNotifier {
  AgencyStage _agencyStage = AgencyStage.decide;
  ConceptTier _conceptTier = ConceptTier.t1;
  RoundOrder _roundOrder = RoundOrder.blocked;

  /// Whether the dev gate should hand off to the A4 ordering screen instead
  /// of the normal pairwise game. Orthogonal to [agencyStage] since
  /// 2026-09-27 (Trello card 168, "Agency is capability, not difficulty"):
  /// ordering is a separate *skill* built on drag capability, not a further
  /// agency stage, so it can no longer be selected by picking a fourth
  /// [AgencyStage] value the way `AgencyStage.order` once was. This is a
  /// dev-tool convenience standing in for a real skill-selection UI that
  /// doesn't exist yet — production would only ever offer ordering once a
  /// child already has drag capability, but this toggle doesn't enforce
  /// that itself.
  bool _orderingSelected = false;

  /// Whether Observe's earned arrow sends the instruments flying to the tree
  /// (Trello card 173) instead of advancing at once. Off by default, so a
  /// child's game is unchanged until Cooper has seen the flight on a device;
  /// this is how he sees it.
  bool _observeFlight = false;

  /// How many rounds a set runs at each agency stage (Trello card 196). The
  /// one shared setting every game reads — not a dev override of something
  /// else: a public build reads [RoundSetLength.standard] from here too,
  /// since nothing there can change it.
  RoundSetLength _roundSetLength = RoundSetLength.standard;

  AgencyStage get agencyStage => _agencyStage;
  RoundSetLength get roundSetLength => _roundSetLength;
  ConceptTier get conceptTier => _conceptTier;
  RoundOrder get roundOrder => _roundOrder;
  bool get orderingSelected => _orderingSelected;
  bool get observeFlight => _observeFlight;

  /// Lowering agency brings the tier down with it: the product cannot
  /// reach a tier its agency stage hasn't earned (see
  /// [ConceptTier.isReachableAt]), so the gate must not let a developer
  /// build one either. Raising agency again does not restore it.
  void setAgencyStage(AgencyStage stage) {
    _agencyStage = stage;
    _conceptTier = _conceptTier.clampedTo(stage);
    notifyListeners();
  }

  /// Ignored if [tier] is unreachable at the current agency stage.
  void setConceptTier(ConceptTier tier) {
    if (!tier.isReachableAt(_agencyStage)) return;
    _conceptTier = tier;
    notifyListeners();
  }

  void setRoundOrder(RoundOrder order) {
    _roundOrder = order;
    notifyListeners();
  }

  void setOrderingSelected(bool selected) {
    _orderingSelected = selected;
    notifyListeners();
  }

  void setObserveFlight(bool on) {
    _observeFlight = on;
    notifyListeners();
  }

  /// Sets the round count for [stage] only; the others keep theirs.
  void setRoundSetLength(AgencyStage stage, int rounds) {
    _roundSetLength = _roundSetLength.withLength(stage, rounds);
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import '../../models/agency_stage.dart';
import '../../models/concept_tier.dart';
import '../../models/round_order.dart';

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
  AgencyStage _agencyStage = AgencyStage.drag;
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

  AgencyStage get agencyStage => _agencyStage;
  ConceptTier get conceptTier => _conceptTier;
  RoundOrder get roundOrder => _roundOrder;
  bool get orderingSelected => _orderingSelected;

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
}

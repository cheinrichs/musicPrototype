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
/// it outside `kDevMode` (`--dart-define=DEV_MODE=true`) — see
/// `DevSetupOverlay` — so a shipping build has no path to reach anything
/// other than these defaults, which are chosen to match the production
/// experience.
class DevSettingsState extends ChangeNotifier {
  AgencyStage _agencyStage = AgencyStage.trigger;
  ConceptTier _conceptTier = ConceptTier.t1;
  RoundOrder _roundOrder = RoundOrder.blocked;

  AgencyStage get agencyStage => _agencyStage;
  ConceptTier get conceptTier => _conceptTier;
  RoundOrder get roundOrder => _roundOrder;

  void setAgencyStage(AgencyStage stage) {
    _agencyStage = stage;
    notifyListeners();
  }

  void setConceptTier(ConceptTier tier) {
    _conceptTier = tier;
    notifyListeners();
  }

  void setRoundOrder(RoundOrder order) {
    _roundOrder = order;
    notifyListeners();
  }
}

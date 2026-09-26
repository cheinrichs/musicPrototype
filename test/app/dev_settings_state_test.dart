import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/app/state/dev_settings_state.dart';
import 'package:ear_trainer/models/agency_stage.dart';
import 'package:ear_trainer/models/concept_tier.dart';

void main() {
  group('DevSettingsState keeps the tier reachable at the agency stage', () {
    test('lowering agency brings an unreachable tier down with it', () {
      final settings = DevSettingsState()..setConceptTier(ConceptTier.t8);
      expect(settings.conceptTier, ConceptTier.t8);

      settings.setAgencyStage(AgencyStage.participate);
      expect(settings.conceptTier, ConceptTier.t4);

      settings.setAgencyStage(AgencyStage.observe);
      expect(settings.conceptTier, ConceptTier.t1);
    });

    test('an unreachable tier cannot be chosen at a low agency stage', () {
      final settings = DevSettingsState()
        ..setAgencyStage(AgencyStage.participate)
        ..setConceptTier(ConceptTier.t5);
      expect(settings.conceptTier, ConceptTier.t1, reason: 'unchanged');

      settings.setConceptTier(ConceptTier.t4);
      expect(settings.conceptTier, ConceptTier.t4);
    });

    test('raising agency again does not restore a tier that was clamped', () {
      final settings = DevSettingsState()
        ..setConceptTier(ConceptTier.t8)
        ..setAgencyStage(AgencyStage.observe)
        ..setAgencyStage(AgencyStage.trigger);
      expect(settings.conceptTier, ConceptTier.t1);
    });
  });
}

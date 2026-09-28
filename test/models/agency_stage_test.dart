import 'package:flutter_test/flutter_test.dart';
import 'package:ear_trainer/models/agency_stage.dart';

void main() {
  group('AgencyStage (Trello card 168, "Agency is capability, not '
      'difficulty")', () {
    test('is exactly three ordered capability levels — observe, explore, '
        'drag — never a fourth. Ordering used to be a fourth value here '
        '(`order`); it is a separate skill now, not an agency level, and '
        'must not come back as one', () {
      expect(AgencyStage.values, [
        AgencyStage.observe,
        AgencyStage.explore,
        AgencyStage.drag,
      ]);
    });

    test('codes match the curriculum sheet\'s own A0/A1/A2 naming, '
        'unaffected by this enum\'s own names', () {
      expect(AgencyStage.observe.code, 'A0');
      expect(AgencyStage.explore.code, 'A1');
      expect(AgencyStage.drag.code, 'A2');
    });

    test('labels are the new, renamed-from-Participate/Trigger names, for '
        'the dev picker', () {
      expect(AgencyStage.observe.label, 'Observe');
      expect(AgencyStage.explore.label, 'Explore');
      expect(AgencyStage.drag.label, 'Drag');
    });
  });
}

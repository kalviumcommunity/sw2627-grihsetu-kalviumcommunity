import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/screens/complaints/complaint_draft.dart';
import 'package:grihsetu/utils/visit_validators.dart';

void main() {
  group('VisitValidators - Step Order Transitions', () {
    test('allowed transitions proceed one step at a time', () {
      expect(
        VisitValidators.validateStepTransition(
          null,
          VisitWorkflowStep.accepted,
        ),
        isNull,
      );
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.accepted,
          VisitWorkflowStep.travelling,
        ),
        isNull,
      );
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.travelling,
          VisitWorkflowStep.arrived,
        ),
        isNull,
      );
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.arrived,
          VisitWorkflowStep.inspection,
        ),
        isNull,
      );
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.inspection,
          VisitWorkflowStep.repairing,
        ),
        isNull,
      );
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.repairing,
          VisitWorkflowStep.completed,
        ),
        isNull,
      );
    });

    test('cannot start a step out of order', () {
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.accepted,
          VisitWorkflowStep.arrived,
        ),
        'You cannot start a step out of order.',
      );
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.accepted,
          VisitWorkflowStep.inspection,
        ),
        'You cannot start a step out of order.',
      );
      expect(
        VisitValidators.validateStepTransition(
          null,
          VisitWorkflowStep.travelling,
        ),
        'You must accept the job first.',
      );
    });

    test('going backwards is not allowed', () {
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.arrived,
          VisitWorkflowStep.travelling,
        ),
        'Going backwards in visit workflow is not allowed.',
      );
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.repairing,
          VisitWorkflowStep.accepted,
        ),
        'Going backwards in visit workflow is not allowed.',
      );
    });

    test('cannot complete visit before "Start repair"', () {
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.accepted,
          VisitWorkflowStep.completed,
        ),
        'You cannot complete a visit before "Start repair".',
      );
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.travelling,
          VisitWorkflowStep.completed,
        ),
        'You cannot complete a visit before "Start repair".',
      );
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.arrived,
          VisitWorkflowStep.completed,
        ),
        'You cannot complete a visit before "Start repair".',
      );
      expect(
        VisitValidators.validateStepTransition(
          VisitWorkflowStep.inspection,
          VisitWorkflowStep.completed,
        ),
        'You cannot complete a visit before "Start repair".',
      );
    });
  });

  group('VisitValidators - Parts Validation', () {
    test('part name boundaries (2 to 60 characters)', () {
      expect(VisitValidators.validatePartName(''), isNotNull);
      expect(VisitValidators.validatePartName('A'), isNotNull);
      expect(VisitValidators.validatePartName('AB'), isNull);
      expect(VisitValidators.validatePartName('A' * 60), isNull);
      expect(VisitValidators.validatePartName('A' * 61), isNotNull);
    });

    test('part quantity boundaries (1 to 99)', () {
      expect(VisitValidators.validatePartQuantity(0), isNotNull);
      expect(VisitValidators.validatePartQuantity(1), isNull);
      expect(VisitValidators.validatePartQuantity(50), isNull);
      expect(VisitValidators.validatePartQuantity(99), isNull);
      expect(VisitValidators.validatePartQuantity(100), isNotNull);
    });

    test('part cost boundaries (0 to 100,000)', () {
      expect(VisitValidators.validatePartCost(null), isNull);
      expect(VisitValidators.validatePartCost(-0.01), isNotNull);
      expect(VisitValidators.validatePartCost(0), isNull);
      expect(VisitValidators.validatePartCost(100000), isNull);
      expect(VisitValidators.validatePartCost(100000.01), isNotNull);
    });

    test('parts group with and without "no parts used"', () {
      // Neither specified -> error
      expect(
        VisitValidators.validatePartsGroup(parts: [], noPartsUsed: false),
        isNotNull,
      );

      // "No parts used" checked with empty parts -> valid
      expect(
        VisitValidators.validatePartsGroup(parts: [], noPartsUsed: true),
        isNull,
      );

      // "No parts used" checked but parts present -> error
      expect(
        VisitValidators.validatePartsGroup(
          parts: [const VisitPartInput(name: 'Valve', quantity: 1)],
          noPartsUsed: true,
        ),
        isNotNull,
      );

      // Valid parts with noPartsUsed: false
      expect(
        VisitValidators.validatePartsGroup(
          parts: [
            const VisitPartInput(name: 'Pipe Seal', quantity: 2, cost: 150),
            const VisitPartInput(name: 'Copper Joint', quantity: 1),
          ],
          noPartsUsed: false,
        ),
        isNull,
      );

      // Invalid part in list -> returns specific part error
      expect(
        VisitValidators.validatePartsGroup(
          parts: [
            const VisitPartInput(name: 'X', quantity: 2), // name too short
          ],
          noPartsUsed: false,
        ),
        contains('Part #1: Part name must be at least 2 characters.'),
      );
    });
  });

  group('VisitValidators - Attachments and Evidence', () {
    test('at most 6 photos allowed per group', () {
      final fivePhotos = List.generate(
        5,
        (i) => ComplaintAttachmentStub(name: 'p$i.jpg', sizeBytes: 1024),
      );
      expect(VisitValidators.validateAttachments(fivePhotos), isNull);

      final sixPhotos = List.generate(
        6,
        (i) => ComplaintAttachmentStub(name: 'p$i.jpg', sizeBytes: 1024),
      );
      expect(VisitValidators.validateAttachments(sixPhotos), isNull);

      final sevenPhotos = List.generate(
        7,
        (i) => ComplaintAttachmentStub(name: 'p$i.jpg', sizeBytes: 1024),
      );
      expect(VisitValidators.validateAttachments(sevenPhotos), isNotNull);
    });

    test('10 MB max size per photo', () {
      final validSize = [
        const ComplaintAttachmentStub(
          name: 'pic.jpg',
          sizeBytes: 10 * 1024 * 1024,
        ),
      ];
      expect(VisitValidators.validateAttachments(validSize), isNull);

      final oversized = [
        const ComplaintAttachmentStub(
          name: 'pic.jpg',
          sizeBytes: (10 * 1024 * 1024) + 1,
        ),
      ];
      expect(VisitValidators.validateAttachments(oversized), isNotNull);
    });

    test('after photos requires at least 1 photo for resolved visit', () {
      expect(VisitValidators.validateAfterPhotos([]), isNotNull);
      expect(
        VisitValidators.validateAfterPhotos([
          const ComplaintAttachmentStub(name: 'after.jpg', sizeBytes: 1024),
        ]),
        isNull,
      );
    });
  });

  group('VisitValidators - Resolved Outcome Fields', () {
    test('what was found (10-500 characters)', () {
      expect(VisitValidators.validateFound(''), isNotNull);
      expect(VisitValidators.validateFound('123456789'), isNotNull);
      expect(VisitValidators.validateFound('1234567890'), isNull);
      expect(VisitValidators.validateFound('A' * 500), isNull);
      expect(VisitValidators.validateFound('A' * 501), isNotNull);
    });

    test('what was repaired (10-500 characters)', () {
      expect(VisitValidators.validateRepaired(''), isNotNull);
      expect(VisitValidators.validateRepaired('123456789'), isNotNull);
      expect(VisitValidators.validateRepaired('1234567890'), isNull);
      expect(VisitValidators.validateRepaired('A' * 500), isNull);
      expect(VisitValidators.validateRepaired('A' * 501), isNotNull);
    });

    test('tenant resolution notes (20-500 characters)', () {
      expect(VisitValidators.validateTenantResolutionNotes(''), isNotNull);
      expect(
        VisitValidators.validateTenantResolutionNotes('1234567890123456789'),
        isNotNull,
      );
      expect(
        VisitValidators.validateTenantResolutionNotes('12345678901234567890'),
        isNull,
      );
      expect(VisitValidators.validateTenantResolutionNotes('B' * 500), isNull);
      expect(
        VisitValidators.validateTenantResolutionNotes('B' * 501),
        isNotNull,
      );
    });
  });

  group('VisitValidators - Needs Another Visit Fields', () {
    test('reason selector and other note', () {
      expect(
        VisitValidators.validateFollowUpReason(null),
        'Please select a reason for the follow-up visit.',
      );
      expect(
        VisitValidators.validateFollowUpReason(FollowUpReason.partNotAvailable),
        isNull,
      );
      expect(
        VisitValidators.validateFollowUpReason(FollowUpReason.needsSpecialist),
        isNull,
      );
      expect(
        VisitValidators.validateFollowUpReason(
          FollowUpReason.other,
          otherNote: '',
        ),
        isNotNull,
      );
      expect(
        VisitValidators.validateFollowUpReason(
          FollowUpReason.other,
          otherNote: 'Too short',
        ),
        isNotNull,
      );
      expect(
        VisitValidators.validateFollowUpReason(
          FollowUpReason.other,
          otherNote: 'Requires structural inspection by engineer',
        ),
        isNull,
      );
    });

    test('follow up details note (10-500 characters)', () {
      expect(VisitValidators.validateFollowUpDetails(''), isNotNull);
      expect(VisitValidators.validateFollowUpDetails('123456789'), isNotNull);
      expect(VisitValidators.validateFollowUpDetails('1234567890'), isNull);
      expect(VisitValidators.validateFollowUpDetails('C' * 500), isNull);
      expect(VisitValidators.validateFollowUpDetails('C' * 501), isNotNull);
    });

    test('suggested date (today to +14 days)', () {
      final today = DateTime(2026, 10, 14);
      expect(VisitValidators.validateSuggestedDate(null, today: today), isNull);
      expect(
        VisitValidators.validateSuggestedDate(
          DateTime(2026, 10, 13),
          today: today,
        ),
        'Suggested date cannot be in the past.',
      );
      expect(
        VisitValidators.validateSuggestedDate(
          DateTime(2026, 10, 14),
          today: today,
        ),
        isNull,
      );
      expect(
        VisitValidators.validateSuggestedDate(
          DateTime(2026, 10, 28),
          today: today,
        ),
        isNull,
      );
      expect(
        VisitValidators.validateSuggestedDate(
          DateTime(2026, 10, 29),
          today: today,
        ),
        'Suggested date must be within 14 days.',
      );
    });
  });
}

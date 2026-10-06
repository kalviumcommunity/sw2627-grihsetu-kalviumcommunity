import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/enums.dart';

void main() {
  group('UserRole Enum Tests', () {
    test('contains all expected roles from PRD', () {
      expect(
        UserRole.values,
        containsAll([
          UserRole.propertyOperations,
          UserRole.complaintOperations,
          UserRole.technician,
          UserRole.propertyOwner,
          UserRole.tenant,
        ]),
      );
    });

    test('displayLabel returns human-readable titles', () {
      expect(UserRole.propertyOperations.displayLabel, 'Property Operations');
      expect(UserRole.complaintOperations.displayLabel, 'Complaint Operations');
      expect(UserRole.technician.displayLabel, 'Technician');
      expect(UserRole.propertyOwner.displayLabel, 'Property Owner');
      expect(UserRole.tenant.displayLabel, 'Tenant');
    });

    test('value returns stable string suitable for Firestore', () {
      expect(UserRole.propertyOperations.value, 'property_operations');
      expect(UserRole.complaintOperations.value, 'complaint_operations');
      expect(UserRole.technician.value, 'technician');
    });

    test('fromValue and tryFromValue deserialize correctly', () {
      expect(UserRole.tryFromValue('technician'), UserRole.technician);
      expect(
        UserRole.tryFromValue('property_operations'),
        UserRole.propertyOperations,
      );
      expect(
        UserRole.tryFromValue('PROPERTY_OPERATIONS'),
        UserRole.propertyOperations,
      );
      expect(UserRole.tryFromValue('unknown_role'), isNull);
      expect(UserRole.fromValue('invalid'), UserRole.propertyOperations);
    });

    test('role helper getters work properly', () {
      expect(UserRole.propertyOperations.isOperationsStaff, isTrue);
      expect(UserRole.complaintOperations.isOperationsStaff, isTrue);
      expect(UserRole.technician.isOperationsStaff, isFalse);
      expect(UserRole.technician.isTechnician, isTrue);
    });
  });

  group('ComplaintStatus Enum Tests', () {
    test('contains all lifecycle statuses required by PRD Section 9', () {
      expect(ComplaintStatus.values, [
        ComplaintStatus.open,
        ComplaintStatus.assigned,
        ComplaintStatus.inProgress,
        ComplaintStatus.waitingForParts,
        ComplaintStatus.resolved,
        ComplaintStatus.closed,
        ComplaintStatus.reopened,
        ComplaintStatus.cancelled,
      ]);
    });

    test('displayLabel returns formatted labels', () {
      expect(ComplaintStatus.open.displayLabel, 'Open');
      expect(ComplaintStatus.assigned.displayLabel, 'Assigned');
      expect(ComplaintStatus.inProgress.displayLabel, 'In Progress');
      expect(ComplaintStatus.waitingForParts.displayLabel, 'Waiting for Parts');
      expect(ComplaintStatus.resolved.displayLabel, 'Resolved');
      expect(ComplaintStatus.closed.displayLabel, 'Closed');
      expect(ComplaintStatus.reopened.displayLabel, 'Reopened');
      expect(ComplaintStatus.cancelled.displayLabel, 'Cancelled');
    });

    test('value returns stable Firestore strings', () {
      expect(ComplaintStatus.waitingForParts.value, 'waiting_for_parts');
      expect(ComplaintStatus.inProgress.value, 'in_progress');
      expect(ComplaintStatus.open.value, 'open');
    });

    test('fromValue and tryFromValue deserialize correctly', () {
      expect(
        ComplaintStatus.tryFromValue('waiting_for_parts'),
        ComplaintStatus.waitingForParts,
      );
      expect(
        ComplaintStatus.tryFromValue('in_progress'),
        ComplaintStatus.inProgress,
      );
      expect(ComplaintStatus.fromValue(null), ComplaintStatus.open);
      expect(ComplaintStatus.fromValue('invalid'), ComplaintStatus.open);
    });

    test('lifecycle helper methods match PRD FR-18 unresolved rules', () {
      expect(ComplaintStatus.open.isUnresolved, isTrue);
      expect(ComplaintStatus.assigned.isUnresolved, isTrue);
      expect(ComplaintStatus.inProgress.isUnresolved, isTrue);
      expect(ComplaintStatus.waitingForParts.isUnresolved, isTrue);
      expect(ComplaintStatus.reopened.isUnresolved, isTrue);

      expect(ComplaintStatus.resolved.isUnresolved, isFalse);
      expect(ComplaintStatus.closed.isUnresolved, isFalse);
      expect(ComplaintStatus.cancelled.isUnresolved, isFalse);

      expect(ComplaintStatus.resolved.isResolvedOrClosed, isTrue);
      expect(ComplaintStatus.closed.isResolvedOrClosed, isTrue);
      expect(ComplaintStatus.open.isResolvedOrClosed, isFalse);
    });
  });

  group('ComplaintPriority Enum Tests', () {
    test('contains all priority levels from PRD FR-05', () {
      expect(ComplaintPriority.values, [
        ComplaintPriority.low,
        ComplaintPriority.medium,
        ComplaintPriority.high,
        ComplaintPriority.urgent,
      ]);
    });

    test('displayLabel returns clean names', () {
      expect(ComplaintPriority.low.displayLabel, 'Low');
      expect(ComplaintPriority.medium.displayLabel, 'Medium');
      expect(ComplaintPriority.high.displayLabel, 'High');
      expect(ComplaintPriority.urgent.displayLabel, 'Urgent');
    });

    test('serialization mappings work', () {
      expect(ComplaintPriority.urgent.value, 'urgent');
      expect(
        ComplaintPriority.tryFromValue('urgent'),
        ComplaintPriority.urgent,
      );
      expect(ComplaintPriority.fromValue('high'), ComplaintPriority.high);
    });
  });

  group('ComplaintCategory Enum Tests', () {
    test('contains all categories from PRD FR-05', () {
      expect(
        ComplaintCategory.values,
        containsAll([
          ComplaintCategory.plumbing,
          ComplaintCategory.electrical,
          ComplaintCategory.structural,
          ComplaintCategory.appliance,
          ComplaintCategory.security,
          ComplaintCategory.cleaning,
          ComplaintCategory.commonArea,
          ComplaintCategory.other,
        ]),
      );
    });

    test('displayLabel and stable values work', () {
      expect(ComplaintCategory.commonArea.displayLabel, 'Common Area');
      expect(ComplaintCategory.commonArea.value, 'common_area');
      expect(
        ComplaintCategory.tryFromValue('common_area'),
        ComplaintCategory.commonArea,
      );
    });
  });

  group('RentStatus Enum Tests', () {
    test('contains all rent statuses from PRD FR-21', () {
      expect(RentStatus.values, [
        RentStatus.due,
        RentStatus.contacted,
        RentStatus.promised,
        RentStatus.overdue,
        RentStatus.paid,
      ]);
    });

    test('displayLabel returns human readable names', () {
      expect(RentStatus.due.displayLabel, 'Due');
      expect(RentStatus.contacted.displayLabel, 'Contacted');
      expect(RentStatus.promised.displayLabel, 'Promised');
      expect(RentStatus.overdue.displayLabel, 'Overdue');
      expect(RentStatus.paid.displayLabel, 'Paid');
    });

    test('serialization and helper methods work', () {
      expect(RentStatus.overdue.value, 'overdue');
      expect(RentStatus.tryFromValue('overdue'), RentStatus.overdue);
      expect(RentStatus.overdue.isOverdue, isTrue);
      expect(RentStatus.paid.isPaid, isTrue);
      expect(RentStatus.due.isPendingAction, isTrue);
      expect(RentStatus.paid.isPendingAction, isFalse);
    });
  });
}

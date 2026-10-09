import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/enums.dart';
import 'package:grihsetu/core/models/models.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';

void main() {
  final validInput = CreateComplaintInput(
    title: 'Kitchen leak',
    description: 'Water is collecting below the sink.',
    category: ComplaintCategory.plumbing,
    priority: ComplaintPriority.high,
    propertyId: 'property-1',
    unitId: 'unit-1',
    tenantId: 'tenant-1',
    submissionId: 'submission-1',
  );

  group('CreateComplaintInput', () {
    test('accepts a complete request', () {
      expect(validInput.validate(), isEmpty);
    });

    test('rejects blank required text and references', () {
      final invalid = CreateComplaintInput(
        title: '  ',
        description: '\n',
        category: ComplaintCategory.other,
        priority: ComplaintPriority.medium,
        propertyId: '',
        unitId: '  ',
        tenantId: '',
      );

      expect(invalid.validate(), hasLength(5));
      expect(invalid.validate(), contains('Complaint title is required.'));
      expect(invalid.validate(), contains('Tenant is required.'));
    });
  });

  group('Firestore complaint payloads', () {
    test('force OPEN and derive creator from the authenticated identity', () {
      final payload = ComplaintFirestorePayloads.complaintForCreate(
        validInput,
        'uid-42',
      );

      expect(payload['status'], 'open');
      expect(payload['createdBy'], 'uid-42');
      expect(payload['createdAt'], isA<FieldValue>());
      expect(payload['updatedAt'], isA<FieldValue>());
      expect(payload, isNot(contains('id')));
    });

    test('creates a deterministic initial audit payload contract', () {
      final payload = ComplaintFirestorePayloads.auditForComplaintCreate(
        complaintId: 'submission-1',
        actorId: 'uid-42',
        category: 'plumbing',
        priority: 'high',
      );

      expect(payload['complaintId'], 'submission-1');
      expect(payload['eventType'], complaintCreatedEventType);
      expect(payload['actorId'], 'uid-42');
      expect(payload['createdAt'], isA<FieldValue>());
      expect(payload['metadata'], containsPair('category', 'plumbing'));
    });
  });

  test('complaint model round-trips Firestore Timestamp dates', () {
    final createdAt = DateTime.utc(2026, 10, 9, 10, 15);
    final complaint = Complaint(
      id: 'complaint-1',
      tenantId: 'tenant-1',
      propertyId: 'property-1',
      unitId: 'unit-1',
      title: 'Kitchen leak',
      description: 'Water is collecting below the sink.',
      category: ComplaintCategory.plumbing,
      priority: ComplaintPriority.high,
      createdBy: 'uid-42',
      createdAt: createdAt,
    );

    final restored = Complaint.fromMap(complaint.toFirestoreMap(), id: complaint.id);
    expect(restored.status, ComplaintStatus.open);
    expect(restored.createdBy, 'uid-42');
    expect(restored.createdAt, createdAt);
  });

  test('typed complaint failures expose safe user-facing messages', () {
    expect(
      const ComplaintAuthenticationException().message,
      contains('sign in'),
    );
    expect(
      const ComplaintPermissionException().message,
      contains('permission'),
    );
  });
}

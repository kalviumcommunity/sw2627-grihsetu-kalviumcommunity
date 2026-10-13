import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_audit_event_type.dart';
import 'package:grihsetu/core/enums/user_role.dart';
import 'package:grihsetu/core/models/complaint_audit_event.dart';

void main() {
  test('typed audit event round-trips structured details and role', () {
    final timestamp = DateTime.utc(2026, 10, 13, 10, 30);
    final event = ComplaintAuditEvent(
      id: 'event-1',
      complaintId: 'complaint-1',
      eventType: ComplaintAuditEventType.technicianReassigned,
      actorId: 'actor-1',
      actorRole: UserRole.complaintOperations,
      timestamp: timestamp,
      details: const {
        'previousTechnicianId': 'tech-old',
        'newTechnicianId': 'tech-new',
      },
      reason: 'Coverage change',
      schemaVersion: 1,
    );

    final restored = ComplaintAuditEvent.fromMap(
      event.toFirestoreMap(),
      id: event.id,
    );

    expect(restored.eventType, ComplaintAuditEventType.technicianReassigned);
    expect(restored.actorRole, UserRole.complaintOperations);
    expect(restored.timestamp, timestamp);
    expect(restored.details['newTechnicianId'], 'tech-new');
    expect(restored.reason, 'Coverage change');
  });

  test('legacy and unknown event records remain readable', () {
    final legacy = ComplaintAuditEvent.fromMap({
      'complaintId': 'complaint-1',
      'eventType': 'LEGACY_EVENT',
      'actorId': 'actor-1',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 13)),
      'metadata': {'note': 'kept'},
    }, id: 'legacy-1');

    expect(legacy.eventType, ComplaintAuditEventType.unknown);
    expect(legacy.eventTypeValue, 'LEGACY_EVENT');
    expect(legacy.metadata['note'], 'kept');
    expect(legacy.actorRole, isNull);
  });

  test('malformed required fields are rejected at the model boundary', () {
    expect(
      () => ComplaintAuditEvent.fromMap({
        'complaintId': 'complaint-1',
        'eventType': 'COMPLAINT_CREATED',
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ComplaintAuditEvent.fromMap({
        'complaintId': 'complaint-1',
        'eventType': 'COMPLAINT_CREATED',
        'actorId': 'actor-1',
        'metadata': 'not-a-map',
      }),
      throwsA(isA<FormatException>()),
    );
  });
}

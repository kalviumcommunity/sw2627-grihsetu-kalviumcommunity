import '../utils/firestore_values.dart';

/// Immutable audit event written with a complaint creation.
class ComplaintAuditEvent {
  const ComplaintAuditEvent({
    required this.id,
    required this.complaintId,
    required this.eventType,
    required this.actorId,
    this.createdAt,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String complaintId;
  final String eventType;
  final String actorId;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toFirestoreMap() => {
    'complaintId': complaintId,
    'eventType': eventType,
    'actorId': actorId,
    if (createdAt != null) 'createdAt': timestampFromDateTime(createdAt),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  factory ComplaintAuditEvent.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) =>
      ComplaintAuditEvent(
        id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
        complaintId: map['complaintId'] as String? ?? '',
        eventType: map['eventType'] as String? ?? '',
        actorId: map['actorId'] as String? ?? '',
        createdAt: dateTimeFromFirestore(map['createdAt']),
        metadata: map['metadata'] is Map
            ? Map<String, dynamic>.from(map['metadata'] as Map)
            : const <String, dynamic>{},
      );
}

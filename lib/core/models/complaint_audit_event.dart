import '../enums/complaint_audit_event_type.dart';
import '../enums/user_role.dart';
import '../utils/firestore_values.dart';

/// Immutable, typed representation of one complaint audit event.
///
/// Older records used `createdAt` and `metadata` and did not contain an actor
/// role. Those records remain readable through the compatibility mapping.
class ComplaintAuditEvent {
  ComplaintAuditEvent({
    required this.id,
    required this.complaintId,
    required this.eventType,
    required this.actorId,
    this.actorRole,
    this.timestamp,
    Map<String, dynamic>? details,
    this.previousValue,
    this.newValue,
    this.reason,
    Map<String, dynamic>? metadata,
    this.schemaVersion,
    this.rawEventType,
  }) : details = Map.unmodifiable(<String, dynamic>{...?metadata, ...?details});

  final String id;
  final String complaintId;
  final ComplaintAuditEventType eventType;
  final String actorId;
  final UserRole? actorRole;
  final DateTime? timestamp;
  final Map<String, dynamic> details;
  final Object? previousValue;
  final Object? newValue;
  final String? reason;
  final int? schemaVersion;
  final String? rawEventType;

  String get eventTypeValue => rawEventType ?? eventType.value;

  /// Legacy aliases retained for callers that used the original model.
  DateTime? get createdAt => timestamp;
  Map<String, dynamic> get metadata => details;

  /// Serializes a resolved event. New writes are staged by the audit writer
  /// so their timestamp is always FieldValue.serverTimestamp().
  Map<String, dynamic> toFirestoreMap() => {
    'complaintId': complaintId,
    'eventType': eventTypeValue,
    'actorId': actorId,
    if (actorRole != null) 'actorRole': actorRole!.value,
    if (timestamp != null) 'createdAt': timestampFromDateTime(timestamp),
    if (details.isNotEmpty) 'metadata': details,
    if (previousValue != null) 'previousValue': previousValue,
    if (newValue != null) 'newValue': newValue,
    if (reason != null && reason!.trim().isNotEmpty) 'reason': reason!.trim(),
    if (schemaVersion != null) 'schemaVersion': schemaVersion,
  };

  factory ComplaintAuditEvent.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    final eventTypeValue = _stringValue(map['eventType']);
    final eventType = ComplaintAuditEventType.tryFromValue(eventTypeValue);
    final complaintId = _stringValue(map['complaintId']);
    final actorId = _stringValue(map['actorId']);
    if (complaintId == null ||
        complaintId.isEmpty ||
        actorId == null ||
        actorId.isEmpty ||
        eventTypeValue == null ||
        eventTypeValue.isEmpty) {
      throw const FormatException('Malformed complaint audit event.');
    }

    final detailsValue = map['details'];
    final metadataValue = map['metadata'];
    if ((detailsValue != null && detailsValue is! Map) ||
        (metadataValue != null && metadataValue is! Map)) {
      throw const FormatException('Audit event details must be a map.');
    }
    final rawDetails = detailsValue is Map ? detailsValue : metadataValue;
    final details = rawDetails is Map
        ? Map<String, dynamic>.from(rawDetails)
        : const <String, dynamic>{};
    final roleValue = _stringValue(map['actorRole']);
    final schemaVersion = map['schemaVersion'];

    return ComplaintAuditEvent(
      id: id.isNotEmpty ? id : (_stringValue(map['id']) ?? ''),
      complaintId: complaintId,
      eventType: eventType ?? ComplaintAuditEventType.unknown,
      rawEventType: eventType == null ? eventTypeValue : null,
      actorId: actorId,
      actorRole: UserRole.tryFromValue(roleValue),
      timestamp: dateTimeFromFirestore(map['timestamp'] ?? map['createdAt']),
      details: details,
      previousValue: map['previousValue'],
      newValue: map['newValue'],
      reason: _stringValue(map['reason']),
      schemaVersion: schemaVersion is int ? schemaVersion : null,
    );
  }
}

String? _stringValue(Object? value) => value is String ? value : null;

import '../utils/firestore_values.dart';

/// The kind of responsibility change recorded for a complaint.
enum TechnicianAssignmentType {
  initialAssignment('INITIAL_ASSIGNMENT'),
  reassignment('REASSIGNMENT');

  const TechnicianAssignmentType(this.value);

  final String value;

  static TechnicianAssignmentType? tryFromValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toUpperCase();
    for (final type in values) {
      if (type.value == normalized || type.name.toUpperCase() == normalized) {
        return type;
      }
    }
    return null;
  }
}

/// Immutable append-only record of a technician responsibility change.
class TechnicianAssignment {
  const TechnicianAssignment({
    required this.id,
    required this.complaintId,
    required this.previousTechnicianId,
    required this.newTechnicianId,
    required this.assignedBy,
    required this.assignmentType,
    required this.operationId,
    this.assignedAt,
    this.reason,
  });

  final String id;
  final String complaintId;
  final String? previousTechnicianId;
  final String newTechnicianId;
  final String assignedBy;
  final TechnicianAssignmentType assignmentType;
  final String operationId;
  final DateTime? assignedAt;
  final String? reason;

  Map<String, dynamic> toFirestoreMap() => {
    'complaintId': complaintId,
    'previousTechnicianId': previousTechnicianId,
    'newTechnicianId': newTechnicianId,
    'assignedBy': assignedBy,
    'assignmentType': assignmentType.value,
    'operationId': operationId,
    if (assignedAt != null) 'assignedAt': timestampFromDateTime(assignedAt),
    if (reason != null && reason!.isNotEmpty) 'reason': reason,
  };

  factory TechnicianAssignment.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    final type = TechnicianAssignmentType.tryFromValue(
      map['assignmentType'] as String?,
    );
    return TechnicianAssignment(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      complaintId: map['complaintId'] as String? ?? '',
      previousTechnicianId: map['previousTechnicianId'] as String?,
      newTechnicianId: map['newTechnicianId'] as String? ?? '',
      assignedBy: map['assignedBy'] as String? ?? '',
      assignmentType: type ?? TechnicianAssignmentType.reassignment,
      operationId: map['operationId'] as String? ?? '',
      assignedAt: dateTimeFromFirestore(map['assignedAt']),
      reason: map['reason'] as String?,
    );
  }
}

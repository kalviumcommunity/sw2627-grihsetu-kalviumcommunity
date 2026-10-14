import '../enums/maintenance_visit_outcome.dart';
import '../utils/firestore_values.dart';

/// Immutable historical record of one technician visit.
class MaintenanceVisit {
  const MaintenanceVisit({
    required this.id,
    required this.complaintId,
    required this.technicianId,
    required this.visitNumber,
    required this.startedAt,
    required this.completedAt,
    required this.observation,
    required this.actionTaken,
    required this.outcome,
    required this.isResolved,
    required this.followUpRequired,
    required this.followUpNotes,
    required this.resolutionSummary,
    required this.operationId,
  });

  final String id;
  final String complaintId;
  final String technicianId;
  final int visitNumber;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? observation;
  final String? actionTaken;
  final MaintenanceVisitOutcome? outcome;
  final bool isResolved;
  final bool followUpRequired;
  final String? followUpNotes;
  final String? resolutionSummary;
  final String operationId;

  bool get isActive => completedAt == null;

  Map<String, dynamic> toMap() => {'id': id, ...toFirestoreMap()};

  Map<String, dynamic> toFirestoreMap() => {
    'complaintId': complaintId,
    'technicianId': technicianId,
    'visitNumber': visitNumber,
    if (startedAt != null) 'startedAt': timestampFromDateTime(startedAt),
    if (completedAt != null) 'completedAt': timestampFromDateTime(completedAt),
    if (observation != null) 'observation': observation,
    if (actionTaken != null) 'actionTaken': actionTaken,
    if (outcome != null) 'outcome': outcome!.value,
    'isResolved': isResolved,
    'followUpRequired': followUpRequired,
    if (followUpNotes != null) 'followUpNotes': followUpNotes,
    if (resolutionSummary != null) 'resolutionSummary': resolutionSummary,
    'operationId': operationId,
  };

  factory MaintenanceVisit.fromMap(Map<String, dynamic> map, {String id = ''}) {
    final visitId = id.isNotEmpty ? id : (map['id'] as String? ?? '');
    final complaintId = map['complaintId'] as String? ?? '';
    final technicianId = map['technicianId'] as String? ?? '';
    final visitNumber = (map['visitNumber'] as num?)?.toInt() ?? 0;
    final isResolved = map['isResolved'];
    final followUpRequired = map['followUpRequired'];
    final operationId = map['operationId'] as String? ?? '';
    if (visitId.trim().isEmpty ||
        complaintId.trim().isEmpty ||
        technicianId.trim().isEmpty ||
        visitNumber < 1 ||
        isResolved is! bool ||
        followUpRequired is! bool ||
        operationId.trim().isEmpty) {
      throw const FormatException('Malformed maintenance visit.');
    }

    final outcomeValue = map['outcome'];
    if (outcomeValue != null && outcomeValue is! String) {
      throw const FormatException('Maintenance visit outcome is invalid.');
    }
    final outcome = MaintenanceVisitOutcome.tryFromValue(
      outcomeValue as String?,
    );
    if (outcomeValue != null && outcome == null) {
      throw const FormatException('Unsupported maintenance visit outcome.');
    }

    return MaintenanceVisit(
      id: visitId,
      complaintId: complaintId,
      technicianId: technicianId,
      visitNumber: visitNumber,
      startedAt: dateTimeFromFirestore(map['startedAt']),
      completedAt: dateTimeFromFirestore(map['completedAt']),
      observation: _optionalString(map, 'observation'),
      actionTaken: _optionalString(map, 'actionTaken'),
      outcome: outcome,
      isResolved: isResolved,
      followUpRequired: followUpRequired,
      followUpNotes: _optionalString(map, 'followUpNotes'),
      resolutionSummary: _optionalString(map, 'resolutionSummary'),
      operationId: operationId,
    );
  }
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Maintenance visit $key is invalid.');
  }
  return value;
}

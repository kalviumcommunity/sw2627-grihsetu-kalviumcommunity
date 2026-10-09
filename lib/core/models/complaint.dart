import '../constants/app_constants.dart';
import '../enums/complaint_category.dart';
import '../enums/complaint_priority.dart';
import '../enums/complaint_status.dart';
import '../utils/firestore_values.dart';

/// Complaint location and reporting data supplied by the create workflow.
///
/// [submissionId] is an idempotency key. A caller must reuse it when retrying
/// the same logical submission, and generate a new one for a new complaint.
class CreateComplaintInput {
  const CreateComplaintInput({
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.propertyId,
    required this.unitId,
    required this.tenantId,
    this.submissionId,
  });

  final String title;
  final String description;
  final ComplaintCategory category;
  final ComplaintPriority priority;
  final String propertyId;
  final String unitId;
  final String tenantId;
  final String? submissionId;

  List<String> validate() {
    final errors = <String>[];
    if (title.trim().isEmpty) errors.add('Complaint title is required.');
    if (description.trim().isEmpty) {
      errors.add('Complaint description is required.');
    }
    if (propertyId.trim().isEmpty) errors.add('Property is required.');
    if (unitId.trim().isEmpty) errors.add('Unit is required.');
    if (tenantId.trim().isEmpty) errors.add('Tenant is required.');
    return errors;
  }
}

/// Firestore-backed complaint entity.
///
/// New writes are created through [ComplaintRepository], which forces
/// [status] to [ComplaintStatus.open], derives [createdBy] from Firebase Auth,
/// and supplies server timestamps. [createdAt] is nullable because a freshly
/// acknowledged write may still contain a pending server timestamp locally.
class Complaint {
  final String id;
  final String tenantId;
  final String propertyId;
  final String unitId;

  final String title;
  final String description;
  final ComplaintCategory category;
  final ComplaintPriority priority;
  final ComplaintStatus status;

  final String? currentTechnicianId;

  final int visitCount;
  final bool isRepeatVisit;
  final int reopenCount;

  final String createdBy;
  final DateTime? createdAt;

  final DateTime? firstAssignedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final DateTime? updatedAt;

  const Complaint({
    required this.id,
    required this.tenantId,
    required this.propertyId,
    required this.unitId,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    this.status = ComplaintStatus.open,
    this.currentTechnicianId,
    this.visitCount = 0,
    bool? isRepeatVisit,
    this.reopenCount = 0,
    required this.createdBy,
    this.createdAt,
    this.firstAssignedAt,
    this.resolvedAt,
    this.closedAt,
    this.updatedAt,
  }) : isRepeatVisit =
           isRepeatVisit ?? (visitCount > AppConstants.repeatVisitThreshold);

  /// Returns required-field errors before persistence.
  List<String> validate() => CreateComplaintInput(
    title: title,
    description: description,
    category: category,
    priority: priority,
    propertyId: propertyId,
    unitId: unitId,
    tenantId: tenantId,
  ).validate();

  /// Existing fixture-compatible map. Repository payloads should use
  /// [toFirestoreMap] so document IDs are not duplicated in the document.
  Map<String, dynamic> toMap() => {
    'id': id,
    ...toFirestoreMap(),
  };

  /// Firestore payload without the document ID.
  Map<String, dynamic> toFirestoreMap() => {
    'tenantId': tenantId,
    'propertyId': propertyId,
    'unitId': unitId,
    'title': title,
    'description': description,
    'category': category.value,
    'priority': priority.value,
    'status': status.value,
    if (currentTechnicianId != null) 'currentTechnicianId': currentTechnicianId,
    'visitCount': visitCount,
    'isRepeatVisit': isRepeatVisit,
    'reopenCount': reopenCount,
    'createdBy': createdBy,
    if (createdAt != null) 'createdAt': timestampFromDateTime(createdAt),
    if (firstAssignedAt != null)
      'firstAssignedAt': timestampFromDateTime(firstAssignedAt),
    if (resolvedAt != null) 'resolvedAt': timestampFromDateTime(resolvedAt),
    if (closedAt != null) 'closedAt': timestampFromDateTime(closedAt),
    if (updatedAt != null) 'updatedAt': timestampFromDateTime(updatedAt),
  };

  factory Complaint.fromMap(Map<String, dynamic> map, {String id = ''}) {
    final visitCount = (map['visitCount'] as num?)?.toInt() ?? 0;
    return Complaint(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      tenantId: map['tenantId'] as String? ?? '',
      propertyId: map['propertyId'] as String? ?? '',
      unitId: map['unitId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: ComplaintCategory.fromValue(map['category'] as String?),
      priority: ComplaintPriority.fromValue(map['priority'] as String?),
      status: ComplaintStatus.fromValue(map['status'] as String?),
      currentTechnicianId: map['currentTechnicianId'] as String?,
      visitCount: visitCount,
      isRepeatVisit:
          map['isRepeatVisit'] as bool? ??
          (visitCount > AppConstants.repeatVisitThreshold),
      reopenCount: (map['reopenCount'] as num?)?.toInt() ?? 0,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: dateTimeFromFirestore(map['createdAt']),
      firstAssignedAt: dateTimeFromFirestore(map['firstAssignedAt']),
      resolvedAt: dateTimeFromFirestore(map['resolvedAt']),
      closedAt: dateTimeFromFirestore(map['closedAt']),
      updatedAt: dateTimeFromFirestore(map['updatedAt']),
    );
  }

  Complaint copyWith({
    String? id,
    String? tenantId,
    String? propertyId,
    String? unitId,
    String? title,
    String? description,
    ComplaintCategory? category,
    ComplaintPriority? priority,
    ComplaintStatus? status,
    String? currentTechnicianId,
    int? visitCount,
    bool? isRepeatVisit,
    int? reopenCount,
    String? createdBy,
    DateTime? createdAt,
    DateTime? firstAssignedAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
    DateTime? updatedAt,
  }) =>
      Complaint(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        propertyId: propertyId ?? this.propertyId,
        unitId: unitId ?? this.unitId,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        currentTechnicianId: currentTechnicianId ?? this.currentTechnicianId,
        visitCount: visitCount ?? this.visitCount,
        isRepeatVisit: isRepeatVisit ?? this.isRepeatVisit,
        reopenCount: reopenCount ?? this.reopenCount,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        firstAssignedAt: firstAssignedAt ?? this.firstAssignedAt,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        closedAt: closedAt ?? this.closedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Complaint &&
          id == other.id &&
          tenantId == other.tenantId &&
          propertyId == other.propertyId &&
          unitId == other.unitId &&
          title == other.title &&
          category == other.category &&
          priority == other.priority &&
          status == other.status &&
          visitCount == other.visitCount &&
          isRepeatVisit == other.isRepeatVisit &&
          reopenCount == other.reopenCount;

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    propertyId,
    unitId,
    title,
    category,
    priority,
    status,
    visitCount,
    isRepeatVisit,
  );

  @override
  String toString() =>
      'Complaint(id: $id, title: $title, status: ${status.displayLabel}, priority: ${priority.displayLabel})';
}

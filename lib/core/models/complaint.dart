import '../constants/app_constants.dart';
import '../enums/complaint_category.dart';
import '../enums/complaint_priority.dart';
import '../enums/complaint_status.dart';

/// Lightweight Complaint model stub matching PRD Section 16 (Complaint Entity).
///
/// Central domain entity representing tenant maintenance requests and office workflows.
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
  final DateTime createdAt;

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
    required this.createdAt,
    this.firstAssignedAt,
    this.resolvedAt,
    this.closedAt,
    this.updatedAt,
  }) : isRepeatVisit =
           isRepeatVisit ?? (visitCount > AppConstants.repeatVisitThreshold);

  /// Serializes model to a Firestore-friendly Map using stable enum string values.
  Map<String, dynamic> toMap() => {
    'id': id,
    'tenantId': tenantId,
    'propertyId': propertyId,
    'unitId': unitId,
    'title': title,
    'description': description,
    'category': category.value,
    'priority': priority.value,
    'status': status.value,
    'currentTechnicianId': currentTechnicianId,
    'visitCount': visitCount,
    'isRepeatVisit': isRepeatVisit,
    'reopenCount': reopenCount,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'firstAssignedAt': firstAssignedAt?.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  /// Constructs a [Complaint] from a Firestore/JSON map.
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
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      firstAssignedAt: _parseDateTime(map['firstAssignedAt']),
      resolvedAt: _parseDateTime(map['resolvedAt']),
      closedAt: _parseDateTime(map['closedAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
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
  }) {
    return Complaint(
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
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Complaint &&
          runtimeType == other.runtimeType &&
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

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    return (value as dynamic).toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}

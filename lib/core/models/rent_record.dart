import '../enums/rent_status.dart';

/// Lightweight RentRecord model stub matching PRD Section 16 (Rent Record Entity).
///
/// Tracks rent collection workflows and follow-up activities without processing payments.
class RentRecord {
  final String id;
  final String tenantId;
  final String propertyId;
  final String unitId;

  final String month;
  final double amountDue;
  final DateTime dueDate;
  final RentStatus status;

  final DateTime? lastFollowUpAt;
  final DateTime? nextFollowUpAt;

  const RentRecord({
    required this.id,
    required this.tenantId,
    required this.propertyId,
    required this.unitId,
    required this.month,
    required this.amountDue,
    required this.dueDate,
    this.status = RentStatus.due,
    this.lastFollowUpAt,
    this.nextFollowUpAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'tenantId': tenantId,
    'propertyId': propertyId,
    'unitId': unitId,
    'month': month,
    'amountDue': amountDue,
    'dueDate': dueDate.toIso8601String(),
    'status': status.value,
    'lastFollowUpAt': lastFollowUpAt?.toIso8601String(),
    'nextFollowUpAt': nextFollowUpAt?.toIso8601String(),
  };

  factory RentRecord.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return RentRecord(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      tenantId: map['tenantId'] as String? ?? '',
      propertyId: map['propertyId'] as String? ?? '',
      unitId: map['unitId'] as String? ?? '',
      month: map['month'] as String? ?? '',
      amountDue: (map['amountDue'] as num?)?.toDouble() ?? 0.0,
      dueDate: _parseDateTime(map['dueDate']) ?? DateTime.now(),
      status: RentStatus.fromValue(map['status'] as String?),
      lastFollowUpAt: _parseDateTime(map['lastFollowUpAt']),
      nextFollowUpAt: _parseDateTime(map['nextFollowUpAt']),
    );
  }

  RentRecord copyWith({
    String? id,
    String? tenantId,
    String? propertyId,
    String? unitId,
    String? month,
    double? amountDue,
    DateTime? dueDate,
    RentStatus? status,
    DateTime? lastFollowUpAt,
    DateTime? nextFollowUpAt,
  }) {
    return RentRecord(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      month: month ?? this.month,
      amountDue: amountDue ?? this.amountDue,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      lastFollowUpAt: lastFollowUpAt ?? this.lastFollowUpAt,
      nextFollowUpAt: nextFollowUpAt ?? this.nextFollowUpAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RentRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tenantId == other.tenantId &&
          propertyId == other.propertyId &&
          unitId == other.unitId &&
          month == other.month &&
          amountDue == other.amountDue &&
          status == other.status;

  @override
  int get hashCode =>
      Object.hash(id, tenantId, propertyId, unitId, month, amountDue, status);

  @override
  String toString() =>
      'RentRecord(id: $id, month: $month, amountDue: $amountDue, status: ${status.displayLabel})';
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

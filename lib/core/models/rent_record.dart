import 'package:cloud_firestore/cloud_firestore.dart';

import '../enums/rent_status.dart';
import '../utils/firestore_values.dart';

/// A monthly rent case. GrihSetu records collection workflow; it does not
/// process or reconcile payments with a payment provider.
class RentRecord {
  final String id;
  final String tenantId;
  final String propertyId;
  final String unitId;
  final String month;
  final double amountDue;
  final DateTime dueDate;
  final RentStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
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
    this.createdAt,
    this.updatedAt,
    this.lastFollowUpAt,
    this.nextFollowUpAt,
  });

  /// Returns validation errors instead of silently repairing invalid records.
  List<String> validate() {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('Rent record ID is required.');
    if (tenantId.trim().isEmpty) errors.add('Tenant is required.');
    if (propertyId.trim().isEmpty) errors.add('Property is required.');
    if (unitId.trim().isEmpty) errors.add('Unit is required.');
    if (month.trim().isEmpty) errors.add('Rental month is required.');
    if (!amountDue.isFinite || amountDue < 0) {
      errors.add('Amount due must be a finite, non-negative number.');
    }
    return errors;
  }

  /// Canonical Firestore representation. Entity IDs are document IDs and are
  /// deliberately not duplicated in the document body.
  Map<String, dynamic> toFirestoreMap() => {
    'tenantId': tenantId,
    'propertyId': propertyId,
    'unitId': unitId,
    'month': month,
    'amountDue': amountDue,
    'dueDate': timestampFromDateTime(dueDate),
    'status': status.value,
    if (createdAt != null) 'createdAt': timestampFromDateTime(createdAt),
    if (updatedAt != null) 'updatedAt': timestampFromDateTime(updatedAt),
    'lastFollowUpAt': timestampFromDateTime(lastFollowUpAt),
    'nextFollowUpAt': timestampFromDateTime(nextFollowUpAt),
  };

  /// Compatibility representation used by fixtures and model tests. The
  /// repository uses [toFirestoreMap] because the document ID is authoritative.
  Map<String, dynamic> toMap() => {'id': id, ...toFirestoreMap()};

  factory RentRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => RentRecord.fromMap(snapshot.data() ?? const {}, id: snapshot.id);

  factory RentRecord.fromMap(Map<String, dynamic> map, {String id = ''}) {
    final recordId = id.trim().isNotEmpty
        ? id.trim()
        : _requiredString(map, 'id');
    final tenantId = _requiredString(map, 'tenantId');
    final propertyId = _requiredString(map, 'propertyId');
    final unitId = _requiredString(map, 'unitId');
    final month = _requiredString(map, 'month');
    final amount = map['amountDue'];
    final dueDate = dateTimeFromFirestore(map['dueDate']);
    final statusValue = map['status'];
    if (amount is! num ||
        !amount.toDouble().isFinite ||
        amount.toDouble() < 0) {
      throw const FormatException('Rent amountDue is missing or invalid.');
    }
    if (dueDate == null) {
      throw const FormatException('Rent dueDate is missing or invalid.');
    }
    if (statusValue is! String ||
        RentStatus.tryFromValue(statusValue) == null) {
      throw const FormatException('Rent status is missing or invalid.');
    }

    return RentRecord(
      id: recordId,
      tenantId: tenantId,
      propertyId: propertyId,
      unitId: unitId,
      month: month,
      amountDue: amount.toDouble(),
      dueDate: dueDate,
      status: RentStatus.fromValue(statusValue),
      createdAt: dateTimeFromFirestore(map['createdAt']),
      updatedAt: dateTimeFromFirestore(map['updatedAt']),
      lastFollowUpAt: dateTimeFromFirestore(map['lastFollowUpAt']),
      nextFollowUpAt: dateTimeFromFirestore(map['nextFollowUpAt']),
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
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastFollowUpAt,
    DateTime? nextFollowUpAt,
    bool clearNextFollowUpAt = false,
  }) => RentRecord(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    propertyId: propertyId ?? this.propertyId,
    unitId: unitId ?? this.unitId,
    month: month ?? this.month,
    amountDue: amountDue ?? this.amountDue,
    dueDate: dueDate ?? this.dueDate,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastFollowUpAt: lastFollowUpAt ?? this.lastFollowUpAt,
    nextFollowUpAt: clearNextFollowUpAt
        ? null
        : nextFollowUpAt ?? this.nextFollowUpAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RentRecord &&
          id == other.id &&
          tenantId == other.tenantId &&
          propertyId == other.propertyId &&
          unitId == other.unitId &&
          month == other.month &&
          amountDue == other.amountDue &&
          dueDate == other.dueDate &&
          status == other.status &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          lastFollowUpAt == other.lastFollowUpAt &&
          nextFollowUpAt == other.nextFollowUpAt;

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    propertyId,
    unitId,
    month,
    amountDue,
    dueDate,
    status,
    createdAt,
    updatedAt,
    lastFollowUpAt,
    nextFollowUpAt,
  );

  @override
  String toString() =>
      'RentRecord(id: $id, month: $month, amountDue: $amountDue, status: ${status.displayLabel})';
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('Rent $key is missing or invalid.');
}

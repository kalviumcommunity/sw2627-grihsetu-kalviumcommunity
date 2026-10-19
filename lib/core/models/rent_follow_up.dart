import 'package:cloud_firestore/cloud_firestore.dart';

import '../enums/rent_status.dart';
import '../utils/firestore_values.dart';

/// An immutable tenant-contact entry belonging to one rent record.
class RentFollowUp {
  final String id;
  final String rentRecordId;
  final String handledBy;
  final DateTime? createdAt;
  final String contactMethod;
  final String notes;
  final String tenantResponse;
  final DateTime? promisedPaymentDate;
  final DateTime? nextFollowUpAt;
  final RentStatus? previousStatus;
  final RentStatus? resultingStatus;

  const RentFollowUp({
    required this.id,
    required this.rentRecordId,
    required this.handledBy,
    required this.createdAt,
    required this.contactMethod,
    required this.notes,
    required this.tenantResponse,
    this.promisedPaymentDate,
    this.nextFollowUpAt,
    this.previousStatus,
    this.resultingStatus,
  });

  List<String> validate() {
    final errors = <String>[];
    if (id.trim().isEmpty) {
      errors.add('Follow-up ID is required.');
    }
    if (rentRecordId.trim().isEmpty) {
      errors.add('Rent record is required.');
    }
    if (handledBy.trim().isEmpty) {
      errors.add('Follow-up staff member is required.');
    }
    if (contactMethod.trim().isEmpty) {
      errors.add('Contact method is required.');
    }
    if (notes.trim().isEmpty && tenantResponse.trim().isEmpty) {
      errors.add('Follow-up notes or tenant response is required.');
    }
    return errors;
  }

  Map<String, dynamic> toFirestoreMap() => {
    'rentRecordId': rentRecordId,
    'handledBy': handledBy,
    if (createdAt != null) 'createdAt': timestampFromDateTime(createdAt),
    'contactMethod': contactMethod,
    'notes': notes,
    'tenantResponse': tenantResponse,
    'promisedPaymentDate': timestampFromDateTime(promisedPaymentDate),
    'nextFollowUpAt': timestampFromDateTime(nextFollowUpAt),
    if (previousStatus != null) 'previousStatus': previousStatus!.value,
    if (resultingStatus != null) 'resultingStatus': resultingStatus!.value,
  };

  Map<String, dynamic> toMap() => {'id': id, ...toFirestoreMap()};

  factory RentFollowUp.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => RentFollowUp.fromMap(snapshot.data() ?? const {}, id: snapshot.id);

  factory RentFollowUp.fromMap(Map<String, dynamic> map, {String id = ''}) {
    String required(String key) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      throw FormatException('Rent follow-up $key is missing or invalid.');
    }

    RentStatus? status(String key) {
      final value = map[key];
      if (value == null) return null;
      if (value is! String || RentStatus.tryFromValue(value) == null) {
        throw FormatException('Rent follow-up $key is invalid.');
      }
      return RentStatus.fromValue(value);
    }

    final followUp = RentFollowUp(
      id: id.trim().isNotEmpty ? id.trim() : required('id'),
      rentRecordId: required('rentRecordId'),
      handledBy: required('handledBy'),
      createdAt: dateTimeFromFirestore(map['createdAt']),
      contactMethod: required('contactMethod'),
      notes: _optionalString(map['notes']),
      tenantResponse: _optionalString(map['tenantResponse']),
      promisedPaymentDate: dateTimeFromFirestore(map['promisedPaymentDate']),
      nextFollowUpAt: dateTimeFromFirestore(map['nextFollowUpAt']),
      previousStatus: status('previousStatus'),
      resultingStatus: status('resultingStatus'),
    );
    if (followUp.notes.trim().isEmpty &&
        followUp.tenantResponse.trim().isEmpty) {
      throw const FormatException('Rent follow-up has no notes or response.');
    }
    return followUp;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RentFollowUp &&
          id == other.id &&
          rentRecordId == other.rentRecordId &&
          handledBy == other.handledBy &&
          createdAt == other.createdAt &&
          contactMethod == other.contactMethod &&
          notes == other.notes &&
          tenantResponse == other.tenantResponse &&
          promisedPaymentDate == other.promisedPaymentDate &&
          nextFollowUpAt == other.nextFollowUpAt &&
          previousStatus == other.previousStatus &&
          resultingStatus == other.resultingStatus;

  @override
  int get hashCode => Object.hash(
    id,
    rentRecordId,
    handledBy,
    createdAt,
    contactMethod,
    notes,
    tenantResponse,
    promisedPaymentDate,
    nextFollowUpAt,
    previousStatus,
    resultingStatus,
  );
}

String _optionalString(dynamic value) => value is String ? value : '';

/// Input used when appending a new contact attempt.
class RentFollowUpInput {
  final String contactMethod;
  final String notes;
  final String tenantResponse;
  final DateTime? promisedPaymentDate;
  final DateTime? nextFollowUpAt;

  const RentFollowUpInput({
    required this.contactMethod,
    this.notes = '',
    this.tenantResponse = '',
    this.promisedPaymentDate,
    this.nextFollowUpAt,
  });

  List<String> validate() => RentFollowUp(
    id: '_input',
    rentRecordId: '_input',
    handledBy: '_input',
    createdAt: null,
    contactMethod: contactMethod,
    notes: notes,
    tenantResponse: tenantResponse,
    promisedPaymentDate: promisedPaymentDate,
    nextFollowUpAt: nextFollowUpAt,
  ).validate();
}

typedef AddRentFollowUpInput = RentFollowUpInput;

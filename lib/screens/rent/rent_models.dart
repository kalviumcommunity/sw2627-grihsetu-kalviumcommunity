import '../../core/enums/rent_status.dart';
import '../../core/models/property.dart';
import '../../core/models/rent_record.dart';
import '../../core/models/tenant.dart';

/// Follow-up communication channels.
enum FollowUpMethod {
  call('Call'),
  message('Message'),
  visit('Visit'),
  email('Email');

  const FollowUpMethod(this.label);
  final String label;
}

/// Follow-up outcome options.
enum FollowUpOutcome {
  noAnswer('No answer'),
  spokeToTenant('Spoke to tenant'),
  promisedToPay('Promised to pay'),
  refusedOrDisputed('Refused or disputed'),
  paid('Paid');

  const FollowUpOutcome(this.label);
  final String label;
}

/// Payment settlement modes.
enum PaymentMode {
  cash('Cash'),
  upi('UPI'),
  bankTransfer('Bank transfer'),
  cheque('Cheque');

  const PaymentMode(this.label);
  final String label;
}

/// A recorded rent follow-up interaction (UI-only model).
class RentFollowUp {
  const RentFollowUp({
    required this.id,
    required this.rentRecordId,
    required this.method,
    required this.outcome,
    required this.actor,
    required this.timestamp,
    this.note = '',
    this.promisedDate,
    this.promisedAmount,
    this.nextFollowUpDate,
  });

  final String id;
  final String rentRecordId;
  final FollowUpMethod method;
  final FollowUpOutcome outcome;
  final String actor;
  final DateTime timestamp;
  final String note;
  final DateTime? promisedDate;
  final double? promisedAmount;
  final DateTime? nextFollowUpDate;

  RentFollowUp copyWith({
    String? id,
    String? rentRecordId,
    FollowUpMethod? method,
    FollowUpOutcome? outcome,
    String? actor,
    DateTime? timestamp,
    String? note,
    DateTime? promisedDate,
    double? promisedAmount,
    DateTime? nextFollowUpDate,
  }) {
    return RentFollowUp(
      id: id ?? this.id,
      rentRecordId: rentRecordId ?? this.rentRecordId,
      method: method ?? this.method,
      outcome: outcome ?? this.outcome,
      actor: actor ?? this.actor,
      timestamp: timestamp ?? this.timestamp,
      note: note ?? this.note,
      promisedDate: promisedDate ?? this.promisedDate,
      promisedAmount: promisedAmount ?? this.promisedAmount,
      nextFollowUpDate: nextFollowUpDate ?? this.nextFollowUpDate,
    );
  }
}

/// A recorded payment for a rent record (UI-only model).
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.rentRecordId,
    required this.amount,
    required this.date,
    required this.mode,
    required this.actor,
    this.note,
  });

  final String id;
  final String rentRecordId;
  final double amount;
  final DateTime date;
  final PaymentMode mode;
  final String actor;
  final String? note;
}

/// UI-enriched rent item providing complete relational information
/// (tenant, property, unit, follow-up timeline and payments).
class RentItem {
  const RentItem({
    required this.record,
    required this.tenant,
    required this.property,
    required this.unit,
    this.followUps = const [],
    this.payments = const [],
  });

  final RentRecord record;
  final Tenant tenant;
  final Property property;
  final Unit unit;
  final List<RentFollowUp> followUps;
  final List<PaymentRecord> payments;

  String get id => record.id;
  String get tenantName => tenant.name;
  String get tenantPhone => tenant.phone;
  String get propertyName => property.name;
  String get unitNumber => unit.unitNumber;
  String get month => record.month;
  double get amountDue => record.amountDue;
  DateTime get dueDate => record.dueDate;
  RentStatus get status => record.status;
  DateTime? get nextFollowUpAt => record.nextFollowUpAt;

  double get amountPaid =>
      payments.fold(0.0, (sum, p) => sum + p.amount);

  double get balance {
    final remaining = amountDue - amountPaid;
    return remaining < 0 ? 0.0 : remaining;
  }

  bool get isPaid => status == RentStatus.paid || balance <= 0;

  RentFollowUp? get lastFollowUp {
    if (followUps.isEmpty) return null;
    final sorted = List<RentFollowUp>.from(followUps)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.first;
  }

  RentItem copyWith({
    RentRecord? record,
    Tenant? tenant,
    Property? property,
    Unit? unit,
    List<RentFollowUp>? followUps,
    List<PaymentRecord>? payments,
  }) {
    return RentItem(
      record: record ?? this.record,
      tenant: tenant ?? this.tenant,
      property: property ?? this.property,
      unit: unit ?? this.unit,
      followUps: followUps ?? this.followUps,
      payments: payments ?? this.payments,
    );
  }
}

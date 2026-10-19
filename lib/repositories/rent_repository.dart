import 'dart:async';

import '../core/enums/rent_status.dart';
import '../core/fixtures/sample_fixtures.dart';
import '../core/models/property.dart';
import '../core/models/tenant.dart';
import '../screens/rent/rent_models.dart';
import '../utils/rent_rules.dart';

/// Repository interface for Rent management matching GRIH-032.
///
/// TODO(Firestore): Replace InMemoryRentRepository with FirestoreRentRepository
/// backed by Firebase collection references ('rent_records', 'rent_follow_ups', 'rent_payments').
abstract interface class RentRepository {
  Future<List<RentItem>> list({
    String? propertyId,
    String? unitId,
    String? tenantId,
    String? month,
    RentStatus? status,
  });

  Future<RentItem?> get(String id);

  Future<RentItem> addFollowUp(RentFollowUp followUp);

  Future<RentItem> markPaid(PaymentRecord payment);
}

/// In-memory implementation of [RentRepository] seeded with [SampleFixtures].
class InMemoryRentRepository implements RentRepository {
  InMemoryRentRepository({
    this.simulatedDelay = const Duration(milliseconds: 60),
    this.debugSimulateFailure = false,
  }) {
    _seedInitialData();
  }

  final Duration simulatedDelay;
  bool debugSimulateFailure;

  final Map<String, RentItem> _items = {};

  void _seedInitialData() {
    final properties = {
      for (final p in SampleFixtures.sampleProperties) p.id: p,
    };
    final units = {for (final u in SampleFixtures.sampleUnits) u.id: u};
    final tenants = {for (final t in SampleFixtures.sampleTenants) t.id: t};

    for (final record in SampleFixtures.sampleRentRecords) {
      final prop =
          properties[record.propertyId] ??
          Property(
            id: record.propertyId,
            name: 'Property ${record.propertyId}',
            address: 'Gurugram',
            createdAt: DateTime(2025, 1, 1),
          );
      final unit =
          units[record.unitId] ??
          Unit(
            id: record.unitId,
            propertyId: record.propertyId,
            unitNumber: 'Unit ${record.unitId}',
            floor: 1,
            occupancyStatus: 'occupied',
          );
      final tenant =
          tenants[record.tenantId] ??
          Tenant(
            id: record.tenantId,
            name: 'Tenant ${record.tenantId}',
            phone: '+91 98000 00000',
            propertyId: record.propertyId,
            unitId: record.unitId,
          );

      final followUps = <RentFollowUp>[];
      final payments = <PaymentRecord>[];

      if (record.id == 'rnt_3001') {
        followUps.add(
          RentFollowUp(
            id: 'flw_001',
            rentRecordId: record.id,
            method: FollowUpMethod.call,
            outcome: FollowUpOutcome.noAnswer,
            actor: 'Riya Sharma',
            timestamp: DateTime(2026, 10, 5, 11, 0),
            note: 'Called tenant mobile, rang without answer.',
            nextFollowUpDate: DateTime(2026, 10, 6),
          ),
        );
      } else if (record.id == 'rnt_3002') {
        followUps.add(
          RentFollowUp(
            id: 'flw_002',
            rentRecordId: record.id,
            method: FollowUpMethod.call,
            outcome: FollowUpOutcome.promisedToPay,
            actor: 'Riya Sharma',
            timestamp: DateTime(2026, 10, 4, 15, 30),
            promisedDate: DateTime(2026, 10, 7),
            promisedAmount: 32000.0,
            note: 'Spoke with tenant; salary credited on 6th, promised payment on 7th.',
            nextFollowUpDate: DateTime(2026, 10, 7),
          ),
        );
      } else if (record.id == 'rnt_3003') {
        followUps.add(
          RentFollowUp(
            id: 'flw_003',
            rentRecordId: record.id,
            method: FollowUpMethod.message,
            outcome: FollowUpOutcome.paid,
            actor: 'Vikram Malhotra',
            timestamp: DateTime(2026, 10, 2, 17, 0),
            note: 'Tenant transferred full rent via UPI transaction ref #UPI8912.',
          ),
        );
        payments.add(
          PaymentRecord(
            id: 'pay_001',
            rentRecordId: record.id,
            amount: 28000.0,
            date: DateTime(2026, 10, 2, 17, 0),
            mode: PaymentMode.upi,
            actor: 'Vikram Malhotra',
            note: 'UPI ref #UPI8912',
          ),
        );
      }

      _items[record.id] = RentItem(
        record: record,
        tenant: tenant,
        property: prop,
        unit: unit,
        followUps: followUps,
        payments: payments,
      );
    }
  }

  Future<void> _checkDelayAndFailure() async {
    if (simulatedDelay > Duration.zero) {
      await Future<void>.delayed(simulatedDelay);
    }
    if (debugSimulateFailure) {
      throw StateError('Simulated repository failure');
    }
  }

  @override
  Future<List<RentItem>> list({
    String? propertyId,
    String? unitId,
    String? tenantId,
    String? month,
    RentStatus? status,
  }) async {
    await _checkDelayAndFailure();
    var results = _items.values.toList();

    if (propertyId != null && propertyId.isNotEmpty) {
      results = results
          .where((i) => i.record.propertyId == propertyId)
          .toList();
    }
    if (unitId != null && unitId.isNotEmpty) {
      results = results.where((i) => i.record.unitId == unitId).toList();
    }
    if (tenantId != null && tenantId.isNotEmpty) {
      results = results.where((i) => i.record.tenantId == tenantId).toList();
    }
    if (month != null && month.isNotEmpty) {
      results = results.where((i) => i.record.month == month).toList();
    }
    if (status != null) {
      results = results.where((i) => i.record.status == status).toList();
    }

    return results;
  }

  @override
  Future<RentItem?> get(String id) async {
    await _checkDelayAndFailure();
    return _items[id];
  }

  @override
  Future<RentItem> addFollowUp(RentFollowUp followUp) async {
    await _checkDelayAndFailure();
    final existing = _items[followUp.rentRecordId];
    if (existing == null) {
      throw StateError('Rent record not found: ${followUp.rentRecordId}');
    }

    // Determine status transition
    RentStatus newStatus = existing.record.status;
    if (followUp.outcome == FollowUpOutcome.paid) {
      newStatus = RentStatus.paid;
    } else if (followUp.outcome == FollowUpOutcome.promisedToPay) {
      newStatus = RentStatus.promised;
    } else if (existing.record.status == RentStatus.due) {
      // First follow-up moves due -> contacted
      newStatus = RentStatus.contacted;
    }

    final updatedRecord = existing.record.copyWith(
      status: newStatus,
      lastFollowUpAt: followUp.timestamp,
      nextFollowUpAt: followUp.nextFollowUpDate,
    );

    final updatedFollowUps = [followUp, ...existing.followUps];

    final updatedItem = existing.copyWith(
      record: updatedRecord,
      followUps: updatedFollowUps,
    );

    _items[followUp.rentRecordId] = updatedItem;
    return updatedItem;
  }

  @override
  Future<RentItem> markPaid(PaymentRecord payment) async {
    await _checkDelayAndFailure();
    final existing = _items[payment.rentRecordId];
    if (existing == null) {
      throw StateError('Rent record not found: ${payment.rentRecordId}');
    }

    final updatedPayments = [payment, ...existing.payments];
    final remaining = balance(existing.record, updatedPayments);
    final isFullyPaid = remaining <= 0;

    final updatedRecord = existing.record.copyWith(
      status: isFullyPaid ? RentStatus.paid : existing.record.status,
    );

    final updatedItem = existing.copyWith(
      record: updatedRecord,
      payments: updatedPayments,
    );

    _items[payment.rentRecordId] = updatedItem;
    return updatedItem;
  }
}

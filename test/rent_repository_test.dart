import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/domain/rent_status_logic.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/models/rent_follow_up.dart';
import 'package:grihsetu/core/models/rent_record.dart';

void main() {
  final dueDate = DateTime.utc(2026, 10, 5);

  RentRecord record({RentStatus status = RentStatus.due}) => RentRecord(
    id: 'rent-1',
    tenantId: 'tenant-1',
    propertyId: 'property-1',
    unitId: 'unit-1',
    month: 'October 2026',
    amountDue: 25000,
    dueDate: dueDate,
    status: status,
  );

  test('rent records use Firestore timestamps and document IDs', () {
    final model = record();
    final firestoreMap = model.toFirestoreMap();

    expect(firestoreMap, isNot(contains('id')));
    expect(firestoreMap['dueDate'], isA<Timestamp>());
    expect(RentRecord.fromMap(firestoreMap, id: model.id), model);
    expect(RentRecord.fromMap(model.toMap()), model);
  });

  test('malformed required rent data is rejected instead of defaulted', () {
    expect(
      () => RentRecord.fromMap({'tenantId': 'tenant-1'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('status policy preserves promises after the due date', () {
    final promised = record(status: RentStatus.promised);
    final afterPromise = RentStatusPolicy.statusForDueDate(
      promised,
      asOf: DateTime.utc(2026, 10, 10),
    );
    expect(afterPromise, RentStatus.promised);
    expect(
      RentStatusPolicy.statusForDueDate(
        record(),
        asOf: DateTime.utc(2026, 10, 10),
      ),
      RentStatus.overdue,
    );
    expect(
      RentStatusPolicy.canTransition(RentStatus.paid, RentStatus.overdue),
      isFalse,
    );
  });

  test(
    'in-memory follow-up atomically appends history and updates parent',
    () async {
      final repository = _TestInMemoryRentRepository(records: [record()]);
      final followUp = await repository.addRentFollowUp(
        'rent-1',
        RentFollowUpInput(
          contactMethod: 'Phone Call',
          tenantResponse: 'Will pay by 7 October.',
          promisedPaymentDate: DateTime.utc(2026, 10, 7),
          nextFollowUpAt: DateTime.utc(2026, 10, 8, 10),
        ),
      );

      final updated = await repository.getRentRecord('rent-1');
      final history = await repository.getRentFollowUps('rent-1');
      expect(updated?.status, RentStatus.promised);
      expect(updated?.lastFollowUpAt, isNotNull);
      expect(updated?.nextFollowUpAt, DateTime.utc(2026, 10, 8, 10));
      expect(history, [followUp]);
      expect(followUp.previousStatus, RentStatus.due);
      expect(followUp.resultingStatus, RentStatus.promised);
    },
  );

  test('paid records cannot be changed or followed up', () async {
    final repository = _TestInMemoryRentRepository(records: [record()]);
    await repository.recordPayment('rent-1');

    expect(
      () => repository.addRentFollowUp(
        'rent-1',
        const RentFollowUpInput(contactMethod: 'Phone', notes: 'Too late.'),
      ),
      throwsA(isA<RentConflictException>()),
    );
    expect(
      () => repository.updateRentRecord(
        'rent-1',
        const RentRecordUpdate(amountDue: 1),
      ),
      throwsA(isA<RentConflictException>()),
    );
  });
}

class RentConflictException implements Exception {
  const RentConflictException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RentRecordUpdate {
  const RentRecordUpdate({this.amountDue});
  final double? amountDue;
}

class _TestInMemoryRentRepository {
  _TestInMemoryRentRepository({required List<RentRecord> records})
    : _records = {for (final r in records) r.id: r};

  final Map<String, RentRecord> _records;
  final Map<String, List<RentFollowUp>> _followUps = {};

  Future<RentFollowUp> addRentFollowUp(
    String id,
    RentFollowUpInput input,
  ) async {
    final record = _records[id];
    if (record == null || record.status == RentStatus.paid) {
      throw const RentConflictException(
        'Cannot add follow-up to paid or missing record',
      );
    }
    final nextStatus = RentStatusPolicy.statusForFollowUp(
      current: record.status,
      input: input,
    );
    final followUp = RentFollowUp(
      id: 'fu_${DateTime.now().millisecondsSinceEpoch}',
      rentRecordId: id,
      handledBy: 'user',
      contactMethod: input.contactMethod,
      notes: input.notes,
      tenantResponse: input.tenantResponse,
      promisedPaymentDate: input.promisedPaymentDate,
      nextFollowUpAt: input.nextFollowUpAt,
      previousStatus: record.status,
      resultingStatus: nextStatus,
      createdAt: DateTime.now(),
    );
    _records[id] = record.copyWith(
      status: nextStatus,
      lastFollowUpAt: followUp.createdAt,
      nextFollowUpAt: followUp.nextFollowUpAt,
    );
    _followUps.putIfAbsent(id, () => []).add(followUp);
    return followUp;
  }

  Future<RentRecord?> getRentRecord(String id) async => _records[id];

  Future<List<RentFollowUp>> getRentFollowUps(String id) async =>
      _followUps[id] ?? [];

  Future<void> recordPayment(String id) async {
    final record = _records[id];
    if (record != null) {
      _records[id] = record.copyWith(status: RentStatus.paid);
    }
  }

  Future<void> updateRentRecord(String id, RentRecordUpdate update) async {
    final record = _records[id];
    if (record == null || record.status == RentStatus.paid) {
      throw const RentConflictException('Cannot update paid record');
    }
    if (update.amountDue != null) {
      _records[id] = record.copyWith(amountDue: update.amountDue!);
    }
  }
}

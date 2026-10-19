import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/domain/rent_status_logic.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/models/rent_follow_up.dart';
import 'package:grihsetu/core/models/rent_record.dart';
import 'package:grihsetu/repositories/rent_repository.dart';

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
      final repository = InMemoryRentRepository(records: [record()]);
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
    final repository = InMemoryRentRepository(records: [record()]);
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

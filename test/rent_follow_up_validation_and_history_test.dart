import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/models/property.dart';
import 'package:grihsetu/core/models/rent_record.dart';
import 'package:grihsetu/core/models/tenant.dart';
import 'package:grihsetu/repositories/rent_repository.dart';
import 'package:grihsetu/screens/rent/add_follow_up_sheet.dart';
import 'package:grihsetu/screens/rent/rent_detail_screen.dart';
import 'package:grihsetu/screens/rent/rent_models.dart';
import 'package:grihsetu/screens/rent/widgets/rent_follow_up_history_item.dart';
import 'package:grihsetu/utils/rent_rules.dart';

/// Controllable fake repository for testing duplicate submission and error lifecycles.
class FakeRentRepository implements RentRepository {
  FakeRentRepository(this.item);

  RentItem item;
  int addFollowUpCalls = 0;
  int markPaidCalls = 0;
  Completer<RentItem>? followUpCompleter;
  Completer<RentItem>? markPaidCompleter;
  bool failNextFollowUp = false;

  @override
  Future<RentItem> addFollowUp(RentFollowUp followUp) async {
    addFollowUpCalls++;
    if (failNextFollowUp) {
      failNextFollowUp = false;
      throw StateError('Simulated repository error');
    }
    if (followUpCompleter != null) {
      return followUpCompleter!.future;
    }
    final updatedRecord = item.record.copyWith(
      status: followUp.outcome == FollowUpOutcome.paid
          ? RentStatus.paid
          : (followUp.outcome == FollowUpOutcome.promisedToPay
                ? RentStatus.promised
                : item.record.status),
      lastFollowUpAt: followUp.timestamp,
      nextFollowUpAt: followUp.nextFollowUpDate,
    );
    item = item.copyWith(
      record: updatedRecord,
      followUps: [followUp, ...item.followUps],
    );
    return item;
  }

  @override
  Future<RentItem> markPaid(PaymentRecord payment) async {
    markPaidCalls++;
    if (markPaidCompleter != null) {
      return markPaidCompleter!.future;
    }
    item = item.copyWith(payments: [payment, ...item.payments]);
    return item;
  }

  @override
  Future<RentItem?> get(String id) async => item;

  @override
  Future<List<RentItem>> list({
    String? propertyId,
    String? unitId,
    String? tenantId,
    String? month,
    RentStatus? status,
  }) async => [item];
}

RentItem createTestRentItem({
  double amountDue = 25000.0,
  List<RentFollowUp> followUps = const [],
  List<PaymentRecord> payments = const [],
}) {
  return RentItem(
    record: RentRecord(
      id: 'rnt_test_01',
      tenantId: 't1',
      propertyId: 'p1',
      unitId: 'u1',
      month: 'October 2026',
      amountDue: amountDue,
      dueDate: DateTime(2026, 10, 5),
      status: RentStatus.due,
    ),
    tenant: const Tenant(
      id: 't1',
      name: 'Rohan Verma',
      phone: '+91 98765 43210',
      propertyId: 'p1',
      unitId: 'u1',
    ),
    property: Property(
      id: 'p1',
      name: 'Greenwood Heights',
      address: 'Gurugram',
      createdAt: DateTime(2025, 1, 1),
    ),
    unit: const Unit(
      id: 'u1',
      propertyId: 'p1',
      unitNumber: '402',
      floor: 4,
      occupancyStatus: 'occupied',
    ),
    followUps: followUps,
    payments: payments,
  );
}

void main() {
  final refDate = DateTime(2026, 10, 5);

  group('GRIH-033 Form Validation Rules (Unit Tests)', () {
    test('missing contact method is rejected', () {
      final res = validateFollowUp(
        method: null,
        outcome: FollowUpOutcome.spokeToTenant,
        note: 'Spoke to tenant regarding delayed payment.',
        currentBalance: 25000.0,
        now: refDate,
      );
      expect(res.isValid, isFalse);
      expect(res.methodError, contains('required'));
    });

    test('missing outcome is rejected', () {
      final res = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: null,
        note: 'Called tenant to follow up on rent.',
        currentBalance: 25000.0,
        now: refDate,
      );
      expect(res.isValid, isFalse);
      expect(res.outcomeError, contains('required'));
    });

    test('empty and whitespace-only notes are rejected', () {
      final emptyRes = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: '',
        currentBalance: 25000.0,
        now: refDate,
      );
      expect(emptyRes.isValid, isFalse);
      expect(emptyRes.noteError, isNotNull);

      final whitespaceRes = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: '         ',
        currentBalance: 25000.0,
        now: refDate,
      );
      expect(whitespaceRes.isValid, isFalse);
      expect(whitespaceRes.noteError, isNotNull);

      final noAnswerWhitespaceRes = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.noAnswer,
        note: '    ',
        currentBalance: 25000.0,
        now: refDate,
      );
      expect(noAnswerWhitespaceRes.isValid, isFalse);
      expect(noAnswerWhitespaceRes.noteError, contains('whitespace'));
    });

    test(
      'valid required fields can be submitted without a next follow-up date',
      () {
        final res = validateFollowUp(
          method: FollowUpMethod.call,
          outcome: FollowUpOutcome.spokeToTenant,
          note: 'Spoke with tenant; confirmed receipt of reminder notice.',
          nextFollowUpDate: null,
          currentBalance: 25000.0,
          now: refDate,
        );
        expect(res.isValid, isTrue);
        expect(res.nextFollowUpDateError, isNull);
      },
    );

    test('next follow-up date must be after today when provided', () {
      final todayRes = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: 'Spoke with tenant; confirmed receipt of reminder notice.',
        nextFollowUpDate: refDate,
        currentBalance: 25000.0,
        now: refDate,
      );
      expect(todayRes.isValid, isFalse);
      expect(todayRes.nextFollowUpDateError, contains('after today'));

      final futureRes = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: 'Spoke with tenant; confirmed receipt of reminder notice.',
        nextFollowUpDate: refDate.add(const Duration(days: 2)),
        currentBalance: 25000.0,
        now: refDate,
      );
      expect(futureRes.isValid, isTrue);
      expect(futureRes.nextFollowUpDateError, isNull);
    });

    test('invalid promise details are rejected', () {
      // Missing promise date
      final noDate = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: null,
        promisedAmount: 10000.0,
        note: 'Tenant promised payment by next week.',
        currentBalance: 25000.0,
        now: refDate,
      );
      expect(noDate.isValid, isFalse);
      expect(noDate.promisedDateError, isNotNull);

      // Past promise date
      final pastDate = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: refDate.subtract(const Duration(days: 1)),
        promisedAmount: 10000.0,
        note: 'Tenant promised payment by next week.',
        currentBalance: 25000.0,
        now: refDate,
      );
      expect(pastDate.isValid, isFalse);
      expect(pastDate.promisedDateError, contains('past'));

      // Amount exceeding balance
      final excessAmount = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: refDate.add(const Duration(days: 3)),
        promisedAmount: 30000.0,
        note: 'Tenant promised payment by next week.',
        currentBalance: 25000.0,
        now: refDate,
      );
      expect(excessAmount.isValid, isFalse);
      expect(
        excessAmount.promisedAmountError,
        contains('cannot exceed balance'),
      );
    });

    test('tenant response validation rejects whitespace-only string', () {
      final res = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: 'Spoke with tenant regarding payment timeline.',
        tenantResponse: '   ',
        currentBalance: 25000.0,
        now: refDate,
      );
      expect(res.isValid, isFalse);
      expect(res.tenantResponseError, contains('whitespace'));
    });
  });

  group('AddFollowUpSheet Form & Duplicate Submission Tests', () {
    testWidgets('missing contact method is rejected when deselected', (
      tester,
    ) async {
      final item = createTestRentItem();
      final repo = FakeRentRepository(item);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddFollowUpSheet(item: item, repository: repo, now: refDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid note
      final noteField = find.byKey(const Key('follow_up_note_field'));
      await tester.enterText(
        noteField,
        'Spoke to tenant regarding payment timeline.',
      );
      await tester.pumpAndSettle();

      // Deselect the Call segment
      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.byKey(const Key('submit_follow_up_button')));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('Follow-up method is required'), findsOneWidget);
      expect(repo.addFollowUpCalls, 0);
    });

    testWidgets(
      'whitespace-only notes are rejected and user can correct them',
      (tester) async {
        final item = createTestRentItem();
        final repo = FakeRentRepository(item);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AddFollowUpSheet(
                item: item,
                repository: repo,
                now: refDate,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter only whitespace in note
        final noteField = find.byKey(const Key('follow_up_note_field'));
        await tester.enterText(noteField, '       ');
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('submit_follow_up_button')));
        await tester.pumpAndSettle();

        // Error shown
        expect(find.textContaining('Note is required'), findsOneWidget);
        expect(repo.addFollowUpCalls, 0);

        // Now correct note
        await tester.enterText(
          noteField,
          'Tenant answered and confirmed payment schedule.',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('submit_follow_up_button')));
        await tester.pumpAndSettle();

        // Successful submission
        expect(repo.addFollowUpCalls, 1);
      },
    );

    testWidgets('submitting without next follow-up date preserves null date', (
      tester,
    ) async {
      final item = createTestRentItem();
      final repo = FakeRentRepository(item);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddFollowUpSheet(item: item, repository: repo, now: refDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final noteField = find.byKey(const Key('follow_up_note_field'));
      await tester.enterText(
        noteField,
        'Routine check-in call with tenant completed.',
      );
      await tester.pumpAndSettle();

      // Next follow-up is None by default
      expect(find.text('Next follow-up date: None'), findsOneWidget);

      await tester.tap(find.byKey(const Key('submit_follow_up_button')));
      await tester.pumpAndSettle();

      expect(repo.addFollowUpCalls, 1);
      expect(repo.item.followUps.first.nextFollowUpDate, isNull);
    });

    testWidgets('duplicate submission protection blocks repeated rapid taps', (
      tester,
    ) async {
      final item = createTestRentItem();
      final repo = FakeRentRepository(item);
      final completer = Completer<RentItem>();
      repo.followUpCompleter = completer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddFollowUpSheet(item: item, repository: repo, now: refDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final noteField = find.byKey(const Key('follow_up_note_field'));
      await tester.enterText(
        noteField,
        'Contacted tenant via call. Discussion completed.',
      );
      await tester.pumpAndSettle();

      // Tap submit first time
      final submitButton = find.byKey(const Key('submit_follow_up_button'));
      await tester.tap(submitButton);
      await tester.pump(); // Start async operation

      // Expect exactly 1 call initiated
      expect(repo.addFollowUpCalls, 1);

      // Loading state indicator should be present
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Rapidly tap submit 3 more times while in progress
      await tester.tap(submitButton, warnIfMissed: false);
      await tester.pump();
      await tester.tap(submitButton, warnIfMissed: false);
      await tester.pump();
      await tester.tap(submitButton, warnIfMissed: false);
      await tester.pump();

      // Still only 1 call
      expect(repo.addFollowUpCalls, 1);

      // Now complete the async repository operation
      completer.complete(
        item.copyWith(
          followUps: [
            RentFollowUp(
              id: 'flw_completed',
              rentRecordId: item.id,
              method: FollowUpMethod.call,
              outcome: FollowUpOutcome.spokeToTenant,
              actor: 'Staff',
              timestamp: refDate,
              note: 'Contacted tenant via call. Discussion completed.',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.addFollowUpCalls, 1);
    });

    testWidgets('failed submission resets submitting state allowing retry', (
      tester,
    ) async {
      final item = createTestRentItem();
      final repo = FakeRentRepository(item);
      repo.failNextFollowUp = true; // First attempt fails

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddFollowUpSheet(item: item, repository: repo, now: refDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final noteField = find.byKey(const Key('follow_up_note_field'));
      await tester.enterText(
        noteField,
        'Tenant contacted. Attempting to record notes.',
      );
      await tester.pumpAndSettle();

      // Tap submit - fails
      await tester.tap(find.byKey(const Key('submit_follow_up_button')));
      await tester.pumpAndSettle();

      expect(repo.addFollowUpCalls, 1);
      expect(find.textContaining('Failed to record follow-up'), findsOneWidget);
      // Spinner is gone, button label restored
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Save follow-up'), findsOneWidget);

      // Tap submit again - succeeds
      await tester.tap(find.byKey(const Key('submit_follow_up_button')));
      await tester.pumpAndSettle();

      expect(repo.addFollowUpCalls, 2);
    });

    testWidgets(
      'payment confirmation step does not trigger write until confirmed',
      (tester) async {
        final item = createTestRentItem();
        final repo = FakeRentRepository(item);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AddFollowUpSheet(
                item: item,
                repository: repo,
                now: refDate,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select Paid outcome
        final outcomeDropdown = find.byKey(
          const Key('follow_up_outcome_dropdown'),
        );
        await tester.tap(outcomeDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Paid').last);
        await tester.pumpAndSettle();

        // Note is required for paid outcome
        final noteField = find.byKey(const Key('follow_up_note_field'));
        await tester.enterText(
          noteField,
          'Tenant paid full rent via online transfer.',
        );
        await tester.pumpAndSettle();

        // Tap 'Proceed to payment'
        final submitButton = find.byKey(const Key('submit_follow_up_button'));
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Should be on payment confirmation screen; no writes yet
        expect(find.text('Confirm payment'), findsOneWidget);
        expect(find.text('Payment summary'), findsOneWidget);
        expect(repo.markPaidCalls, 0);
        expect(repo.addFollowUpCalls, 0);

        // Now tap 'Confirm & record'
        final confirmButton = find.byKey(
          const Key('confirm_payment_submit_button'),
        );
        await tester.ensureVisible(confirmButton);
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        // Both payment and follow-up recorded exactly once
        expect(repo.markPaidCalls, 1);
        expect(repo.addFollowUpCalls, 1);
      },
    );
  });

  group('RentFollowUpHistoryItem Widget Tests', () {
    testWidgets(
      'renders all core fields: handler, timestamp, method, outcome, note',
      (tester) async {
        final followUp = RentFollowUp(
          id: 'flw_01',
          rentRecordId: 'rnt_1',
          method: FollowUpMethod.call,
          outcome: FollowUpOutcome.spokeToTenant,
          actor: 'Priya Sharma',
          timestamp: DateTime(2026, 10, 2, 11, 15),
          note: 'Tenant promised payment by end of week.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RentFollowUpHistoryItem(
                followUp: followUp,
                elapsed: '2 hrs after previous',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Call'), findsOneWidget);
        expect(find.text('Spoke to tenant'), findsOneWidget);
        expect(find.text('By Priya Sharma'), findsOneWidget);
        expect(find.text('2 hrs after previous'), findsOneWidget);
        expect(
          find.text('Tenant promised payment by end of week.'),
          findsOneWidget,
        );
        expect(find.textContaining('2 Oct 2026'), findsOneWidget);
      },
    );

    testWidgets(
      'promise details banner is shown for promise and omitted otherwise',
      (tester) async {
        final promiseFollowUp = RentFollowUp(
          id: 'flw_promise',
          rentRecordId: 'rnt_1',
          method: FollowUpMethod.call,
          outcome: FollowUpOutcome.promisedToPay,
          actor: 'Aakash',
          timestamp: DateTime(2026, 10, 4, 10, 0),
          promisedDate: DateTime(2026, 10, 8),
          promisedAmount: 20000.0,
          note: 'Promised 20k payment.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RentFollowUpHistoryItem(followUp: promiseFollowUp),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Promised ₹20,000 by 8 Oct 2026'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.event_available), findsOneWidget);

        // Ordinary follow-up does not show promise banner
        final normalFollowUp = RentFollowUp(
          id: 'flw_normal',
          rentRecordId: 'rnt_1',
          method: FollowUpMethod.message,
          outcome: FollowUpOutcome.spokeToTenant,
          actor: 'Aakash',
          timestamp: DateTime(2026, 10, 4, 10, 0),
          note: 'Sent WhatsApp reminder.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RentFollowUpHistoryItem(followUp: normalFollowUp),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.event_available), findsNothing);
      },
    );

    testWidgets(
      'next follow-up date is shown when present and omitted when null',
      (tester) async {
        final withNextDate = RentFollowUp(
          id: 'flw_next',
          rentRecordId: 'rnt_1',
          method: FollowUpMethod.visit,
          outcome: FollowUpOutcome.spokeToTenant,
          actor: 'Riya',
          timestamp: DateTime(2026, 10, 3),
          nextFollowUpDate: DateTime(2026, 10, 7),
          note: 'Visited premises; follow-up scheduled.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RentFollowUpHistoryItem(followUp: withNextDate),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Next follow-up: 7 Oct 2026'), findsOneWidget);

        final withoutNextDate = RentFollowUp(
          id: 'flw_no_next',
          rentRecordId: 'rnt_1',
          method: FollowUpMethod.call,
          outcome: FollowUpOutcome.spokeToTenant,
          actor: 'Riya',
          timestamp: DateTime(2026, 10, 3),
          note: 'No further follow-up required.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RentFollowUpHistoryItem(followUp: withoutNextDate),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Next follow-up:'), findsNothing);
      },
    );

    testWidgets(
      'tenant response is rendered when non-empty and omitted when null',
      (tester) async {
        final withResponse = RentFollowUp(
          id: 'flw_resp',
          rentRecordId: 'rnt_1',
          method: FollowUpMethod.call,
          outcome: FollowUpOutcome.spokeToTenant,
          actor: 'Riya',
          timestamp: DateTime(2026, 10, 3),
          tenantResponse: 'Will pay after monthly salary credit.',
          note: 'Noted tenant salary schedule.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RentFollowUpHistoryItem(followUp: withResponse),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Response: Will pay after monthly salary credit.'),
          findsOneWidget,
        );

        // Without response: never shows "Response:" or "null"
        final withoutResponse = RentFollowUp(
          id: 'flw_no_resp',
          rentRecordId: 'rnt_1',
          method: FollowUpMethod.call,
          outcome: FollowUpOutcome.spokeToTenant,
          actor: 'Riya',
          timestamp: DateTime(2026, 10, 3),
          note: 'Noted tenant schedule.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RentFollowUpHistoryItem(followUp: withoutResponse),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Response:'), findsNothing);
        expect(find.textContaining('null'), findsNothing);
      },
    );

    testWidgets('missing optional display values do not show "null" or crash', (
      tester,
    ) async {
      final minimal = RentFollowUp(
        id: 'flw_min',
        rentRecordId: 'rnt_1',
        method: FollowUpMethod.email,
        outcome: FollowUpOutcome.noAnswer,
        actor: '', // blank actor
        timestamp: DateTime(2026, 10, 1),
        note: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RentFollowUpHistoryItem(followUp: minimal)),
        ),
      );
      await tester.pumpAndSettle();

      // Actor falls back to 'Staff'
      expect(find.text('By Staff'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets(
      'long notes wrap cleanly without horizontal overflow at 320px width and 1.5 text scale',
      (tester) async {
        final longNoteFollowUp = RentFollowUp(
          id: 'flw_long',
          rentRecordId: 'rnt_1',
          method: FollowUpMethod.call,
          outcome: FollowUpOutcome.spokeToTenant,
          actor: 'Senior Operational Staff Member In Charge',
          timestamp: DateTime(2026, 10, 5, 14, 30),
          note:
              'This is an extensive follow-up note detailing multiple conversation points with the tenant ' *
              3,
          tenantResponse: 'The tenant explained their current banking issues and requested a temporary grace period.',
          nextFollowUpDate: DateTime(2026, 10, 15),
        );

        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: RentFollowUpHistoryItem(
                    followUp: longNoteFollowUp,
                    elapsed: '1 day after previous',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No overflow exception thrown
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining('Senior Operational Staff Member'),
          findsOneWidget,
        );
      },
    );
  });

  group('RentDetailScreen Integration with RentFollowUpHistoryItem Tests', () {
    testWidgets(
      'RentDetailScreen renders RentFollowUpHistoryItem for every history entry',
      (tester) async {
        final followUp1 = RentFollowUp(
          id: 'flw_101',
          rentRecordId: 'rnt_test_01',
          method: FollowUpMethod.call,
          outcome: FollowUpOutcome.noAnswer,
          actor: 'Staff A',
          timestamp: DateTime(2026, 10, 1, 10, 0),
          note: 'First call rang out.',
        );
        final followUp2 = RentFollowUp(
          id: 'flw_102',
          rentRecordId: 'rnt_test_01',
          method: FollowUpMethod.message,
          outcome: FollowUpOutcome.promisedToPay,
          actor: 'Staff B',
          timestamp: DateTime(2026, 10, 3, 14, 0),
          promisedDate: DateTime(2026, 10, 6),
          promisedAmount: 25000.0,
          note: 'Sent WhatsApp text; tenant promised payment.',
        );

        final item = createTestRentItem(followUps: [followUp1, followUp2]);
        final repo = FakeRentRepository(item);

        await tester.pumpWidget(
          MaterialApp(
            home: RentDetailScreen(item: item, repository: repo, now: refDate),
          ),
        );
        await tester.pumpAndSettle();

        // History header shows count 2
        expect(find.text('Follow-up history (2)'), findsOneWidget);

        // Verify RentFollowUpHistoryItem widgets are rendered
        expect(find.byType(RentFollowUpHistoryItem), findsNWidgets(2));
        expect(
          find.byKey(const Key('rent_follow_up_history_item_flw_101')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('rent_follow_up_history_item_flw_102')),
          findsOneWidget,
        );
      },
    );

    testWidgets('RentDetailScreen shows empty state when no follow-ups exist', (
      tester,
    ) async {
      final item = createTestRentItem(followUps: []);
      final repo = FakeRentRepository(item);

      await tester.pumpWidget(
        MaterialApp(
          home: RentDetailScreen(item: item, repository: repo, now: refDate),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No follow-ups recorded'), findsOneWidget);
      expect(find.byType(RentFollowUpHistoryItem), findsNothing);
    });
  });
}

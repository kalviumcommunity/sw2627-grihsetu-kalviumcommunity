import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/models/rent_record.dart';
import 'package:grihsetu/repositories/rent_repository.dart';
import 'package:grihsetu/screens/rent/add_follow_up_sheet.dart';
import 'package:grihsetu/screens/rent/rent_detail_screen.dart';
import 'package:grihsetu/screens/rent/rent_list_screen.dart';
import 'package:grihsetu/screens/rent/rent_models.dart';
import 'package:grihsetu/utils/rent_rules.dart';

void main() {
  group('GRIH-032 Rent Management Tests', () {
    // -------------------------------------------------------------
    // Test 1: rent_rules (effectiveStatus on due-date boundary, balance, broken promises)
    // -------------------------------------------------------------
    test('1. rent_rules: effectiveStatus on due-date boundary, balance, and broken promises', () {
      final dueDate = DateTime(2026, 10, 5);
      final record = RentRecord(
        id: 'r1',
        tenantId: 't1',
        propertyId: 'p1',
        unitId: 'u1',
        month: 'October 2026',
        amountDue: 25000.0,
        dueDate: dueDate,
        status: RentStatus.due,
      );

      // (a) On due date (boundary): not overdue
      final onDueDate = DateTime(2026, 10, 5, 12, 0);
      expect(effectiveStatus(record, onDueDate), RentStatus.due);

      // Day before due date: not overdue
      final beforeDueDate = DateTime(2026, 10, 4);
      expect(effectiveStatus(record, beforeDueDate), RentStatus.due);

      // Day after due date: overdue
      final afterDueDate = DateTime(2026, 10, 6, 9, 0);
      expect(effectiveStatus(record, afterDueDate), RentStatus.overdue);

      // (b) Balance computation
      expect(balance(record), 25000.0);
      final partialPayment = PaymentRecord(
        id: 'pay_1',
        rentRecordId: 'r1',
        amount: 10000.0,
        date: DateTime(2026, 10, 2),
        mode: PaymentMode.upi,
        actor: 'Staff',
      );
      expect(balance(record, [partialPayment]), 15000.0);

      final fullPayment = PaymentRecord(
        id: 'pay_2',
        rentRecordId: 'r1',
        amount: 25000.0,
        date: DateTime(2026, 10, 3),
        mode: PaymentMode.bankTransfer,
        actor: 'Staff',
      );
      expect(balance(record, [fullPayment]), 0.0);
      expect(
        effectiveStatus(record, afterDueDate, [fullPayment]),
        RentStatus.paid,
      );

      // (c) Broken promises calculation
      final followUpActivePromise = RentFollowUp(
        id: 'flw_1',
        rentRecordId: 'r1',
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        actor: 'Staff',
        timestamp: DateTime(2026, 10, 1),
        promisedDate: DateTime(2026, 10, 8),
        promisedAmount: 25000.0,
      );
      final followUpBrokenPromise = RentFollowUp(
        id: 'flw_2',
        rentRecordId: 'r1',
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        actor: 'Staff',
        timestamp: DateTime(2026, 9, 20),
        promisedDate: DateTime(2026, 9, 25),
        promisedAmount: 25000.0,
      );

      final history = [followUpActivePromise, followUpBrokenPromise];
      // On Oct 5: the promise for Sept 25 is broken, while the promise for Oct 8 is still active
      expect(brokenPromises(history, DateTime(2026, 10, 5)), 1);

      // On Oct 9: both promises are broken
      expect(brokenPromises(history, DateTime(2026, 10, 9)), 2);

      // On Sept 24: neither promise is broken
      expect(brokenPromises(history, DateTime(2026, 9, 24)), 0);
    });

    // -------------------------------------------------------------
    // Test 2: follow-up validation (promise needs date and amount, amount cannot exceed balance, note rules)
    // -------------------------------------------------------------
    test('2. follow-up validation: promise needs date and amount, amount cannot exceed balance, note rules', () {
      final now = DateTime(2026, 10, 5);
      const balance = 20000.0;

      // (a) Promise needs date and amount
      final missingDateResult = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: null,
        promisedAmount: 15000.0,
        note: 'Spoke with tenant regarding payment timeline.',
        currentBalance: balance,
        now: now,
      );
      expect(missingDateResult.isValid, isFalse);
      expect(missingDateResult.promisedDateError, isNotNull);

      final missingAmountResult = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: DateTime(2026, 10, 10),
        promisedAmount: null,
        note: 'Spoke with tenant regarding payment timeline.',
        currentBalance: balance,
        now: now,
      );
      expect(missingAmountResult.isValid, isFalse);
      expect(missingAmountResult.promisedAmountError, isNotNull);

      // (b) Amount cannot exceed balance
      final excessAmountResult = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: DateTime(2026, 10, 10),
        promisedAmount: 25000.0,
        note: 'Spoke with tenant regarding payment timeline.',
        currentBalance: balance,
        now: now,
      );
      expect(excessAmountResult.isValid, isFalse);
      expect(excessAmountResult.promisedAmountError, contains('cannot exceed'));

      // (c) Note rules:
      // When outcome is NOT noAnswer, note must be 10-300 characters
      final shortNoteResult = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: 'Too short', // 9 characters
        currentBalance: balance,
        now: now,
      );
      expect(shortNoteResult.isValid, isFalse);
      expect(shortNoteResult.noteError, contains('at least 10'));

      final tooLongNoteResult = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: 'A' * 301,
        currentBalance: balance,
        now: now,
      );
      expect(tooLongNoteResult.isValid, isFalse);
      expect(tooLongNoteResult.noteError, contains('cannot exceed 300'));

      // When outcome IS noAnswer, note is optional
      final noAnswerEmptyNoteResult = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.noAnswer,
        note: '',
        currentBalance: balance,
        now: now,
      );
      expect(noAnswerEmptyNoteResult.isValid, isTrue);

      // Valid full promise passes
      final validPromiseResult = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: DateTime(2026, 10, 12),
        promisedAmount: 20000.0,
        note: 'Tenant promised to transfer full balance by next Monday.',
        currentBalance: balance,
        now: now,
      );
      expect(validPromiseResult.isValid, isTrue);
    });

    // -------------------------------------------------------------
    // Test 3: list filtering and search
    // -------------------------------------------------------------
    testWidgets('3. list filtering and search', (tester) async {
      final repo = InMemoryRentRepository(simulatedDelay: Duration.zero);

      await tester.pumpWidget(
        MaterialApp(
          home: RentListScreen(repository: repo, now: DateTime(2026, 10, 6)),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 3 seeded records are rendered
      expect(find.byKey(const Key('rent_row_rnt_3001')), findsOneWidget);
      expect(find.byKey(const Key('rent_row_rnt_3002')), findsOneWidget);
      expect(find.byKey(const Key('rent_row_rnt_3003')), findsOneWidget);

      // (a) Search by tenant name
      final searchField = find.byKey(const Key('rent_search_field'));
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Anita');
      await tester.pumpAndSettle();

      // Only Anita Desai (rnt_3003) should remain
      expect(find.byKey(const Key('rent_row_rnt_3003')), findsOneWidget);
      expect(find.byKey(const Key('rent_row_rnt_3001')), findsNothing);
      expect(find.byKey(const Key('rent_row_rnt_3002')), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rent_row_rnt_3001')), findsOneWidget);

      // (b) Status filter chip: tap 'Paid'
      final paidChip = find.byKey(const Key('rent_filter_chip_paid'));
      expect(paidChip, findsOneWidget);

      await tester.tap(paidChip);
      await tester.pumpAndSettle();

      // Only rnt_3003 (paid) is visible
      expect(find.byKey(const Key('rent_row_rnt_3003')), findsOneWidget);
      expect(find.byKey(const Key('rent_row_rnt_3001')), findsNothing);

      // Tap 'All' chip
      await tester.tap(find.byKey(const Key('rent_filter_chip_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rent_row_rnt_3001')), findsOneWidget);
      expect(find.byKey(const Key('rent_row_rnt_3002')), findsOneWidget);
      expect(find.byKey(const Key('rent_row_rnt_3003')), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test 4: adding a follow-up changes the status and shows in the timeline
    // -------------------------------------------------------------
    testWidgets(
      '4. adding a follow-up changes the status and shows in the timeline',
      (tester) async {
        final repo = InMemoryRentRepository(simulatedDelay: Duration.zero);
        final item = await repo.get('rnt_3001');
        expect(item, isNotNull);

        await tester.pumpWidget(
          MaterialApp(
            home: RentDetailScreen(
              item: item!,
              repository: repo,
              now: DateTime(2026, 10, 5), // on due date
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially 1 follow-up
        expect(find.text('Follow-up history (1)'), findsOneWidget);

        // Tap 'Add follow-up' button
        final addFollowUpButton = find.byKey(
          const Key('rent_detail_add_follow_up_button'),
        );
        expect(addFollowUpButton, findsOneWidget);
        await tester.tap(addFollowUpButton);
        await tester.pumpAndSettle();

        // Ensure sheet opened
        expect(find.byType(AddFollowUpSheet), findsOneWidget);

        // Change outcome to 'Promised to pay'
        final outcomeDropdown = find.byKey(
          const Key('follow_up_outcome_dropdown'),
        );
        await tester.tap(outcomeDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Promised to pay').last);
        await tester.pumpAndSettle();

        // Enter a valid note
        final noteField = find.byKey(const Key('follow_up_note_field'));
        await tester.ensureVisible(noteField);
        await tester.enterText(
          noteField,
          'Spoke to tenant Priya. Promised to pay full rent on 8th.',
        );
        await tester.pumpAndSettle();

        // Submit follow-up
        final submitButton = find.byKey(const Key('submit_follow_up_button'));
        await tester.ensureVisible(submitButton);
        await tester.pumpAndSettle();
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Verify the sheet closed, timeline now shows 2 follow-ups, and status changed to Promised
        expect(find.byType(AddFollowUpSheet), findsNothing);
        expect(find.text('Follow-up history (2)'), findsOneWidget);
        expect(find.text('Promised to pay'), findsWidgets);
        expect(
          find.text('Spoke to tenant Priya. Promised to pay full rent on 8th.'),
          findsOneWidget,
        );
      },
    );

    // -------------------------------------------------------------
    // Test 5: the owner role sees no action buttons
    // -------------------------------------------------------------
    testWidgets('5. the owner role sees no action buttons', (tester) async {
      final repo = InMemoryRentRepository(simulatedDelay: Duration.zero);
      final item = await repo.get('rnt_3001');
      expect(item, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: RentDetailScreen(
            item: item!,
            repository: repo,
            readOnly: true, // Owner role is read-only
            now: DateTime(2026, 10, 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify neither 'Add follow-up' nor 'Mark as paid' buttons are rendered
      expect(
        find.byKey(const Key('rent_detail_add_follow_up_button')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('rent_detail_mark_paid_button')),
        findsNothing,
      );

      // Detail information is still visible
      expect(find.text(item.tenantName), findsWidgets);
      expect(find.text('Payment & Settlement'), findsOneWidget);
      expect(find.text('Follow-up history (1)'), findsOneWidget);
    });
  });
}

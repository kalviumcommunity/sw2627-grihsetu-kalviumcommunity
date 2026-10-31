import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/user_role.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/fixtures/sample_fixtures.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/repositories/complaint_store.dart';
import 'package:grihsetu/repositories/rent_repository.dart';
import 'package:grihsetu/screens/complaints/complaint_detail_screen.dart';
import 'package:grihsetu/screens/rent/rent_models.dart';
import 'package:grihsetu/theme/app_theme.dart';
import 'package:grihsetu/utils/attention_rules.dart';
import 'package:grihsetu/utils/complaint_query.dart';

import '../support/app_harness.dart';

void main() {
  test(
    'rent promise, payment, search filters, and attention counts agree',
    () async {
      final rentRepository = InMemoryRentRepository(
        simulatedDelay: Duration.zero,
      );
      final item = (await rentRepository.list()).firstWhere(
        (candidate) => candidate.id == 'rnt_3004',
      );
      final promise = RentFollowUp(
        id: 'flw_grih_049',
        rentRecordId: item.id,
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        actor: 'Vikram Malhotra',
        timestamp: DateTime(2026, 10, 6, 14),
        promisedDate: DateTime(2026, 10, 8),
        promisedAmount: item.balance,
        note: 'Tenant promised full payment after returning to Gurugram.',
      );
      final promised = await rentRepository.addFollowUp(promise);
      expect(promised.status, RentStatus.promised);
      expect(promised.lastFollowUp?.promisedDate, isNotNull);
      expect(promised.lastFollowUp?.promisedAmount, item.balance);

      final paid = await rentRepository.markPaid(
        PaymentRecord(
          id: 'pay_grih_049',
          rentRecordId: item.id,
          amount: item.balance,
          date: DateTime(2026, 10, 8),
          mode: PaymentMode.bankTransfer,
          actor: 'Vikram Malhotra',
        ),
      );
      expect(paid.status, RentStatus.paid);
      expect(paid.balance, 0);

      final complaints = SampleFixtures.sampleComplaints;
      final open = applyFilter(
        complaints,
        const ComplaintFilter(statuses: {ComplaintStatus.open}),
      );
      expect(
        open.map((complaint) => complaint.status),
        everyElement(ComplaintStatus.open),
      );

      final attention = analyzeAttention(
        complaints: complaints,
        rentRecords: SampleFixtures.sampleRentRecords,
        now: DateTime(2026, 10, 10, 12),
      );
      const exactFilterTypes = {
        AttentionType.unassigned,
        AttentionType.urgentUnvisited,
        AttentionType.waitingForParts,
        AttentionType.unconfirmedResolution,
        AttentionType.reopened,
      };
      for (final item in attention.items.where(
        (item) => exactFilterTypes.contains(item.type),
      )) {
        final filtered = applyFilter(complaints, item.targetFilter!);
        expect(
          filtered.map((complaint) => complaint.id).toSet(),
          item.matchedComplaints.map((complaint) => complaint.id).toSet(),
        );
        expect(filtered.length, item.count);
      }
    },
  );

  testWidgets('owner complaint detail exposes no mutation actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final complaint = SampleFixtures.sampleComplaints.first;
    ComplaintStore.resetInstance(
      ComplaintStore(initialComplaints: [complaint]),
    );
    addTearDown(ComplaintStore.resetInstance);
    final repository = InMemoryComplaintRepository(
      initialComplaints: [complaint],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(webFonts: false),
        home: ComplaintDetailScreen(
          complaint: complaint,
          complaintRepository: repository,
          userRole: UserRole.owner,
        ),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('assign_technician_button')), findsNothing);
    expect(find.byKey(const Key('change_priority_button')), findsNothing);
    expect(find.byKey(const Key('staff_cancel_button')), findsNothing);
    expect(find.byKey(const Key('tenant_confirm_button')), findsNothing);
  });
}

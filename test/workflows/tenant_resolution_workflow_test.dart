import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/repositories/complaint_store.dart';
import 'package:grihsetu/utils/app_clock.dart';

void main() {
  setUp(() {
    AppClock.current = FixedClock(DateTime(2026, 10, 7, 9));
  });
  tearDown(AppClock.reset);

  test(
    'tenant confirms a resolution or reopens it with repeat history',
    () async {
      final confirmStore = ComplaintStore(initialComplaints: const []);
      addTearDown(confirmStore.dispose);
      final confirmRepo = InMemoryComplaintRepository(
        initialComplaints: [_resolved('cmp_confirm')],
        store: confirmStore,
      );
      final closed = await confirmRepo.changeStatus(
        const StatusChange(
          complaintId: 'cmp_confirm',
          to: ComplaintStatus.closed,
          actor: 'ten_001',
          role: 'Tenant',
          tenantConfirmed: true,
          note: 'Tenant confirmed that the repair is complete.',
        ),
      );
      expect(closed.status, ComplaintStatus.closed);
      expect(
        confirmStore.getEvents(closed.id).last.rawEventType,
        'closed_with_tenant_confirmation',
      );

      final reopenStore = ComplaintStore(initialComplaints: const []);
      addTearDown(reopenStore.dispose);
      final reopenRepo = InMemoryComplaintRepository(
        initialComplaints: [_resolved('cmp_not_fixed')],
        store: reopenStore,
      );
      final reopened = await reopenRepo.changeStatus(
        const StatusChange(
          complaintId: 'cmp_not_fixed',
          to: ComplaintStatus.reopened,
          actor: 'ten_001',
          role: 'Tenant',
          reason: 'Problem came back',
          note: 'The pipe started leaking again after the pressure increased.',
        ),
      );
      expect(reopened.status, ComplaintStatus.reopened);
      expect(reopened.reopenCount, 1);
      expect(reopened.visitCount, 2);
      expect(reopened.isRepeatVisit, isTrue);
      expect(
        reopenStore.getEvents(reopened.id).last.metadata['reason'],
        'Problem came back',
      );
    },
  );
}

Complaint _resolved(String id) => Complaint(
  id: id,
  title: 'Kitchen pipe leak',
  description: 'Water was leaking below the kitchen sink cabinet.',
  category: ComplaintCategory.plumbing,
  priority: ComplaintPriority.high,
  status: ComplaintStatus.resolved,
  propertyId: 'prop_001',
  unitId: 'unit_101',
  tenantId: 'ten_001',
  currentTechnicianId: 'tech_1',
  visitCount: 1,
  createdBy: 'ten_001',
  createdAt: DateTime(2026, 10, 5, 9),
  resolvedAt: DateTime(2026, 10, 6, 11),
);

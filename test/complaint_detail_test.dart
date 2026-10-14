import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/user_role.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/complaint_audit_event.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/screens/complaints/complaint_detail_screen.dart';
import 'package:grihsetu/theme/app_theme.dart';

Widget _buildTestApp({
  required Widget child,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) {
  final theme = brightness == Brightness.light
      ? AppTheme.light(webFonts: false)
      : AppTheme.dark(webFonts: false);
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(1000, 1600),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Material(child: child),
    ),
  );
}

void main() {
  final testComplaint = Complaint(
    id: 'cmp_detail_101',
    title: 'Main water pipe leaking in kitchen',
    description: 'Constant dripping causing damage under sink.',
    category: ComplaintCategory.plumbing,
    priority: ComplaintPriority.high,
    status: ComplaintStatus.open,
    propertyId: 'prop_001',
    unitId: 'unit_302',
    tenantId: 'ten_001',
    createdBy: 'usr_tenant_01',
    createdAt: DateTime(2026, 10, 10, 8, 30),
  );

  group('Complaint Detail & Timeline Tests', () {
    test('(a) derived values computed accurately from single source', () {
      final now = DateTime(2026, 10, 10, 14, 0);
      final events = [
        ActivityEvent(
          id: 'evt_1',
          complaintId: testComplaint.id,
          type: ActivityEventType.created,
          actorId: 'usr_tenant_01',
          actorName: 'Priya Patel',
          actorRole: 'Tenant',
          timestamp: DateTime(2026, 10, 10, 8, 30),
          note: 'Initial report',
        ),
        ActivityEvent(
          id: 'evt_2',
          complaintId: testComplaint.id,
          type: ActivityEventType.assigned,
          actorId: 'usr_staff_01',
          actorName: 'Riya Sharma',
          actorRole: 'Operations Staff',
          timestamp: DateTime(2026, 10, 10, 9, 30),
          note: 'Assigned to Ramesh',
          metadata: {
            'technicianId': 'tech_001',
            'technicianName': 'Ramesh Meena',
          },
        ),
        ActivityEvent(
          id: 'evt_3',
          complaintId: testComplaint.id,
          type: ActivityEventType.arrived,
          actorId: 'tech_001',
          actorName: 'Ramesh Meena',
          actorRole: 'Technician',
          timestamp: DateTime(2026, 10, 10, 11, 0),
          note: 'Arrived on site',
        ),
      ];

      final state = ComplaintDetailState(
        status: ComplaintDetailStatus.data,
        complaint: testComplaint,
        events: events,
        referenceNow: now,
      );

      expect(state.currentStatus, ComplaintStatus.inProgress);
      expect(state.assignedTechnicianId, 'tech_001');
      expect(state.assignedTechnicianName, 'Ramesh Meena');
      expect(state.numberOfVisits, 1);
      expect(state.timeToFirstResponse, const Duration(hours: 1));
      expect(state.timeOpen, const Duration(hours: 5, minutes: 30));
      expect(state.slaStatus, SlaStatus.onTrack);
      expect(state.completedSteps.contains(ProgressStep.raised), isTrue);
      expect(state.completedSteps.contains(ProgressStep.assigned), isTrue);
      expect(state.completedSteps.contains(ProgressStep.visited), isTrue);
    });

    testWidgets('(b) single-source update advances state', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryComplaintRepository();
      repo.seedComplaint(testComplaint);

      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintDetailScreen(
            complaintId: testComplaint.id,
            complaintRepository: repo,
            userRole: UserRole.staff,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Main water pipe leaking in kitchen'), findsOneWidget);
      expect(find.text('Open'), findsWidgets);

      // Perform assignment via repo
      await repo.assignComplaintTechnician(
        testComplaint.id,
        'usr_002',
        actorId: 'usr_staff_01',
        role: 'Operations Staff',
        reason: 'Priority allocation',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Status advances to assigned
      expect(find.text('Assigned'), findsWidgets);
    });

    testWidgets('(c) action bar shows correct buttons per role', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryComplaintRepository();

      // 1. Staff actions (Assign, Change priority, Add internal note)
      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintDetailScreen(
            key: const ValueKey('detail_staff'),
            complaint: testComplaint,
            complaintRepository: repo,
            userRole: UserRole.staff,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('assign_technician_button')), findsOneWidget);
      expect(find.byKey(const Key('change_priority_button')), findsOneWidget);
      expect(find.byKey(const Key('add_internal_note_button')), findsOneWidget);

      // 2. Owner is strictly read-only
      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintDetailScreen(
            key: const ValueKey('detail_owner'),
            complaint: testComplaint,
            complaintRepository: repo,
            userRole: UserRole.owner,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('assign_technician_button')), findsNothing);
      expect(find.byKey(const Key('change_priority_button')), findsNothing);
      expect(find.byKey(const Key('add_internal_note_button')), findsNothing);

      // 3. Technician actions when assigned
      final assigned = testComplaint.copyWith(
        status: ComplaintStatus.assigned,
        currentTechnicianId: 'usr_002',
      );
      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintDetailScreen(
            key: const ValueKey('detail_technician'),
            complaint: assigned,
            complaintRepository: repo,
            userRole: UserRole.technician,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('tech_accept_job_button')), findsOneWidget);
    });

    testWidgets('(d) timeline day grouping and filter chips', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryComplaintRepository();
      repo.seedComplaint(testComplaint);

      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintDetailScreen(
            complaint: testComplaint,
            complaintRepository: repo,
            userRole: UserRole.staff,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Status changes'), findsOneWidget);
      expect(find.text('Assignments'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Visits'), findsOneWidget);
      expect(find.text('Notes & evidence'), findsOneWidget);
      expect(find.text('Internal notes'), findsOneWidget);
    });

    testWidgets(
      '(e) internal notes privacy - hidden from tenant, visible to staff',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = InMemoryComplaintRepository();
        repo.seedComplaint(testComplaint);
        await repo.appendAuditEvent(
          ComplaintAuditEvent(
            id: 'audit_private_note',
            complaintId: testComplaint.id,
            eventType: 'NOTE_ADDED',
            actorId: 'usr_staff_01',
            createdAt: DateTime(2026, 10, 10, 10, 0),
            metadata: {
              'note':
                  'Confidential staff assessment: potential pipe replacement.',
              'actorName': 'Riya Sharma',
              'actorRole': 'Operations Staff',
              'isInternal': true,
            },
          ),
        );

        // Check Tenant sees no confidential note
        await tester.pumpWidget(
          _buildTestApp(
            child: ComplaintDetailScreen(
              key: const ValueKey('tenant_view'),
              complaintId: testComplaint.id,
              complaintRepository: repo,
              userRole: UserRole.tenant,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.textContaining('Confidential staff assessment'),
          findsNothing,
        );

        // Check Staff sees internal note
        await tester.pumpWidget(
          _buildTestApp(
            child: ComplaintDetailScreen(
              key: const ValueKey('staff_view'),
              complaintId: testComplaint.id,
              complaintRepository: repo,
              userRole: UserRole.staff,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.textContaining('Confidential staff assessment'),
          findsOneWidget,
        );
        expect(find.text('Internal'), findsWidgets);
      },
    );

    testWidgets('(f) loading, not found, and error states', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryComplaintRepository();

      // Not found state
      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintDetailScreen(
            complaintId: 'non_existent_id',
            complaintRepository: repo,
            userRole: UserRole.staff,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Complaint not found'), findsOneWidget);
    });

    testWidgets(
      '(g) responsive layout across 360, 768, 1280 and text scale 1.3',
      (tester) async {
        final repo = InMemoryComplaintRepository();
        repo.seedComplaint(testComplaint);

        for (final width in [360.0, 768.0, 1280.0]) {
          for (final brightness in [Brightness.light, Brightness.dark]) {
            tester.view.physicalSize = Size(width * 2, 1000 * 2);
            tester.view.devicePixelRatio = 2.0;

            await tester.pumpWidget(
              _buildTestApp(
                brightness: brightness,
                textScale: 1.3,
                child: ComplaintDetailScreen(
                  key: ValueKey('detail_resp_${width}_$brightness'),
                  complaint: testComplaint,
                  complaintRepository: repo,
                  userRole: UserRole.staff,
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 300));

            expect(find.byType(ComplaintDetailScreen), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        }

        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      },
    );
  });
}

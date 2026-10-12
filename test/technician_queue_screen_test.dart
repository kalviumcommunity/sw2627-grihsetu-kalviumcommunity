import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/app_shell.dart';
import 'package:grihsetu/core/enums/enums.dart';
import 'package:grihsetu/core/models/models.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/screens/complaints/complaint_detail_screen.dart';
import 'package:grihsetu/screens/complaints/technician_queue_screen.dart';
import 'package:grihsetu/services/auth_service.dart';
import 'package:grihsetu/widgets/complaint_card.dart';
import 'package:grihsetu/widgets/empty_state.dart';
import 'package:grihsetu/widgets/error_state.dart';
import 'package:grihsetu/widgets/section_header.dart';
import 'package:grihsetu/widgets/skeleton_box.dart';

class TestTechnicianComplaintRepository implements ComplaintRepository {
  TestTechnicianComplaintRepository();

  final StreamController<List<Complaint>> _controller =
      StreamController<List<Complaint>>.broadcast();

  String? lastRequestedTechnicianId;

  void emitData(List<Complaint> data) => _controller.add(data);
  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<List<Complaint>> watchComplaints({
    String? propertyId,
    String? unitId,
    String? tenantId,
  }) => _controller.stream;

  @override
  Stream<List<Complaint>> watchAssignedComplaints({
    required String technicianId,
  }) {
    lastRequestedTechnicianId = technicianId;
    return _controller.stream;
  }

  @override
  Future<Complaint> createComplaint(CreateComplaintInput input) async {
    throw UnimplementedError();
  }

  void dispose() => _controller.close();
}

class FakeUserProvider implements AuthenticatedUserProvider {
  FakeUserProvider(this.mockUser);

  final User? mockUser;

  @override
  User? get currentUser => mockUser;
}

void main() {
  const testTechnicianProfile = AppUser(
    id: 'tech_001',
    name: 'Suresh Kumar',
    email: 'suresh@grihsetu.local',
    role: UserRole.technician,
    isActive: true,
    createdAt: null,
  );

  final urgentComplaint = Complaint(
    id: 'c_urgent_1',
    title: 'Gas line smell in kitchen',
    description: 'Strong smell of gas near meter.',
    category: ComplaintCategory.appliance,
    priority: ComplaintPriority.urgent,
    status: ComplaintStatus.assigned,
    currentTechnicianId: 'tech_001',
    propertyId: 'prop_001',
    unitId: 'unit_101',
    tenantId: 'ten_001',
    createdBy: 'ops_1',
    createdAt: DateTime.utc(2026, 10, 8, 9, 0),
  );

  final inProgressComplaint = Complaint(
    id: 'c_prog_1',
    title: 'Corridor light fixture broken',
    description: 'Wiring exposed after fixture fell.',
    category: ComplaintCategory.electrical,
    priority: ComplaintPriority.medium,
    status: ComplaintStatus.inProgress,
    currentTechnicianId: 'tech_001',
    propertyId: 'prop_001',
    unitId: 'unit_204',
    tenantId: 'ten_002',
    createdBy: 'ops_1',
    createdAt: DateTime.utc(2026, 10, 8, 8, 30),
  );

  final otherActiveComplaint = Complaint(
    id: 'c_other_1',
    title: 'Balcony drainage blocked',
    description: 'Slow drainage after rains.',
    category: ComplaintCategory.plumbing,
    priority: ComplaintPriority.low,
    status: ComplaintStatus.assigned,
    currentTechnicianId: 'tech_001',
    propertyId: 'prop_002',
    unitId: 'unit_505',
    tenantId: 'ten_003',
    createdBy: 'ops_1',
    createdAt: DateTime.utc(2026, 10, 8, 10, 15),
  );

  group('TechnicianQueueScreen - UI States', () {
    testWidgets('renders loading skeleton while stream is waiting', (
      tester,
    ) async {
      final repo = TestTechnicianComplaintRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: TechnicianQueueScreen(
            profile: testTechnicianProfile,
            complaintRepository: repo,
          ),
        ),
      );

      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
      expect(find.byType(ComplaintCard), findsNothing);

      repo.dispose();
    });

    testWidgets(
      'renders technician empty state when queue has 0 active assignments',
      (tester) async {
        final repo = TestTechnicianComplaintRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: TechnicianQueueScreen(
              profile: testTechnicianProfile,
              complaintRepository: repo,
            ),
          ),
        );

        repo.emitData([]);
        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text("You're all caught up"), findsOneWidget);
        expect(
          find.text('No active complaints are assigned to you.'),
          findsOneWidget,
        );
        // Technicians must NOT be prompted to register complaints
        expect(find.text('Register complaint'), findsNothing);
        expect(find.byType(SkeletonList), findsNothing);
        expect(find.byType(ComplaintCard), findsNothing);

        repo.dispose();
      },
    );

    testWidgets(
      'renders complaint cards and groups into Urgent & High, In Progress, and Other Assigned Work',
      (tester) async {
        final repo = TestTechnicianComplaintRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: TechnicianQueueScreen(
              profile: testTechnicianProfile,
              complaintRepository: repo,
            ),
          ),
        );

        repo.emitData([
          urgentComplaint,
          inProgressComplaint,
          otherActiveComplaint,
        ]);
        await tester.pumpAndSettle();

        // 3 complaint cards
        expect(find.byType(ComplaintCard), findsNWidgets(3));
        expect(find.text('Gas line smell in kitchen'), findsOneWidget);
        expect(find.text('Corridor light fixture broken'), findsOneWidget);
        expect(find.text('Balcony drainage blocked'), findsOneWidget);

        // Group headers
        expect(find.text('Urgent & High Priority'), findsOneWidget);
        expect(
          find.widgetWithText(SectionHeader, 'In Progress'),
          findsOneWidget,
        );
        expect(find.text('Other Assigned Work'), findsOneWidget);

        // Status and priority badges are visible
        expect(find.text('Urgent'), findsOneWidget);
        expect(
          find.widgetWithText(ComplaintStatusBadge, 'In Progress'),
          findsOneWidget,
        );
        expect(find.text('Low'), findsOneWidget);

        repo.dispose();
      },
    );

    testWidgets(
      'renders user-friendly error state on stream failure with retry',
      (tester) async {
        final repo = TestTechnicianComplaintRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: TechnicianQueueScreen(
              profile: testTechnicianProfile,
              complaintRepository: repo,
            ),
          ),
        );

        repo.emitError(
          const ComplaintFailure(
            ComplaintFailureCode.network,
            'Unable to reach service.',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ErrorState), findsOneWidget);
        expect(find.text('Unable to reach service.'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Verify retry action resubscribes
        await tester.tap(find.text('Retry'));
        await tester.pump();

        repo.emitData([urgentComplaint]);
        await tester.pumpAndSettle();

        expect(find.byType(ErrorState), findsNothing);
        expect(find.byType(ComplaintCard), findsOneWidget);

        repo.dispose();
      },
    );

    testWidgets('tapping a complaint card opens ComplaintDetailScreen', (
      tester,
    ) async {
      final repo = TestTechnicianComplaintRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: TechnicianQueueScreen(
            profile: testTechnicianProfile,
            complaintRepository: repo,
          ),
        ),
      );

      repo.emitData([urgentComplaint]);
      await tester.pumpAndSettle();

      final cardFinder = find.byType(ComplaintCard);
      expect(cardFinder, findsOneWidget);

      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      // On detail screen
      expect(find.byType(ComplaintDetailScreen), findsOneWidget);
      expect(find.text('Complaint details'), findsOneWidget);
      expect(find.text('Gas line smell in kitchen'), findsOneWidget);
      expect(find.text('Strong smell of gas near meter.'), findsOneWidget);

      // Back navigation
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(ComplaintDetailScreen), findsNothing);
      expect(find.byType(TechnicianQueueScreen), findsOneWidget);

      repo.dispose();
    });

    testWidgets(
      'unauthorized identity renders access restricted and avoids query',
      (tester) async {
        final repo = TestTechnicianComplaintRepository();

        // Non-technician profile (tenant)
        const tenantProfile = AppUser(
          id: 'u_tenant',
          name: 'Tenant User',
          email: 'tenant@grihsetu.local',
          role: UserRole.tenant,
          isActive: true,
          createdAt: null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: TechnicianQueueScreen(
              profile: tenantProfile,
              complaintRepository: repo,
            ),
          ),
        );

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('Access restricted'), findsOneWidget);
        expect(
          find.text(
            'This work queue is only accessible to authorized field technicians.',
          ),
          findsOneWidget,
        );
        expect(repo.lastRequestedTechnicianId, isNull);

        repo.dispose();
      },
    );

    testWidgets('preview fixture identity renders access restricted', (
      tester,
    ) async {
      final repo = TestTechnicianComplaintRepository();

      const previewProfile = AppUser(
        id: 'preview',
        name: 'Preview',
        email: 'preview@grihsetu.local',
        role: UserRole.technician,
        isActive: true,
        createdAt: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TechnicianQueueScreen(
            profile: previewProfile,
            complaintRepository: repo,
          ),
        ),
      );

      expect(find.text('Access restricted'), findsOneWidget);
      expect(repo.lastRequestedTechnicianId, isNull);

      repo.dispose();
    });
  });

  group('TechnicianQueueScreen - Navigation in AppShell', () {
    testWidgets('AppShell Assigned Work navigation destination opens queue', (
      tester,
    ) async {
      final repo = InMemoryComplaintRepository(
        initialComplaints: [urgentComplaint],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            profile: testTechnicianProfile,
            complaintRepository: repo,
          ),
        ),
      );

      // Switch to Assigned Work navigation item
      final assignedTab = find.text('Assigned Work');
      expect(assignedTab, findsWidgets);

      await tester.tap(assignedTab.first);
      await tester.pumpAndSettle();

      expect(find.byType(TechnicianQueueScreen), findsOneWidget);
      expect(find.byType(ComplaintCard), findsOneWidget);
      expect(find.text('Gas line smell in kitchen'), findsOneWidget);

      repo.dispose();
    });
  });
}

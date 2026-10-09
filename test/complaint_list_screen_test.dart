import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/app_shell.dart';
import 'package:grihsetu/core/enums/enums.dart';
import 'package:grihsetu/core/models/models.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/screens/complaints/complaint_detail_screen.dart';
import 'package:grihsetu/screens/complaints/complaint_list_screen.dart';
import 'package:grihsetu/widgets/complaint_card.dart';
import 'package:grihsetu/widgets/empty_state.dart';
import 'package:grihsetu/widgets/error_state.dart';
import 'package:grihsetu/widgets/skeleton_box.dart';

class TestStreamComplaintRepository implements ComplaintRepository {
  TestStreamComplaintRepository();

  final StreamController<List<Complaint>> _controller =
      StreamController<List<Complaint>>.broadcast();

  void emitData(List<Complaint> data) => _controller.add(data);
  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<List<Complaint>> watchComplaints({
    String? propertyId,
    String? unitId,
    String? tenantId,
  }) => _controller.stream;

  @override
  Future<Complaint> createComplaint(CreateComplaintInput input) async {
    throw UnimplementedError();
  }

  void dispose() => _controller.close();
}

void main() {
  final sampleComplaint1 = Complaint(
    id: 'c_001',
    title: 'Ceiling leakage in hall',
    description: 'Dripping from corner of ceiling.',
    category: ComplaintCategory.plumbing,
    priority: ComplaintPriority.urgent,
    status: ComplaintStatus.open,
    propertyId: 'prop_001',
    unitId: 'unit_101',
    tenantId: 'ten_001',
    createdBy: 'user_1',
    createdAt: DateTime.utc(2026, 10, 8, 10, 0),
  );

  final sampleComplaint2 = Complaint(
    id: 'c_002',
    title: 'Faulty hallway light',
    description: 'Flickering incessantly.',
    category: ComplaintCategory.electrical,
    priority: ComplaintPriority.low,
    status: ComplaintStatus.inProgress,
    propertyId: 'prop_001',
    unitId: 'unit_204',
    tenantId: 'ten_002',
    createdBy: 'user_1',
    createdAt: DateTime.utc(2026, 10, 7, 15, 0),
  );

  group('ComplaintListScreen', () {
    testWidgets('renders loading skeleton while stream is waiting', (
      tester,
    ) async {
      final repo = TestStreamComplaintRepository();

      await tester.pumpWidget(
        MaterialApp(home: ComplaintListScreen(complaintRepository: repo)),
      );

      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
      expect(find.byType(ComplaintCard), findsNothing);

      repo.dispose();
    });

    testWidgets('renders empty state when stream returns empty list', (
      tester,
    ) async {
      final repo = TestStreamComplaintRepository();

      await tester.pumpWidget(
        MaterialApp(home: ComplaintListScreen(complaintRepository: repo)),
      );

      repo.emitData([]);
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No complaints yet'), findsOneWidget);
      expect(find.text('Register complaint'), findsOneWidget);
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.byType(ComplaintCard), findsNothing);

      repo.dispose();
    });

    testWidgets('renders complaint cards when stream emits data', (
      tester,
    ) async {
      final repo = TestStreamComplaintRepository();

      await tester.pumpWidget(
        MaterialApp(home: ComplaintListScreen(complaintRepository: repo)),
      );

      repo.emitData([sampleComplaint1, sampleComplaint2]);
      await tester.pumpAndSettle();

      expect(find.byType(ComplaintCard), findsNWidgets(2));
      expect(find.text('Ceiling leakage in hall'), findsOneWidget);
      expect(find.text('Faulty hallway light'), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
      expect(find.byType(SkeletonList), findsNothing);

      repo.dispose();
    });

    testWidgets(
      'renders user-friendly error state on stream failure with retry',
      (tester) async {
        final repo = TestStreamComplaintRepository();

        await tester.pumpWidget(
          MaterialApp(home: ComplaintListScreen(complaintRepository: repo)),
        );

        repo.emitError(
          const ComplaintFailure(
            ComplaintFailureCode.network,
            'Connection timed out.',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ErrorState), findsOneWidget);
        expect(find.text('Connection timed out.'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Verify retry action works
        await tester.tap(find.text('Retry'));
        await tester.pump();

        repo.emitData([sampleComplaint1]);
        await tester.pumpAndSettle();

        expect(find.byType(ErrorState), findsNothing);
        expect(find.byType(ComplaintCard), findsOneWidget);

        repo.dispose();
      },
    );

    testWidgets('tapping a complaint card navigates to detail placeholder', (
      tester,
    ) async {
      final repo = TestStreamComplaintRepository();

      await tester.pumpWidget(
        MaterialApp(home: ComplaintListScreen(complaintRepository: repo)),
      );

      repo.emitData([sampleComplaint1]);
      await tester.pumpAndSettle();

      final cardFinder = find.byType(ComplaintCard);
      expect(cardFinder, findsOneWidget);

      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      // Should now be on ComplaintDetailScreen
      expect(find.byType(ComplaintDetailScreen), findsOneWidget);
      expect(find.text('Complaint details'), findsOneWidget);
      expect(find.text('Ceiling leakage in hall'), findsOneWidget);
      expect(find.text('Dripping from corner of ceiling.'), findsOneWidget);
      expect(find.text('Complaint detail placeholder'), findsOneWidget);

      // Back navigation
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(ComplaintDetailScreen), findsNothing);
      expect(find.byType(ComplaintListScreen), findsOneWidget);

      repo.dispose();
    });

    testWidgets('AppShell Complaints tab opens ComplaintListScreen', (
      tester,
    ) async {
      const opsProfile = AppUser(
        id: 'u_ops',
        name: 'Ops Manager',
        email: 'ops@grihsetu.com',
        role: UserRole.propertyOperations,
        createdAt: null,
      );

      final repo = InMemoryComplaintRepository(
        initialComplaints: [sampleComplaint1],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(profile: opsProfile, complaintRepository: repo),
        ),
      );

      // Switch to Complaints navigation item
      final complaintsTab = find.text('Complaints');
      expect(complaintsTab, findsOneWidget);

      await tester.tap(complaintsTab);
      await tester.pumpAndSettle();

      expect(find.byType(ComplaintListScreen), findsOneWidget);
      expect(find.byType(ComplaintCard), findsOneWidget);
      expect(find.text('Ceiling leakage in hall'), findsOneWidget);

      repo.dispose();
    });
  });
}

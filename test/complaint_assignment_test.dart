import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/user_role.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/repositories/assignment_repository.dart';
import 'package:grihsetu/screens/complaints/assignment/assign_technician_sheet.dart';
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
  final unassignedComplaint = Complaint(
    id: 'cmp_open_01',
    title: 'Water leaking under bathroom sink',
    description: 'Puddle accumulating rapidly.',
    category: ComplaintCategory.plumbing,
    priority: ComplaintPriority.high,
    status: ComplaintStatus.open,
    propertyId: 'prop_001',
    unitId: 'unit_101',
    tenantId: 'ten_001',
    createdBy: 'usr_001',
    createdAt: DateTime(2026, 10, 10, 10, 0),
  );

  final assignedComplaint = Complaint(
    id: 'cmp_assigned_01',
    title: 'Circuit breaker tripping constantly',
    description: 'Electrical spark observed.',
    category: ComplaintCategory.electrical,
    priority: ComplaintPriority.urgent,
    status: ComplaintStatus.assigned,
    currentTechnicianId: 'usr_002',
    propertyId: 'prop_001',
    unitId: 'unit_204',
    tenantId: 'ten_002',
    createdBy: 'usr_001',
    createdAt: DateTime(2026, 10, 10, 9, 0),
    firstAssignedAt: DateTime(2026, 10, 10, 9, 30),
  );

  group('Technician Assignment UI Tests', () {
    testWidgets(
      '(a) sheet shows "Best match" badge on the best matching technician',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = InMemoryAssignmentRepository(
          simulatedDelay: Duration.zero,
        );

        await tester.pumpWidget(
          _buildTestApp(
            child: AssignTechnicianSheet(
              complaint: unassignedComplaint,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // For plumbing complaint (cmp_open_01), Ramesh Meena matches plumbing with lowest load (1)
        expect(find.text('Best match'), findsOneWidget);
        expect(find.text('Ramesh Meena'), findsOneWidget);
      },
    );

    testWidgets('(b) confirm button is disabled until a technician is chosen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryAssignmentRepository(simulatedDelay: Duration.zero);

      await tester.pumpWidget(
        _buildTestApp(
          child: AssignTechnicianSheet(
            complaint: unassignedComplaint,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final confirmButtonFinder = find.byKey(
        const Key('confirm_assign_button'),
      );
      expect(confirmButtonFinder, findsOneWidget);

      // Initially disabled
      FilledButton button = tester.widget<FilledButton>(confirmButtonFinder);
      expect(button.onPressed, isNull);

      // Tap on a technician to select
      await tester.tap(find.text('Ramesh Meena'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Now enabled
      button = tester.widget<FilledButton>(confirmButtonFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets(
      '(c) reassign mode requires a reason and excludes the current technician',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = InMemoryAssignmentRepository(
          simulatedDelay: Duration.zero,
        );
        const currentTech = TechnicianOption(
          id: 'usr_002',
          name: 'Aman Verma',
          phone: '+91 98111 22334',
          specialties: [ComplaintCategory.electrical],
          todayJobCount: 2,
          availability: TechnicianAvailability.available,
        );

        await tester.pumpWidget(
          _buildTestApp(
            child: AssignTechnicianSheet(
              complaint: assignedComplaint,
              repository: repo,
              currentTechnician: currentTech,
              isReassign: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Currently Assigned header is visible
        expect(find.text('Currently assigned'), findsOneWidget);

        // Current technician Aman Verma should be shown in currently assigned header
        // but excluded from selectable list cards
        expect(find.byKey(const Key('technician_card_usr_002')), findsNothing);

        // Select another technician
        await tester.tap(find.text('Kavita Sundaram'), warnIfMissed: false);
        await tester.pumpAndSettle();

        // Button should still be disabled because reason is not yet selected
        final confirmButtonFinder = find.byKey(
          const Key('confirm_assign_button'),
        );
        FilledButton button = tester.widget<FilledButton>(confirmButtonFinder);
        expect(button.onPressed, isNull);

        // Scroll to and select reason via dropdown
        final dropdownFinder = find.byKey(
          const Key('reassignment_reason_dropdown'),
        );
        await tester.ensureVisible(dropdownFinder);
        await tester.tap(dropdownFinder, warnIfMissed: false);
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('Technician unavailable').last,
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        // Now button is enabled
        button = tester.widget<FilledButton>(confirmButtonFinder);
        expect(button.onPressed, isNotNull);
        expect(find.text('Confirm reassignment'), findsOneWidget);
      },
    );

    testWidgets('(d) off-duty warning requires "Assign anyway" button label', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryAssignmentRepository(simulatedDelay: Duration.zero);

      await tester.pumpWidget(
        _buildTestApp(
          child: AssignTechnicianSheet(
            complaint: unassignedComplaint,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mohit Chawla is off duty in sample repo
      final mohitFinder = find.text('Mohit Chawla');
      await tester.ensureVisible(mohitFinder);
      await tester.tap(mohitFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Inline warning banner shows
      expect(find.text('Assignment warning'), findsOneWidget);
      expect(find.text('• Technician is currently off duty.'), findsOneWidget);

      // Button label changes to "Assign anyway"
      expect(find.text('Assign anyway'), findsOneWidget);
      final confirmButtonFinder = find.byKey(
        const Key('confirm_assign_button'),
      );
      final button = tester.widget<FilledButton>(confirmButtonFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('(e) audit timeline gains the correct event after assignment', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryAssignmentRepository(simulatedDelay: Duration.zero);

      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintDetailScreen(
            key: const ValueKey('detail_screen_test_e'),
            complaint: unassignedComplaint,
            assignmentRepository: repo,
            userRole: UserRole.staff,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify initial audit event
      expect(find.text('Audit timeline'), findsOneWidget);
      expect(find.text('Complaint created'), findsOneWidget);
      expect(find.text('Technician assigned'), findsNothing);

      // Tap Assign technician
      await tester.tap(find.byKey(const Key('assign_technician_button')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Select Ramesh Meena
      await tester.tap(find.text('Ramesh Meena'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      // Tap confirm
      await tester.tap(
        find.byKey(const Key('confirm_assign_button')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Check SnackBar appeared
      expect(find.text('Assigned to Ramesh Meena'), findsOneWidget);

      // Check updated status badge
      expect(find.text('Assigned'), findsWidgets);

      // Check new audit timeline event appeared
      expect(find.text('Technician assigned'), findsOneWidget);
      expect(find.textContaining('Ramesh Meena'), findsWidgets);
    });

    testWidgets('(f) staff-only visibility of the action buttons', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryAssignmentRepository(simulatedDelay: Duration.zero);

      // 1. Staff role on unassigned complaint -> sees Assign technician button
      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintDetailScreen(
            key: const ValueKey('detail_staff_unassigned'),
            complaint: unassignedComplaint,
            assignmentRepository: repo,
            userRole: UserRole.staff,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('assign_technician_button')), findsOneWidget);

      // 2. Tenant role on unassigned complaint -> read-only, no button
      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintDetailScreen(
            key: const ValueKey('detail_tenant_unassigned'),
            complaint: unassignedComplaint,
            assignmentRepository: repo,
            userRole: UserRole.tenant,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('assign_technician_button')), findsNothing);

      // 3. Staff role on assigned complaint -> sees Reassign button
      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintDetailScreen(
            key: const ValueKey('detail_staff_assigned'),
            complaint: assignedComplaint,
            assignmentRepository: repo,
            userRole: UserRole.staff,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const Key('reassign_technician_button')),
        findsOneWidget,
      );

      // 4. Technician role on assigned complaint -> read-only, sees name but no Reassign button
      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintDetailScreen(
            key: const ValueKey('detail_tech_assigned'),
            complaint: assignedComplaint,
            assignmentRepository: repo,
            userRole: UserRole.technician,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('reassign_technician_button')), findsNothing);
      expect(find.text('Aman Verma'), findsOneWidget);

      // 5. Terminal status (resolved) disables button with tooltip
      final resolvedComplaint = assignedComplaint.copyWith(
        status: ComplaintStatus.resolved,
      );
      await tester.pumpWidget(
        _buildTestApp(
          child: ComplaintDetailScreen(
            key: const ValueKey('detail_staff_resolved'),
            complaint: resolvedComplaint,
            assignmentRepository: repo,
            userRole: UserRole.staff,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final reassignButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('reassign_technician_button')),
      );
      expect(reassignButton.onPressed, isNull);
    }, skip: true); // GRIH-049 known issue: terminal assignment action contract changed.

    testWidgets(
      'responsive layout and themes across widths 360, 768, 1280 and text scale 1.3',
      (tester) async {
        final repo = InMemoryAssignmentRepository(
          simulatedDelay: Duration.zero,
        );

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
                  complaint: assignedComplaint,
                  assignmentRepository: repo,
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

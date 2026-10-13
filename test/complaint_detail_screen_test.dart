import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/enums.dart';
import 'package:grihsetu/core/models/models.dart';
import 'package:grihsetu/screens/complaints/complaint_detail_screen.dart';
import 'package:grihsetu/widgets/audit_timeline.dart';
import 'package:grihsetu/widgets/empty_state.dart';

void main() {
  final testComplaint = Complaint(
    id: 'c_test_001',
    title: 'Water pressure low in bathroom',
    description: 'Shower flow is very weak since morning.',
    category: ComplaintCategory.plumbing,
    priority: ComplaintPriority.high,
    status: ComplaintStatus.inProgress,
    propertyId: 'prop_001',
    unitId: 'unit_101',
    tenantId: 'ten_001',
    createdBy: 'usr_tenant',
    createdAt: DateTime.utc(2026, 10, 10, 8, 30),
  );

  group('ComplaintDetailScreen - Audit History and UI States', () {
    testWidgets(
      'renders populated audit timeline when initialAuditEvents are provided',
      (tester) async {
        final events = [
          AuditEvent(
            title: 'Complaint logged',
            actor: 'Priya Sharma',
            role: 'Tenant',
            timestamp: DateTime.utc(2026, 10, 10, 8, 30),
            tone: AuditTone.neutral,
          ),
          AuditEvent(
            title: 'Technician dispatched',
            actor: 'Rohan Gupta',
            role: 'Operations',
            timestamp: DateTime.utc(2026, 10, 10, 10, 0),
            tone: AuditTone.accent,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: ComplaintDetailScreen(
              complaint: testComplaint,
              propertyName: 'Sunrise Apartments',
              unitNumber: 'A-101',
              initialAuditEvents: events,
            ),
          ),
        );

        expect(find.text('Complaint details'), findsOneWidget);
        expect(find.text('Water pressure low in bathroom'), findsOneWidget);
        expect(find.text('Sunrise Apartments · Unit A-101'), findsOneWidget);
        expect(find.byType(AuditTimeline), findsOneWidget);
        expect(find.text('Complaint logged'), findsOneWidget);
        expect(find.text('Technician dispatched'), findsOneWidget);
        expect(find.byType(EmptyState), findsNothing);
      },
    );

    testWidgets('renders compact EmptyState when audit events list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ComplaintDetailScreen(
            complaint: testComplaint,
            propertyName: 'Sunrise Apartments',
            unitNumber: 'A-101',
            initialAuditEvents: const [],
          ),
        ),
      );

      expect(find.byType(AuditTimeline), findsNothing);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No activity recorded yet'), findsOneWidget);
      expect(
        find.text(
          'Timeline events will appear here as the complaint progresses.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.history_toggle_off_outlined), findsOneWidget);
    });

    testWidgets(
      'unassigned technician displays placeholder and assign action for staff',
      (tester) async {
        final unassignedComplaint = testComplaint.copyWith(
          currentTechnicianId: null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ComplaintDetailScreen(
              complaint: unassignedComplaint,
              initialAuditEvents: const [],
            ),
          ),
        );

        expect(find.text('No technician currently assigned.'), findsOneWidget);
        expect(
          find.byKey(const Key('assign_technician_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders cleanly without overflow across common screen widths (320px to 720px)',
      (tester) async {
        for (final width in [320.0, 360.0, 390.0, 720.0]) {
          await tester.binding.setSurfaceSize(Size(width, 800));

          await tester.pumpWidget(
            MaterialApp(
              home: ComplaintDetailScreen(
                key: ValueKey(width),
                complaint: testComplaint,
                propertyName: 'Green Heights Tower B Locality',
                unitNumber: 'Penthouse 1202',
                initialAuditEvents: const [],
              ),
            ),
          );
          await tester.pump();

          expect(
            tester.takeException(),
            isNull,
            reason: 'Failed at width $width',
          );
        }
        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}

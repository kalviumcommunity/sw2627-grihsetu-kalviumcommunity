import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_audit_event_type.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/complaint_audit_event.dart';
import 'package:grihsetu/screens/complaints/complaint_detail_screen.dart';
import 'package:grihsetu/theme/app_colors.dart';
import 'package:grihsetu/theme/app_theme.dart';
import 'package:grihsetu/utils/visit_history.dart';
import 'package:grihsetu/widgets/repeat_indicator.dart';

Widget _buildTestApp({required Widget child}) {
  return MaterialApp(
    theme: AppTheme.light(webFonts: false),
    darkTheme: AppTheme.dark(webFonts: false),
    home: Scaffold(body: child),
  );
}

void main() {
  group('GRIH-026 Visit History and Repeat Indicators', () {
    // -------------------------------------------------------------
    // TEST 1: visitsFromEvents (0, 1, 3 visits)
    // -------------------------------------------------------------
    test('visitsFromEvents derives 0, 1, and 3 visits correctly', () {
      // 0 visits
      final zeroVisits = visitsFromEvents(<ComplaintAuditEvent>[]);
      expect(zeroVisits, isEmpty);

      final nonVisitEvents = [
        ComplaintAuditEvent(
          id: 'ev_0',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.complaintCreated,
          actorId: 'usr_tenant',
          timestamp: DateTime(2026, 10, 1, 9, 0),
        ),
        ComplaintAuditEvent(
          id: 'ev_1',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.technicianAssigned,
          actorId: 'usr_ops',
          timestamp: DateTime(2026, 10, 1, 9, 30),
        ),
      ];
      expect(visitsFromEvents(nonVisitEvents), isEmpty);

      // 1 visit: arrived -> inspection -> partAdded -> photoUploaded -> resolved
      final oneVisitEvents = [
        ComplaintAuditEvent(
          id: 'ev_arr_1',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.technicianArrived,
          actorId: 'tech_aman',
          timestamp: DateTime(2026, 10, 2, 10, 0),
          metadata: const {'actorName': 'Aman Verma'},
        ),
        ComplaintAuditEvent(
          id: 'ev_insp_1',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.inspectionStarted,
          actorId: 'tech_aman',
          timestamp: DateTime(2026, 10, 2, 10, 10),
          metadata: const {'note': 'Checked pipe joints'},
        ),
        ComplaintAuditEvent(
          id: 'ev_part_1',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.partAdded,
          actorId: 'tech_aman',
          timestamp: DateTime(2026, 10, 2, 10, 20),
          metadata: const {'partName': 'Brass Valve 1/2"'},
        ),
        ComplaintAuditEvent(
          id: 'ev_photo_1',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.photoUploaded,
          actorId: 'tech_aman',
          timestamp: DateTime(2026, 10, 2, 10, 30),
          metadata: const {
            'photos': ['https://example.com/photo1.jpg'],
          },
        ),
        ComplaintAuditEvent(
          id: 'ev_res_1',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.complaintResolved,
          actorId: 'tech_aman',
          timestamp: DateTime(2026, 10, 2, 10, 45),
          metadata: const {
            'note': 'Joint tightened and valve replaced successfully.',
            'outcome': 'resolved',
          },
        ),
      ];

      final singleVisitList = visitsFromEvents(oneVisitEvents);
      expect(singleVisitList, hasLength(1));
      final v1 = singleVisitList.first;
      expect(v1.visitNumber, 1);
      expect(v1.technician, 'Aman Verma');
      expect(v1.arrival, DateTime(2026, 10, 2, 10, 0));
      expect(v1.end, DateTime(2026, 10, 2, 10, 45));
      expect(v1.timeOnSite, const Duration(minutes: 45));
      expect(v1.outcome, 'resolved');
      expect(v1.isResolved, isTrue);
      expect(v1.parts, contains('Brass Valve 1/2"'));
      expect(v1.photoCount, 1);
      expect(v1.notes, contains('Joint tightened'));

      // 3 visits
      final threeVisitEvents = [
        // Visit 1: Needs another visit (part not available)
        ComplaintAuditEvent(
          id: 'ev_v1_arr',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.technicianArrived,
          actorId: 'tech_aman',
          timestamp: DateTime(2026, 10, 1, 10, 0),
          metadata: const {'actorName': 'Aman Verma'},
        ),
        ComplaintAuditEvent(
          id: 'ev_v1_end',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.needsAnotherVisit,
          actorId: 'tech_aman',
          timestamp: DateTime(2026, 10, 1, 10, 30),
          metadata: const {'note': 'Part required: heavy coil'},
        ),

        // Visit 2: Needs specialist
        ComplaintAuditEvent(
          id: 'ev_v2_arr',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.technicianArrived,
          actorId: 'tech_rajesh',
          timestamp: DateTime(2026, 10, 3, 11, 0),
          metadata: const {'actorName': 'Rajesh Kumar'},
        ),
        ComplaintAuditEvent(
          id: 'ev_v2_end',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.needsAnotherVisit,
          actorId: 'tech_rajesh',
          timestamp: DateTime(2026, 10, 3, 12, 15),
          metadata: const {'note': 'Requires HVAC specialist'},
        ),

        // Visit 3: Specialist completes job
        ComplaintAuditEvent(
          id: 'ev_v3_arr',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.technicianArrived,
          actorId: 'tech_vikram',
          timestamp: DateTime(2026, 10, 5, 14, 0),
          metadata: const {'actorName': 'Vikram Malhotra'},
        ),
        ComplaintAuditEvent(
          id: 'ev_v3_part',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.partAdded,
          actorId: 'tech_vikram',
          timestamp: DateTime(2026, 10, 5, 14, 20),
          metadata: const {'partName': 'Compressor relay'},
        ),
        ComplaintAuditEvent(
          id: 'ev_v3_end',
          complaintId: 'cmp_1',
          eventType: ComplaintAuditEventType.complaintResolved,
          actorId: 'tech_vikram',
          timestamp: DateTime(2026, 10, 5, 15, 30),
          metadata: const {
            'note': 'Relay installed and tested cooling cycle.',
            'outcome': 'resolved',
          },
        ),
      ];

      final threeVisitList = visitsFromEvents(threeVisitEvents);
      expect(threeVisitList, hasLength(3));
      expect(threeVisitList[0].visitNumber, 1);
      expect(threeVisitList[0].technician, 'Aman Verma');
      expect(threeVisitList[0].needsAnotherVisit, isTrue);
      expect(threeVisitList[0].timeOnSite, const Duration(minutes: 30));

      expect(threeVisitList[1].visitNumber, 2);
      expect(threeVisitList[1].technician, 'Rajesh Kumar');
      expect(threeVisitList[1].needsAnotherVisit, isTrue);
      expect(
        threeVisitList[1].timeOnSite,
        const Duration(hours: 1, minutes: 15),
      );

      expect(threeVisitList[2].visitNumber, 3);
      expect(threeVisitList[2].technician, 'Vikram Malhotra');
      expect(threeVisitList[2].isResolved, isTrue);
      expect(threeVisitList[2].parts, contains('Compressor relay'));
      expect(
        threeVisitList[2].timeOnSite,
        const Duration(hours: 1, minutes: 30),
      );
    });

    // -------------------------------------------------------------
    // TEST 2: repeatInfo thresholds (the 60-day boundary: day 60 counts, day 61 does not)
    // -------------------------------------------------------------
    test(
      'repeatInfo thresholds - 60-day boundary: day 60 counts, day 61 does not',
      () {
        final now = DateTime(2026, 10, 15, 12, 0);

        final currentComplaint = Complaint(
          id: 'cmp_current',
          tenantId: 'ten_001',
          propertyId: 'prop_001',
          unitId: 'unit_101',
          title: 'Water leak',
          description: 'Bathroom faucet leaking',
          category: ComplaintCategory.plumbing,
          priority: ComplaintPriority.high,
          status: ComplaintStatus.assigned,
          currentTechnicianId: 'tech_001',
          createdBy: 'usr_001',
          createdAt: now,
          visitCount: 1,
        );

        // Same unit, same category, exactly 60 days ago
        final complaintAtDay60 = Complaint(
          id: 'cmp_day_60',
          tenantId: 'ten_001',
          propertyId: 'prop_001',
          unitId: 'unit_101',
          title: 'Pipe dripping',
          description: 'Sink pipe drip repaired',
          category: ComplaintCategory.plumbing,
          priority: ComplaintPriority.medium,
          status: ComplaintStatus.resolved,
          currentTechnicianId: 'tech_002',
          createdBy: 'usr_001',
          createdAt: now.subtract(const Duration(days: 60)),
          visitCount: 1,
        );

        // Same unit, same category, 61 days ago
        final complaintAtDay61 = Complaint(
          id: 'cmp_day_61',
          tenantId: 'ten_001',
          propertyId: 'prop_001',
          unitId: 'unit_101',
          title: 'Old leak',
          description: 'Old valve repaired',
          category: ComplaintCategory.plumbing,
          priority: ComplaintPriority.low,
          status: ComplaintStatus.resolved,
          currentTechnicianId: 'tech_003',
          createdBy: 'usr_001',
          createdAt: now.subtract(const Duration(days: 61)),
          visitCount: 1,
        );

        // Day 60 counts -> recurringIssue is TRUE
        final infoDay60 = repeatInfo(currentComplaint, [complaintAtDay60]);
        expect(infoDay60.recurringIssue, isTrue);
        expect(infoDay60.count, 2);
        expect(infoDay60.previousTechnicians, contains('tech_002'));
        expect(infoDay60.previousActions, contains('Sink pipe drip repaired'));

        // Day 61 does NOT count -> recurringIssue is FALSE
        final infoDay61 = repeatInfo(currentComplaint, [complaintAtDay61]);
        expect(infoDay61.recurringIssue, isFalse);
        expect(infoDay61.count, 1);

        // Repeat visit threshold on complaint itself: visitCount >= 2 is repeatVisit
        final singleVisitComplaint = currentComplaint.copyWith(visitCount: 1);
        final repeatVisitComplaint = currentComplaint.copyWith(visitCount: 2);
        expect(repeatInfo(singleVisitComplaint, []).repeatVisit, isFalse);
        expect(repeatInfo(repeatVisitComplaint, []).repeatVisit, isTrue);
      },
    );

    // -------------------------------------------------------------
    // TEST 3: RepeatIndicator levels
    // -------------------------------------------------------------
    testWidgets('RepeatIndicator levels: amber for 2, terracotta for 3+', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const Column(
            children: [
              RepeatIndicator(count: 2, label: 'Visit 2'),
              RepeatIndicator(count: 3, label: 'Repeat x3'),
              RepeatIndicator.recurring(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Column));
      final palette = context.palette;

      // 1. Level 2 -> Amber (palette.warning)
      expect(find.text('Visit 2'), findsOneWidget);
      final visit2Text = tester.widget<Text>(find.text('Visit 2'));
      expect(visit2Text.style?.color, palette.warning);

      // 2. Level 3 -> Terracotta (palette.accent)
      expect(find.text('Repeat x3'), findsOneWidget);
      final repeat3Text = tester.widget<Text>(find.text('Repeat x3'));
      expect(repeat3Text.style?.color, palette.accent);

      // 3. Recurring issue pill with semantic label and tooltip
      expect(find.text('Recurring issue'), findsOneWidget);
      final recurringPill = find.byType(RepeatIndicator).last;
      expect(recurringPill, findsOneWidget);
      expect(find.byType(Tooltip), findsNWidgets(3));
      expect(find.byType(Semantics), findsWidgets);
    });

    // -------------------------------------------------------------
    // TEST 4: The detail screen shows the section and the recurring card for a fixture with 3 visits
    // -------------------------------------------------------------
    testWidgets(
      'the detail screen shows the section and the recurring card for a fixture with 3 visits',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Fixture with 3 visits
        final fixtureWith3Visits = Complaint(
          id: 'cmp_fixture_3_visits',
          tenantId: 'ten_001',
          propertyId: 'prop_001',
          unitId: 'unit_101',
          title: 'AC cooling failure and water dripping',
          description: 'AC unit fails to reach set temperature and drips into living room.',
          category: ComplaintCategory.appliance,
          priority: ComplaintPriority.high,
          status: ComplaintStatus.inProgress,
          currentTechnicianId: 'usr_002',
          visitCount: 3,
          isRepeatVisit: true,
          reopenCount: 1,
          createdBy: 'usr_001',
          createdAt: DateTime(2026, 10, 10, 9, 0),
        );

        await tester.pumpWidget(
          _buildTestApp(
            child: ComplaintDetailScreen(
              complaint: fixtureWith3Visits,
              propertyName: 'Shanti Heights',
              unitNumber: 'A-101',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Visit history section must be shown with count (3)
        expect(find.text('Visit history (3)'), findsOneWidget);

        // 2. Recurring issue card must be visible with "Recurring issue detected"
        expect(find.text('Recurring issue detected'), findsOneWidget);

        // 3. "Requires root-cause inspection" banner must be displayed
        expect(find.text('Requires root-cause inspection'), findsOneWidget);

        // 4. Visit cards should be rendered
        expect(find.text('Visit #3'), findsOneWidget);
        expect(find.text('Visit #2'), findsOneWidget);
        expect(find.text('Visit #1'), findsOneWidget);
      },
    );
  });
}

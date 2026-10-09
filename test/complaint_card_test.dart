import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/enums.dart';
import 'package:grihsetu/core/models/models.dart';
import 'package:grihsetu/widgets/complaint_card.dart';

void main() {
  final testComplaint = Complaint(
    id: 'complaint_123',
    tenantId: 'tenant_001',
    propertyId: 'prop_001',
    unitId: 'unit_101',
    title: 'Water leaking from pipe',
    description: 'Noticeable dripping under the kitchen sink.',
    category: ComplaintCategory.plumbing,
    priority: ComplaintPriority.high,
    status: ComplaintStatus.inProgress,
    createdBy: 'user_test',
    createdAt: DateTime.utc(2026, 10, 8, 14, 30),
  );

  Widget buildCard({
    Complaint? complaint,
    String? propertyName,
    String? unitNumber,
    VoidCallback? onTap,
    double width = 400,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: ComplaintCard(
              complaint: complaint ?? testComplaint,
              propertyName: propertyName,
              unitNumber: unitNumber,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  group('ComplaintCard', () {
    testWidgets('renders title, resolved property, and unit context', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(propertyName: 'Green Valley Heights', unitNumber: 'A-101'),
      );

      expect(find.text('Water leaking from pipe'), findsOneWidget);
      expect(find.text('Green Valley Heights · Unit A-101'), findsOneWidget);
      expect(find.text('Plumbing'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Oct 8, 2026'), findsOneWidget);
    });

    testWidgets('falls back to propertyId and unitId when names are absent', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard(propertyName: null, unitNumber: null));

      expect(find.text('prop_001 · Unit unit_101'), findsOneWidget);
    });

    testWidgets(
      'renders distinguishable labels for all 8 ComplaintStatus values',
      (tester) async {
        for (final status in ComplaintStatus.values) {
          final complaint = testComplaint.copyWith(status: status);
          await tester.pumpWidget(buildCard(complaint: complaint));

          expect(
            find.text(status.displayLabel),
            findsOneWidget,
            reason:
                'Status badge for ${status.name} should display ${status.displayLabel}',
          );
        }
      },
    );

    testWidgets(
      'renders distinguishable labels for all 4 ComplaintPriority values',
      (tester) async {
        for (final priority in ComplaintPriority.values) {
          final complaint = testComplaint.copyWith(priority: priority);
          await tester.pumpWidget(buildCard(complaint: complaint));

          expect(
            find.text(priority.displayLabel),
            findsOneWidget,
            reason:
                'Priority badge for ${priority.name} should display ${priority.displayLabel}',
          );
        }
      },
    );

    testWidgets('renders repeat visit badge when isRepeatVisit is true', (
      tester,
    ) async {
      final repeatComplaint = testComplaint.copyWith(
        visitCount: 3,
        isRepeatVisit: true,
      );
      await tester.pumpWidget(buildCard(complaint: repeatComplaint));

      expect(find.text('Repeat visit'), findsOneWidget);
    });

    testWidgets(
      'long text and narrow screen width do not cause layout overflow',
      (tester) async {
        final longComplaint = Complaint(
          id: 'c_long',
          tenantId: 'tenant_long_id_000000000000',
          propertyId: 'property_very_long_identifier_value_here',
          unitId: 'unit_very_long_unit_identifier_value_here',
          title: 'A very long complaint title that describes an extensive structural and plumbing issue that repeats across multiple sentences and takes up a large amount of horizontal and vertical space without overflowing the layout.',
          description: 'Description text',
          category: ComplaintCategory.structural,
          priority: ComplaintPriority.urgent,
          status: ComplaintStatus.waitingForParts,
          createdBy: 'user_long',
          createdAt: DateTime.utc(2026, 10, 8),
        );

        await tester.pumpWidget(
          buildCard(
            complaint: longComplaint,
            propertyName: 'Extremely Long Property Residence Complex Name',
            unitNumber: 'Building 14 Tower B Unit 999',
            width: 300,
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ComplaintCard), findsOneWidget);
      },
    );

    testWidgets('tapping the card invokes the onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildCard(onTap: () => tapped = true));

      await tester.tap(find.byType(ComplaintCard));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}

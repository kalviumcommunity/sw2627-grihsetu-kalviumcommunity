import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/maintenance_visit_outcome.dart';
import 'package:grihsetu/core/models/maintenance_visit.dart';
import 'package:grihsetu/services/maintenance_visit_reconciliation.dart';

MaintenanceVisit visit(int number, {String? id}) => MaintenanceVisit(
  id: id ?? 'visit-$number',
  complaintId: 'complaint-1',
  technicianId: 'tech-1',
  visitNumber: number,
  startedAt: DateTime(2026, 10, number),
  completedAt: DateTime(2026, 10, number, 1),
  observation: 'Observed',
  actionTaken: 'Acted',
  outcome: MaintenanceVisitOutcome.unresolved,
  isResolved: false,
  followUpRequired: true,
  followUpNotes: 'Return required',
  resolutionSummary: null,
  operationId: 'op-$number',
);

void main() {
  test('derives count and repeat flag for zero through three visits', () {
    for (var count = 0; count <= 3; count++) {
      final report = MaintenanceVisitReconciliation.inspect(
        visits: [for (var number = 1; number <= count; number++) visit(number)],
        storedVisitCount: count,
        storedRepeatFlag: count > 1,
      );
      expect(report.recordedVisitCount, count);
      expect(report.expectedRepeatFlag, count > 1);
      expect(report.nextVisitNumber, count + 1);
      expect(report.isConsistent, isTrue);
    }
  });

  test('detects stale counters and numbering gaps without renumbering', () {
    final report = MaintenanceVisitReconciliation.inspect(
      visits: [visit(1), visit(3)],
      storedVisitCount: 3,
      storedRepeatFlag: false,
    );

    expect(report.recordedVisitCount, 2);
    expect(report.nextVisitNumber, 3);
    expect(report.isConsistent, isFalse);
    expect(report.issues, contains(contains('does not match')));
    expect(report.issues, contains(contains('not contiguous')));
  });
}

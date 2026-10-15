import '../core/constants/app_constants.dart';
import '../core/models/maintenance_visit.dart';

/// The result of comparing the denormalized complaint visit fields with the
/// visit records that are actually stored for the complaint.
class MaintenanceVisitConsistencyReport {
  const MaintenanceVisitConsistencyReport({
    required this.recordedVisitCount,
    required this.expectedRepeatFlag,
    required this.nextVisitNumber,
    required this.issues,
  });

  final int recordedVisitCount;
  final bool expectedRepeatFlag;
  final int nextVisitNumber;
  final List<String> issues;

  bool get isConsistent => issues.isEmpty;

  Map<String, dynamic> get derivedComplaintFields => {
    'visitCount': recordedVisitCount,
    'isRepeatVisit': expectedRepeatFlag,
  };
}

/// Pure, deterministic reconciliation rules for legacy visit data.
///
/// This utility never writes to Firestore. A migration can use [inspect] for
/// a dry run and apply [MaintenanceVisitConsistencyReport.derivedComplaintFields]
/// only after reviewing the report. Existing visit documents are never
/// deleted or renumbered by this code.
abstract final class MaintenanceVisitReconciliation {
  static MaintenanceVisitConsistencyReport inspect({
    required List<MaintenanceVisit> visits,
    int? storedVisitCount,
    bool? storedRepeatFlag,
  }) {
    final ordered = List<MaintenanceVisit>.from(visits)
      ..sort((a, b) {
        final numberComparison = a.visitNumber.compareTo(b.visitNumber);
        return numberComparison != 0 ? numberComparison : a.id.compareTo(b.id);
      });
    final issues = <String>[];
    final numbers = <int>{};
    for (final visit in ordered) {
      if (!numbers.add(visit.visitNumber)) {
        issues.add('Duplicate visit number ${visit.visitNumber}.');
      }
    }
    for (var index = 0; index < ordered.length; index++) {
      final expectedNumber = index + 1;
      if (ordered[index].visitNumber != expectedNumber) {
        issues.add(
          'Visit numbering is not contiguous at position $expectedNumber.',
        );
        break;
      }
    }

    final recordedVisitCount = ordered.length;
    final expectedRepeatFlag =
        recordedVisitCount > AppConstants.repeatVisitThreshold;
    if (storedVisitCount != null && storedVisitCount != recordedVisitCount) {
      issues.add(
        'Stored visitCount $storedVisitCount does not match '
        '$recordedVisitCount recorded visits.',
      );
    }
    if (storedRepeatFlag != null && storedRepeatFlag != expectedRepeatFlag) {
      issues.add(
        'Stored isRepeatVisit $storedRepeatFlag does not match the '
        'derived value $expectedRepeatFlag.',
      );
    }

    return MaintenanceVisitConsistencyReport(
      recordedVisitCount: recordedVisitCount,
      expectedRepeatFlag: expectedRepeatFlag,
      nextVisitNumber: recordedVisitCount + 1,
      issues: List.unmodifiable(issues),
    );
  }
}

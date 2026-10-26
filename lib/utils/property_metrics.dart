import '../core/enums/complaint_category.dart';
import '../core/enums/complaint_status.dart';
import '../core/enums/rent_status.dart';
import '../core/enums/unit_status.dart';
import '../core/models/complaint.dart';
import '../core/models/property.dart';
import '../core/models/rent_record.dart';
import 'attention_rules.dart';
import 'rent_rules.dart';
import 'visit_history.dart';

/// Available evaluation periods for property summary analytics.
enum PropertyPeriod {
  days7(7, 'Last 7 days'),
  days30(30, 'Last 30 days'),
  days90(90, 'Last 90 days');

  const PropertyPeriod(this.days, this.label);

  final int days;
  final String label;

  Duration get duration => Duration(days: days);
}

/// Immutable aggregated summary for a property over a selected time window.
class PropertySummary {
  const PropertySummary({
    required this.propertyId,
    required this.propertyName,
    required this.periodDays,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.occupancyRate,
    required this.openComplaints,
    required this.resolvedInPeriod,
    required this.createdInPeriod,
    required this.avgFirstResponse,
    required this.avgResolutionTime,
    required this.slaPercent,
    required this.repeatVisits,
    required this.recurringIssues,
    required this.reopenedCount,
    required this.waitingForPartsCount,
    required this.unassignedCount,
    required this.overdueRentCount,
    required this.overdueRentAmount,
    required this.collectionRate,
    required this.totalRentDue,
    required this.totalRentCollected,
    required this.categoryBreakdown,
    required this.technicianWorkload,
    required this.trendBuckets,
    required this.calculatedAt,
  });

  final String propertyId;
  final String propertyName;
  final int periodDays;

  // Unit metrics
  final int totalUnits;
  final int occupiedUnits;
  final double occupancyRate;

  // Complaint volume
  final int openComplaints;
  final int resolvedInPeriod;
  final int createdInPeriod;

  // Speed and SLA (null when no eligible data in period)
  final Duration? avgFirstResponse;
  final Duration? avgResolutionTime;
  final double? slaPercent;

  // Quality and attention indicators
  final int repeatVisits;
  final int recurringIssues;
  final int reopenedCount;
  final int waitingForPartsCount;
  final int unassignedCount;

  // Financial / Rent metrics
  final int overdueRentCount;
  final double overdueRentAmount;
  final double collectionRate;
  final double totalRentDue;
  final double totalRentCollected;

  // Breakdowns
  final Map<ComplaintCategory, int> categoryBreakdown;
  final Map<String, int> technicianWorkload;

  /// Exactly 6 data points showing complaint creation distribution over the period.
  final List<int> trendBuckets;

  final DateTime calculatedAt;

  /// Returns true if this property has no open complaints and 0 overdue rent.
  bool get isHealthy =>
      openComplaints == 0 &&
      waitingForPartsCount == 0 &&
      unassignedCount == 0 &&
      overdueRentCount == 0;

  /// Normalized health score from 0.0 (critical) to 1.0 (optimal).
  double get healthScore {
    double score = 1.0;
    if (openComplaints > 0) {
      score -= (openComplaints * 0.05).clamp(0.0, 0.35);
    }
    if (unassignedCount > 0) {
      score -= (unassignedCount * 0.1).clamp(0.0, 0.25);
    }
    if (repeatVisits > 0) {
      score -= (repeatVisits * 0.05).clamp(0.0, 0.15);
    }
    if (overdueRentCount > 0) {
      score -= (overdueRentCount * 0.08).clamp(0.0, 0.25);
    }
    if (slaPercent != null && slaPercent! < 90.0) {
      score -= ((90.0 - slaPercent!) / 100.0).clamp(0.0, 0.2);
    }
    return score.clamp(0.0, 1.0);
  }
}

/// Pure calculation function deriving [PropertySummary] from canonical domain models.
PropertySummary calculatePropertySummary({
  required Property property,
  required List<Unit> units,
  required List<Complaint> complaints,
  required List<RentRecord> rentRecords,
  required int periodDays,
  required DateTime now,
}) {
  final periodStart = now.subtract(Duration(days: periodDays));

  // 1. Units & Occupancy
  final propUnits = units.where((u) => u.propertyId == property.id).toList();
  final totalUnits = propUnits.length;
  final occupiedUnits = propUnits
      .where((u) => u.status == UnitStatus.occupied)
      .length;
  final occupancyRate = totalUnits > 0
      ? (occupiedUnits / totalUnits) * 100.0
      : 0.0;

  // 2. Property Complaints
  final propComplaints = complaints
      .where((c) => c.propertyId == property.id)
      .toList();

  final openComplaints = propComplaints
      .where(
        (c) =>
            c.status == ComplaintStatus.open ||
            c.status == ComplaintStatus.assigned ||
            c.status == ComplaintStatus.inProgress ||
            c.status == ComplaintStatus.waitingForParts ||
            c.status == ComplaintStatus.reopened,
      )
      .length;

  final createdInPeriod = propComplaints.where((c) {
    final created = c.createdAt;
    if (created == null) return false;
    return !created.isBefore(periodStart) && !created.isAfter(now);
  }).length;

  final resolvedComplaintsInPeriod = propComplaints.where((c) {
    final res = c.resolvedAt;
    if (res == null) return false;
    return !res.isBefore(periodStart) && !res.isAfter(now);
  }).toList();

  final resolvedInPeriod = resolvedComplaintsInPeriod.length;

  // 3. Averages & SLA
  // First response time
  final respondedInPeriod = propComplaints.where((c) {
    final created = c.createdAt;
    if (created == null ||
        created.isBefore(periodStart) ||
        created.isAfter(now)) {
      return false;
    }
    final responseTime =
        c.firstAssignedAt ??
        (c.status != ComplaintStatus.open &&
                c.updatedAt != null &&
                c.updatedAt!.isAfter(created)
            ? c.updatedAt
            : null);
    return responseTime != null && responseTime.isAfter(created);
  }).toList();

  Duration? avgFirstResponse;
  if (respondedInPeriod.isNotEmpty) {
    final totalMillis = respondedInPeriod.fold<int>(0, (sum, c) {
      final created = c.createdAt!;
      final responseTime =
          c.firstAssignedAt ??
          (c.status != ComplaintStatus.open &&
                  c.updatedAt != null &&
                  c.updatedAt!.isAfter(created)
              ? c.updatedAt!
              : created);
      return sum + responseTime.difference(created).inMilliseconds;
    });
    avgFirstResponse = Duration(
      milliseconds: (totalMillis / respondedInPeriod.length).round(),
    );
  }

  // Resolution time
  Duration? avgResolutionTime;
  if (resolvedComplaintsInPeriod.isNotEmpty) {
    final validResolutions = resolvedComplaintsInPeriod
        .where((c) => c.createdAt != null)
        .toList();
    if (validResolutions.isNotEmpty) {
      final totalMillis = validResolutions.fold<int>(0, (sum, c) {
        return sum + c.resolvedAt!.difference(c.createdAt!).inMilliseconds;
      });
      avgResolutionTime = Duration(
        milliseconds: (totalMillis / validResolutions.length).round(),
      );
    }
  }

  // SLA %
  double? slaPercent;
  if (resolvedComplaintsInPeriod.isNotEmpty) {
    final metSlaCount = resolvedComplaintsInPeriod.where((c) {
      final res = c.resolvedAt;
      if (res == null) return false;
      final deadline = expectedResolutionDeadline(c);
      return !res.isAfter(deadline);
    }).length;
    slaPercent = (metSlaCount / resolvedComplaintsInPeriod.length) * 100.0;
  }

  // 4. Quality and operational attention counts
  int repeatVisits = 0;
  int recurringIssues = 0;
  int reopenedCount = 0;
  int waitingForPartsCount = 0;
  int unassignedCount = 0;

  for (final c in propComplaints) {
    if (c.visitCount >= 2 || c.isRepeatVisit) {
      repeatVisits++;
    }

    final sameUnitComplaints = propComplaints
        .where((other) => other.unitId == c.unitId)
        .toList();
    final rInfo = repeatInfo(c, sameUnitComplaints);
    if (rInfo.recurringIssue) {
      recurringIssues++;
    }

    reopenedCount += c.reopenCount;

    if (c.status == ComplaintStatus.waitingForParts) {
      waitingForPartsCount++;
    }

    final isOpenStatus =
        c.status == ComplaintStatus.open ||
        c.status == ComplaintStatus.assigned ||
        c.status == ComplaintStatus.reopened;
    final isUnassigned =
        c.currentTechnicianId == null ||
        c.currentTechnicianId!.trim().isEmpty ||
        c.currentTechnicianId!.toLowerCase() == 'unassigned';
    if (isOpenStatus && isUnassigned) {
      unassignedCount++;
    }
  }

  // 5. Rent Metrics
  final propRentRecords = rentRecords
      .where((r) => r.propertyId == property.id)
      .toList();

  int overdueRentCount = 0;
  double overdueRentAmount = 0.0;
  double totalRentDue = 0.0;
  double totalRentCollected = 0.0;

  for (final record in propRentRecords) {
    totalRentDue += record.amountDue;
    final effStatus = effectiveStatus(record, now);

    if (effStatus == RentStatus.overdue) {
      overdueRentCount++;
      overdueRentAmount += balance(record);
    }

    if (effStatus == RentStatus.paid) {
      totalRentCollected += record.amountDue;
    }
  }

  final collectionRate = totalRentDue > 0
      ? (totalRentCollected / totalRentDue) * 100.0
      : 100.0;

  // 6. Category breakdown
  final categoryBreakdown = <ComplaintCategory, int>{
    for (final cat in ComplaintCategory.values) cat: 0,
  };
  for (final c in propComplaints) {
    categoryBreakdown[c.category] = (categoryBreakdown[c.category] ?? 0) + 1;
  }

  // 7. Technician workload
  final technicianWorkload = <String, int>{};
  for (final c in propComplaints) {
    final techId = c.currentTechnicianId;
    if (techId != null &&
        techId.trim().isNotEmpty &&
        techId.toLowerCase() != 'unassigned') {
      final isOpen =
          c.status == ComplaintStatus.open ||
          c.status == ComplaintStatus.assigned ||
          c.status == ComplaintStatus.inProgress ||
          c.status == ComplaintStatus.waitingForParts ||
          c.status == ComplaintStatus.reopened;
      if (isOpen) {
        technicianWorkload[techId] = (technicianWorkload[techId] ?? 0) + 1;
      }
    }
  }

  // 8. Exactly 6 trend buckets over the period
  final trendBuckets = List<int>.filled(6, 0);
  final bucketDurationMillis = (now.difference(periodStart).inMilliseconds / 6);

  if (bucketDurationMillis > 0) {
    for (final c in propComplaints) {
      final created = c.createdAt;
      if (created == null ||
          created.isBefore(periodStart) ||
          created.isAfter(now)) {
        continue;
      }
      final offsetMillis = created.difference(periodStart).inMilliseconds;
      int bucketIdx = (offsetMillis / bucketDurationMillis).floor();
      if (bucketIdx >= 6) bucketIdx = 5;
      if (bucketIdx < 0) bucketIdx = 0;
      trendBuckets[bucketIdx]++;
    }
  }

  return PropertySummary(
    propertyId: property.id,
    propertyName: property.name,
    periodDays: periodDays,
    totalUnits: totalUnits,
    occupiedUnits: occupiedUnits,
    occupancyRate: occupancyRate,
    openComplaints: openComplaints,
    resolvedInPeriod: resolvedInPeriod,
    createdInPeriod: createdInPeriod,
    avgFirstResponse: avgFirstResponse,
    avgResolutionTime: avgResolutionTime,
    slaPercent: slaPercent,
    repeatVisits: repeatVisits,
    recurringIssues: recurringIssues,
    reopenedCount: reopenedCount,
    waitingForPartsCount: waitingForPartsCount,
    unassignedCount: unassignedCount,
    overdueRentCount: overdueRentCount,
    overdueRentAmount: overdueRentAmount,
    collectionRate: collectionRate,
    totalRentDue: totalRentDue,
    totalRentCollected: totalRentCollected,
    categoryBreakdown: categoryBreakdown,
    technicianWorkload: technicianWorkload,
    trendBuckets: trendBuckets,
    calculatedAt: now,
  );
}

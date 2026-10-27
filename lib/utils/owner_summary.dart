import '../core/enums/complaint_category.dart';
import '../core/enums/complaint_status.dart';
import '../core/enums/rent_status.dart';
import 'visit_history.dart';
import '../core/models/complaint.dart';
import '../core/models/property.dart';
import '../core/models/rent_record.dart';
import 'attention_rules.dart';
import 'property_metrics.dart';

/// Direction of change for a metric compared to previous period.
enum ChangeDirection {
  better,
  worse,
  neutral;

  bool get isBetter => this == ChangeDirection.better;
  bool get isWorse => this == ChangeDirection.worse;
}

/// Represents the delta between current and previous period for a metric.
class MetricDelta {
  const MetricDelta({
    required this.current,
    required this.previous,
    required this.percentChange,
    required this.direction,
    required this.formattedChange,
  });

  final double? current;
  final double? previous;
  final double? percentChange;
  final ChangeDirection direction;
  final String formattedChange;

  bool get hasPrevious => previous != null && percentChange != null;
}

/// Performance metrics for a technician aggregated for the owner portfolio.
class OwnerTechnicianPerformance {
  const OwnerTechnicianPerformance({
    required this.technicianId,
    required this.technicianName,
    required this.jobsCompleted,
    required this.avgResponseTime,
    required this.repeatVisitRate,
  });

  final String technicianId;
  final String technicianName;
  final int jobsCompleted;
  final Duration? avgResponseTime;
  final double repeatVisitRate;
}

/// Aggregated portfolio operational and financial summary for owners.
class OwnerSummary {
  const OwnerSummary({
    required this.periodDays,
    required this.calculatedAt,
    required this.totalProperties,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.occupancyRate,
    required this.openComplaints,
    required this.resolvedInPeriod,
    required this.createdInPeriod,
    required this.repeatVisits,
    required this.reopenedCount,
    required this.waitingForPartsCount,
    required this.avgFirstResponse,
    required this.avgResolutionTime,
    required this.slaPercent,
    required this.responseDelta,
    required this.resolutionDelta,
    required this.slaDelta,
    required this.resolvedDelta,
    required this.totalRentDue,
    required this.totalRentCollected,
    required this.overdueRentCount,
    required this.overdueRentAmount,
    required this.collectionRate,
    required this.collectionDelta,
    required this.topProblemProperties,
    required this.recurringIssues,
    required this.technicianPerformance,
    required this.categoryMix,
    required this.createdTrend,
    required this.resolvedTrend,
    required this.highlights,
    required this.propertySummaries,
  });

  final int periodDays;
  final DateTime calculatedAt;

  // Portfolio KPIs
  final int totalProperties;
  final int totalUnits;
  final int occupiedUnits;
  final double occupancyRate;

  final int openComplaints;
  final int resolvedInPeriod;
  final int createdInPeriod;
  final int repeatVisits;
  final int reopenedCount;
  final int waitingForPartsCount;

  final Duration? avgFirstResponse;
  final Duration? avgResolutionTime;
  final double? slaPercent;

  // Period-over-period Deltas
  final MetricDelta responseDelta;
  final MetricDelta resolutionDelta;
  final MetricDelta slaDelta;
  final MetricDelta resolvedDelta;

  // Rent
  final double totalRentDue;
  final double totalRentCollected;
  final int overdueRentCount;
  final double overdueRentAmount;
  final double collectionRate;
  final MetricDelta collectionDelta;

  // Property Breakdowns
  final List<PropertySummary> topProblemProperties;
  final List<Complaint> recurringIssues;
  final List<OwnerTechnicianPerformance> technicianPerformance;
  final Map<ComplaintCategory, int> categoryMix;

  // Charts data (exactly 6 points per trend)
  final List<int> createdTrend;
  final List<int> resolvedTrend;

  // Plain-language highlights
  final List<String> highlights;

  // Underlying property summaries
  final List<PropertySummary> propertySummaries;

  bool get isEmptyPortfolio => totalProperties == 0;
  bool get isSingleProperty => totalProperties == 1;
}

/// Pure computation aggregating complaints, units, and rent records into [OwnerSummary].
OwnerSummary calculateOwnerSummary({
  required List<Property> properties,
  required List<Unit> units,
  required List<Complaint> complaints,
  required List<RentRecord> rentRecords,
  required int periodDays,
  required DateTime now,
  Map<String, String>? technicianNames,
}) {
  final currentPeriodStart = now.subtract(Duration(days: periodDays));
  final prevPeriodStart = currentPeriodStart.subtract(
    Duration(days: periodDays),
  );

  // 1. Calculate individual property summaries for current period
  final propSummaries = <PropertySummary>[];
  for (final prop in properties) {
    final summary = calculatePropertySummary(
      property: prop,
      units: units,
      complaints: complaints,
      rentRecords: rentRecords,
      periodDays: periodDays,
      now: now,
    );
    propSummaries.add(summary);
  }

  // 2. Aggregate portfolio units and occupancy
  final totalProperties = properties.length;
  final totalUnits = propSummaries.fold<int>(0, (s, p) => s + p.totalUnits);
  final occupiedUnits = propSummaries.fold<int>(
    0,
    (s, p) => s + p.occupiedUnits,
  );
  final occupancyRate = totalUnits > 0
      ? (occupiedUnits / totalUnits) * 100.0
      : 0.0;

  // 3. Current period complaint KPIs
  final openComplaints = propSummaries.fold<int>(
    0,
    (s, p) => s + p.openComplaints,
  );
  final resolvedInPeriod = propSummaries.fold<int>(
    0,
    (s, p) => s + p.resolvedInPeriod,
  );
  final createdInPeriod = propSummaries.fold<int>(
    0,
    (s, p) => s + p.createdInPeriod,
  );
  final repeatVisits = propSummaries.fold<int>(0, (s, p) => s + p.repeatVisits);
  final reopenedCount = propSummaries.fold<int>(
    0,
    (s, p) => s + p.reopenedCount,
  );
  final waitingForPartsCount = propSummaries.fold<int>(
    0,
    (s, p) => s + p.waitingForPartsCount,
  );

  // Overall avg response time
  final respondedComplaints = complaints.where((c) {
    final cr = c.createdAt;
    if (cr == null || cr.isBefore(currentPeriodStart) || cr.isAfter(now)) {
      return false;
    }
    final resp =
        c.firstAssignedAt ??
        (c.status != ComplaintStatus.open &&
                c.updatedAt != null &&
                c.updatedAt!.isAfter(cr)
            ? c.updatedAt
            : null);
    return resp != null && resp.isAfter(cr);
  }).toList();

  Duration? avgFirstResponse;
  if (respondedComplaints.isNotEmpty) {
    final totalMillis = respondedComplaints.fold<int>(0, (sum, c) {
      final cr = c.createdAt!;
      final resp =
          c.firstAssignedAt ??
          (c.status != ComplaintStatus.open &&
                  c.updatedAt != null &&
                  c.updatedAt!.isAfter(cr)
              ? c.updatedAt!
              : cr);
      return sum + resp.difference(cr).inMilliseconds;
    });
    avgFirstResponse = Duration(
      milliseconds: (totalMillis / respondedComplaints.length).round(),
    );
  }

  // Overall avg resolution time
  final resolvedComplaints = complaints.where((c) {
    final res = c.resolvedAt;
    if (res == null) return false;
    return !res.isBefore(currentPeriodStart) && !res.isAfter(now);
  }).toList();

  Duration? avgResolutionTime;
  if (resolvedComplaints.isNotEmpty) {
    final valid = resolvedComplaints.where((c) => c.createdAt != null).toList();
    if (valid.isNotEmpty) {
      final totalMillis = valid.fold<int>(
        0,
        (sum, c) => sum + c.resolvedAt!.difference(c.createdAt!).inMilliseconds,
      );
      avgResolutionTime = Duration(
        milliseconds: (totalMillis / valid.length).round(),
      );
    }
  }

  // Overall SLA %
  double? slaPercent;
  if (resolvedComplaints.isNotEmpty) {
    final metCount = resolvedComplaints.where((c) {
      final res = c.resolvedAt!;
      final deadline = expectedResolutionDeadline(c);
      return !res.isAfter(deadline);
    }).length;
    slaPercent = (metCount / resolvedComplaints.length) * 100.0;
  }

  // 4. Previous period metrics for deltas
  final prevResponded = complaints.where((c) {
    final cr = c.createdAt;
    if (cr == null ||
        cr.isBefore(prevPeriodStart) ||
        cr.isAfter(currentPeriodStart)) {
      return false;
    }
    final resp =
        c.firstAssignedAt ??
        (c.status != ComplaintStatus.open &&
                c.updatedAt != null &&
                c.updatedAt!.isAfter(cr)
            ? c.updatedAt
            : null);
    return resp != null && resp.isAfter(cr);
  }).toList();

  Duration? prevAvgFirstResponse;
  if (prevResponded.isNotEmpty) {
    final totalMillis = prevResponded.fold<int>(0, (sum, c) {
      final cr = c.createdAt!;
      final resp =
          c.firstAssignedAt ??
          (c.status != ComplaintStatus.open &&
                  c.updatedAt != null &&
                  c.updatedAt!.isAfter(cr)
              ? c.updatedAt!
              : cr);
      return sum + resp.difference(cr).inMilliseconds;
    });
    prevAvgFirstResponse = Duration(
      milliseconds: (totalMillis / prevResponded.length).round(),
    );
  }

  final prevResolved = complaints.where((c) {
    final res = c.resolvedAt;
    if (res == null) return false;
    return !res.isBefore(prevPeriodStart) && !res.isAfter(currentPeriodStart);
  }).toList();

  Duration? prevAvgResolutionTime;
  if (prevResolved.isNotEmpty) {
    final valid = prevResolved.where((c) => c.createdAt != null).toList();
    if (valid.isNotEmpty) {
      final totalMillis = valid.fold<int>(
        0,
        (sum, c) => sum + c.resolvedAt!.difference(c.createdAt!).inMilliseconds,
      );
      prevAvgResolutionTime = Duration(
        milliseconds: (totalMillis / valid.length).round(),
      );
    }
  }

  double? prevSlaPercent;
  if (prevResolved.isNotEmpty) {
    final metCount = prevResolved.where((c) {
      final res = c.resolvedAt!;
      final deadline = expectedResolutionDeadline(c);
      return !res.isAfter(deadline);
    }).length;
    prevSlaPercent = (metCount / prevResolved.length) * 100.0;
  }

  // Metric deltas
  final responseDelta = _calculateDurationDelta(
    current: avgFirstResponse,
    previous: prevAvgFirstResponse,
    lowerIsBetter: true,
  );

  final resolutionDelta = _calculateDurationDelta(
    current: avgResolutionTime,
    previous: prevAvgResolutionTime,
    lowerIsBetter: true,
  );

  final slaDelta = _calculatePercentageDelta(
    current: slaPercent,
    previous: prevSlaPercent,
    higherIsBetter: true,
  );

  final resolvedDelta = _calculateNumericDelta(
    current: resolvedInPeriod.toDouble(),
    previous: prevResolved.length.toDouble(),
    higherIsBetter: true,
  );

  // 5. Rent Metrics & Delta
  final totalRentDue = propSummaries.fold<double>(
    0.0,
    (s, p) => s + p.totalRentDue,
  );
  final totalRentCollected = propSummaries.fold<double>(
    0.0,
    (s, p) => s + p.totalRentCollected,
  );
  final overdueRentCount = propSummaries.fold<int>(
    0,
    (s, p) => s + p.overdueRentCount,
  );
  final overdueRentAmount = propSummaries.fold<double>(
    0.0,
    (s, p) => s + p.overdueRentAmount,
  );
  final collectionRate = totalRentDue > 0
      ? (totalRentCollected / totalRentDue) * 100.0
      : 100.0;

  // Prior period rent collection rate
  final prevRentRecords = rentRecords.where((r) {
    final due = r.dueDate;
    return !due.isBefore(prevPeriodStart) && !due.isAfter(currentPeriodStart);
  }).toList();
  double prevDue = 0.0;
  double prevCollected = 0.0;
  for (final r in prevRentRecords) {
    prevDue += r.amountDue;
    if (r.status == RentStatus.paid) {
      prevCollected += r.amountDue;
    }
  }
  final prevCollectionRate = prevDue > 0
      ? (prevCollected / prevDue) * 100.0
      : null;

  final collectionDelta = _calculatePercentageDelta(
    current: collectionRate,
    previous: prevCollectionRate,
    higherIsBetter: true,
  );

  // 6. Top 3 Problem Properties (sorted by lowest healthScore, then most open complaints)
  final sortedProps = List<PropertySummary>.from(propSummaries)
    ..sort((a, b) {
      final scoreCmp = a.healthScore.compareTo(b.healthScore);
      if (scoreCmp != 0) return scoreCmp;
      return b.openComplaints.compareTo(a.openComplaints);
    });
  final topProblemProperties = sortedProps
      .where((p) => p.openComplaints > 0 || p.overdueRentCount > 0)
      .take(3)
      .toList();

  // 7. Recurring issues list
  final recurringIssues = <Complaint>[];
  for (final c in complaints) {
    final sameUnit = complaints.where((o) => o.unitId == c.unitId).toList();
    if (repeatInfo(c, sameUnit).recurringIssue) {
      recurringIssues.add(c);
    }
  }

  // 8. Technician performance
  final techJobs = <String, int>{};
  final techDurations = <String, List<int>>{};
  final techRepeatVisits = <String, int>{};

  for (final c in complaints) {
    final techId = c.currentTechnicianId;
    if (techId == null ||
        techId.trim().isEmpty ||
        techId.toLowerCase() == 'unassigned') {
      continue;
    }
    if (c.status == ComplaintStatus.resolved ||
        c.status == ComplaintStatus.closed) {
      final res = c.resolvedAt;
      if (res != null &&
          !res.isBefore(currentPeriodStart) &&
          !res.isAfter(now)) {
        techJobs[techId] = (techJobs[techId] ?? 0) + 1;
        if (c.createdAt != null) {
          techDurations
              .putIfAbsent(techId, () => [])
              .add(res.difference(c.createdAt!).inMilliseconds);
        }
      }
    }
    if (c.visitCount >= 2 || c.isRepeatVisit) {
      techRepeatVisits[techId] = (techRepeatVisits[techId] ?? 0) + 1;
    }
  }

  final allTechIds = {...techJobs.keys, ...techRepeatVisits.keys};

  final technicianPerformance = <OwnerTechnicianPerformance>[];
  for (final tId in allTechIds) {
    final jobs = techJobs[tId] ?? 0;
    final durations = techDurations[tId] ?? [];
    Duration? avgDuration;
    if (durations.isNotEmpty) {
      final avgMs = (durations.reduce((a, b) => a + b) / durations.length)
          .round();
      avgDuration = Duration(milliseconds: avgMs);
    }
    final repeats = techRepeatVisits[tId] ?? 0;
    final repeatRate = (jobs + repeats) > 0
        ? (repeats / (jobs + repeats)) * 100.0
        : 0.0;
    final name = technicianNames?[tId] ?? tId;

    technicianPerformance.add(
      OwnerTechnicianPerformance(
        technicianId: tId,
        technicianName: name,
        jobsCompleted: jobs,
        avgResponseTime: avgDuration,
        repeatVisitRate: repeatRate,
      ),
    );
  }
  technicianPerformance.sort(
    (a, b) => b.jobsCompleted.compareTo(a.jobsCompleted),
  );

  // 9. Category mix
  final categoryMix = <ComplaintCategory, int>{
    for (final cat in ComplaintCategory.values) cat: 0,
  };
  for (final c in complaints) {
    categoryMix[c.category] = (categoryMix[c.category] ?? 0) + 1;
  }

  // 10. Trends (6 buckets each for created and resolved)
  final createdTrend = List<int>.filled(6, 0);
  final resolvedTrend = List<int>.filled(6, 0);
  final bucketDuration = periodDays * 86400000 / 6;

  for (final c in complaints) {
    final cr = c.createdAt;
    if (cr != null && !cr.isBefore(currentPeriodStart) && !cr.isAfter(now)) {
      final offset = cr.difference(currentPeriodStart).inMilliseconds;
      int idx = (offset / bucketDuration).floor().clamp(0, 5);
      createdTrend[idx]++;
    }
    final res = c.resolvedAt;
    if (res != null && !res.isBefore(currentPeriodStart) && !res.isAfter(now)) {
      final offset = res.difference(currentPeriodStart).inMilliseconds;
      int idx = (offset / bucketDuration).floor().clamp(0, 5);
      resolvedTrend[idx]++;
    }
  }

  // 11. Plain-language highlights
  final highlights = generateOwnerHighlights(
    periodDays: periodDays,
    totalProperties: totalProperties,
    occupiedUnits: occupiedUnits,
    totalUnits: totalUnits,
    occupancyRate: occupancyRate,
    openComplaints: openComplaints,
    resolvedInPeriod: resolvedInPeriod,
    slaPercent: slaPercent,
    responseDelta: responseDelta,
    resolutionDelta: resolutionDelta,
    collectionRate: collectionRate,
    collectionDelta: collectionDelta,
    topProblemProperties: topProblemProperties,
    repeatVisits: repeatVisits,
  );

  return OwnerSummary(
    periodDays: periodDays,
    calculatedAt: now,
    totalProperties: totalProperties,
    totalUnits: totalUnits,
    occupiedUnits: occupiedUnits,
    occupancyRate: occupancyRate,
    openComplaints: openComplaints,
    resolvedInPeriod: resolvedInPeriod,
    createdInPeriod: createdInPeriod,
    repeatVisits: repeatVisits,
    reopenedCount: reopenedCount,
    waitingForPartsCount: waitingForPartsCount,
    avgFirstResponse: avgFirstResponse,
    avgResolutionTime: avgResolutionTime,
    slaPercent: slaPercent,
    responseDelta: responseDelta,
    resolutionDelta: resolutionDelta,
    slaDelta: slaDelta,
    resolvedDelta: resolvedDelta,
    totalRentDue: totalRentDue,
    totalRentCollected: totalRentCollected,
    overdueRentCount: overdueRentCount,
    overdueRentAmount: overdueRentAmount,
    collectionRate: collectionRate,
    collectionDelta: collectionDelta,
    topProblemProperties: topProblemProperties,
    recurringIssues: recurringIssues,
    technicianPerformance: technicianPerformance,
    categoryMix: categoryMix,
    createdTrend: createdTrend,
    resolvedTrend: resolvedTrend,
    highlights: highlights,
    propertySummaries: propSummaries,
  );
}

/// Formulates plain-language highlights from structured metrics without AI.
List<String> generateOwnerHighlights({
  required int periodDays,
  required int totalProperties,
  required int occupiedUnits,
  required int totalUnits,
  required double occupancyRate,
  required int openComplaints,
  required int resolvedInPeriod,
  required double? slaPercent,
  required MetricDelta responseDelta,
  required MetricDelta resolutionDelta,
  required MetricDelta collectionDelta,
  required double collectionRate,
  required List<PropertySummary> topProblemProperties,
  required int repeatVisits,
}) {
  final list = <String>[];

  if (totalProperties == 0) {
    return ['No properties are currently under management in your portfolio.'];
  }

  // Highlight 1: Occupancy
  if (totalUnits > 0) {
    list.add(
      'Portfolio occupancy stands at ${occupancyRate.toStringAsFixed(1)}% '
      '($occupiedUnits of $totalUnits units occupied).',
    );
  }

  // Highlight 2: Response time improvement / degradation
  if (responseDelta.hasPrevious && responseDelta.percentChange != 0) {
    final verb = responseDelta.direction == ChangeDirection.better
        ? 'improved'
        : 'slowed';
    final pct = responseDelta.percentChange!.abs().toStringAsFixed(1);
    list.add('Response time $verb $pct% versus the previous $periodDays days.');
  } else if (resolutionDelta.hasPrevious &&
      resolutionDelta.percentChange != 0) {
    final verb = resolutionDelta.direction == ChangeDirection.better
        ? 'improved'
        : 'increased';
    final pct = resolutionDelta.percentChange!.abs().toStringAsFixed(1);
    list.add(
      'Resolution time $verb $pct% versus the previous $periodDays days.',
    );
  }

  // Highlight 3: SLA & Resolutions
  if (slaPercent != null && resolvedInPeriod > 0) {
    list.add(
      'Resolved $resolvedInPeriod complaints in this period with '
      '${slaPercent.toStringAsFixed(1)}% meeting SLA targets.',
    );
  } else if (openComplaints == 0) {
    list.add(
      'All tenant issues are currently resolved with 0 open complaints.',
    );
  } else {
    list.add(
      'Currently tracking $openComplaints open complaints across the portfolio.',
    );
  }

  // Highlight 4: Rent collection
  if (collectionRate >= 95.0) {
    list.add(
      'Rent collection is strong at ${collectionRate.toStringAsFixed(1)}%.',
    );
  } else {
    list.add(
      'Rent collection rate is ${collectionRate.toStringAsFixed(1)}% '
      'requiring operational follow-up.',
    );
  }

  // Highlight 5: Top problem property attention
  if (topProblemProperties.isNotEmpty) {
    final top = topProblemProperties.first;
    list.add(
      'Primary operational focus: ${top.propertyName} with ${top.openComplaints} open issues '
      'and ${top.overdueRentCount} overdue rent payments.',
    );
  }

  return list;
}

MetricDelta _calculateDurationDelta({
  required Duration? current,
  required Duration? previous,
  required bool lowerIsBetter,
}) {
  if (current == null || previous == null || previous.inMilliseconds == 0) {
    return const MetricDelta(
      current: null,
      previous: null,
      percentChange: null,
      direction: ChangeDirection.neutral,
      formattedChange: '—',
    );
  }
  final curMs = current.inMilliseconds.toDouble();
  final prevMs = previous.inMilliseconds.toDouble();
  final pct = ((curMs - prevMs) / prevMs) * 100.0;

  final ChangeDirection dir;
  if (pct.abs() < 1.0) {
    dir = ChangeDirection.neutral;
  } else if (pct < 0) {
    dir = lowerIsBetter ? ChangeDirection.better : ChangeDirection.worse;
  } else {
    dir = lowerIsBetter ? ChangeDirection.worse : ChangeDirection.better;
  }

  final sign = pct > 0 ? '+' : '';
  return MetricDelta(
    current: curMs,
    previous: prevMs,
    percentChange: pct,
    direction: dir,
    formattedChange: '$sign${pct.toStringAsFixed(1)}%',
  );
}

MetricDelta _calculatePercentageDelta({
  required double? current,
  required double? previous,
  required bool higherIsBetter,
}) {
  if (current == null || previous == null) {
    return const MetricDelta(
      current: null,
      previous: null,
      percentChange: null,
      direction: ChangeDirection.neutral,
      formattedChange: '—',
    );
  }
  final diff = current - previous;
  final ChangeDirection dir;
  if (diff.abs() < 0.1) {
    dir = ChangeDirection.neutral;
  } else if (diff > 0) {
    dir = higherIsBetter ? ChangeDirection.better : ChangeDirection.worse;
  } else {
    dir = higherIsBetter ? ChangeDirection.worse : ChangeDirection.better;
  }

  final sign = diff > 0 ? '+' : '';
  return MetricDelta(
    current: current,
    previous: previous,
    percentChange: diff,
    direction: dir,
    formattedChange: '$sign${diff.toStringAsFixed(1)}%',
  );
}

MetricDelta _calculateNumericDelta({
  required double current,
  required double previous,
  required bool higherIsBetter,
}) {
  if (previous == 0) {
    return MetricDelta(
      current: current,
      previous: previous,
      percentChange: null,
      direction: current > 0 ? ChangeDirection.better : ChangeDirection.neutral,
      formattedChange: current > 0 ? '+${current.round()}' : '0',
    );
  }
  final pct = ((current - previous) / previous) * 100.0;
  final ChangeDirection dir;
  if (pct.abs() < 1.0) {
    dir = ChangeDirection.neutral;
  } else if (pct > 0) {
    dir = higherIsBetter ? ChangeDirection.better : ChangeDirection.worse;
  } else {
    dir = higherIsBetter ? ChangeDirection.worse : ChangeDirection.better;
  }

  final sign = pct > 0 ? '+' : '';
  return MetricDelta(
    current: current,
    previous: previous,
    percentChange: pct,
    direction: dir,
    formattedChange: '$sign${pct.toStringAsFixed(1)}%',
  );
}

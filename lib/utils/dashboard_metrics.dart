import 'package:flutter/foundation.dart';

import '../core/enums/complaint_status.dart';
import '../core/models/complaint.dart';
import 'attention_rules.dart';
import 'display_formatters.dart';

@immutable
class StatMetric {
  final String label;
  final String value;
  final double? change; // absent when no comparable previous period exists
  final bool isPositiveGood; // for display semantics if needed

  const StatMetric({
    required this.label,
    required this.value,
    this.change,
    this.isPositiveGood = true,
  });
}

@immutable
class TodayMetrics {
  final StatMetric open;
  final StatMetric resolvedToday;
  final StatMetric avgFirstResponse;
  final StatMetric slaPercent;

  const TodayMetrics({
    required this.open,
    required this.resolvedToday,
    required this.avgFirstResponse,
    required this.slaPercent,
  });
}

TodayMetrics calculateTodayMetrics({
  required List<Complaint> complaints,
  required DateTime now,
}) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

  // 1. Open complaints
  final openNow = complaints
      .where(
        (c) =>
            c.status == ComplaintStatus.open ||
            c.status == ComplaintStatus.assigned ||
            c.status == ComplaintStatus.inProgress ||
            c.status == ComplaintStatus.waitingForParts ||
            c.status == ComplaintStatus.reopened,
      )
      .length;

  // Approximate open yesterday: created before today and (closed/resolved after yesterday or not closed/resolved)
  final openYesterday = complaints.where((c) {
    final created = c.createdAt ?? DateTime(2000);
    if (created.isAfter(startOfToday)) return false;
    final res = c.resolvedAt;
    if (res != null && res.isBefore(startOfYesterday)) return false;
    return true;
  }).length;

  final openDiff = (openYesterday == 0)
      ? null
      : ((openNow - openYesterday) / openYesterday) * 100;

  // 2. Resolved today
  final resolvedTodayCount = complaints.where((c) {
    final res = c.resolvedAt;
    return res != null && !res.isBefore(startOfToday) && !res.isAfter(now);
  }).length;

  final resolvedYesterdayCount = complaints.where((c) {
    final res = c.resolvedAt;
    return res != null &&
        !res.isBefore(startOfYesterday) &&
        res.isBefore(startOfToday);
  }).length;

  final resolvedDiff = (resolvedYesterdayCount == 0)
      ? null
      : ((resolvedTodayCount - resolvedYesterdayCount) /
                resolvedYesterdayCount) *
            100;

  // 3. Avg first response time (in hours or minutes)
  final respondedComplaints = complaints.where((c) {
    final created = c.createdAt ?? now;
    final updated = c.updatedAt ?? created;
    return c.status != ComplaintStatus.open && updated.isAfter(created);
  }).toList();

  double avgResponseHours = 0.0;
  if (respondedComplaints.isNotEmpty) {
    final totalHours = respondedComplaints.fold<double>(0.0, (sum, c) {
      final created = c.createdAt ?? now;
      final updated = c.updatedAt ?? created;
      final diff = updated.difference(created).inMinutes / 60.0;
      return sum + diff;
    });
    avgResponseHours = totalHours / respondedComplaints.length;
  }

  final avgResponseStr = formatHumanDuration(
    Duration(minutes: (avgResponseHours * 60).round()),
  );

  // 4. SLA %
  final slaPopulation = complaints
      .where((c) => c.status != ComplaintStatus.cancelled)
      .toList();

  double slaRatio = 100.0;
  if (slaPopulation.isNotEmpty) {
    final metSla = slaPopulation
        .where((c) => isComplaintWithinSla(c, now))
        .length;
    slaRatio = (metSla / slaPopulation.length) * 100.0;
  }

  return TodayMetrics(
    open: StatMetric(
      label: 'Open',
      value: '$openNow',
      change: openDiff,
      isPositiveGood: false,
    ),
    resolvedToday: StatMetric(
      label: 'Resolved today',
      value: '$resolvedTodayCount',
      change: resolvedDiff,
      isPositiveGood: true,
    ),
    avgFirstResponse: StatMetric(
      label: 'Avg first response',
      value: avgResponseStr,
      change: null,
      isPositiveGood: false,
    ),
    slaPercent: StatMetric(
      label: 'SLA %',
      value: '${slaRatio.round()}%',
      change: null,
      isPositiveGood: true,
    ),
  );
}

import 'package:flutter/foundation.dart';
import '../core/enums/complaint_priority.dart';
import '../core/enums/complaint_status.dart';
import '../core/enums/rent_status.dart';
import '../core/models/complaint.dart';
import '../core/models/rent_record.dart';
import 'complaint_query.dart';
import 'rent_rules.dart';
import 'visit_history.dart';

enum AttentionSeverity {
  amber,
  urgent,
}

enum AttentionType {
  unassigned,
  slaRiskOrBreached,
  urgentUnvisited,
  recurringIssues,
  waitingForParts,
  unconfirmedResolution,
  reopened,
  overdueRent,
  brokenPromises,
}

@immutable
class AttentionItem {
  final AttentionType type;
  final AttentionSeverity severity;
  final String title;
  final String subtitle;
  final int count;
  final Duration oldestAge;
  final ComplaintFilter? targetFilter;
  final String? targetRoute;
  final List<Complaint> matchedComplaints;

  const AttentionItem({
    required this.type,
    required this.severity,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.oldestAge,
    this.targetFilter,
    this.targetRoute,
    this.matchedComplaints = const [],
  });

  String get oldestAgeLabel {
    final hours = oldestAge.inHours;
    if (hours < 1) {
      final mins = oldestAge.inMinutes;
      return 'oldest ${mins}m';
    }
    if (hours < 24) {
      return 'oldest ${hours}h';
    }
    final days = oldestAge.inDays;
    return 'oldest ${days}d';
  }
}

class AttentionAnalysis {
  final List<AttentionItem> items;
  final int healthScore;

  const AttentionAnalysis({
    required this.items,
    required this.healthScore,
  });

  bool get isAllClear => items.isEmpty;
}

AttentionAnalysis analyzeAttention({
  required List<Complaint> complaints,
  required List<RentRecord> rentRecords,
  required DateTime now,
}) {
  final items = <AttentionItem>[];

  // 1. Unassigned complaints (>4 h amber, >24 h urgent)
  // ComplaintStatus.open without assigned technician
  final unassignedList = complaints.where((c) {
    final isOpen = c.status == ComplaintStatus.open;
    final noTech = c.assignedTechnicianId == null || c.assignedTechnicianId!.isEmpty;
    if (!isOpen || !noTech) return false;
    final age = now.difference(c.createdAt);
    return age.inHours >= 4;
  }).toList();

  if (unassignedList.isNotEmpty) {
    unassignedList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final oldestAge = now.difference(unassignedList.first.createdAt);
    final hasUrgent = unassignedList.any((c) => now.difference(c.createdAt).inHours >= 24);

    items.add(AttentionItem(
      type: AttentionType.unassigned,
      severity: hasUrgent ? AttentionSeverity.urgent : AttentionSeverity.amber,
      title: 'Unassigned complaints',
      subtitle: '${unassignedList.length} awaiting technician assignment',
      count: unassignedList.length,
      oldestAge: oldestAge,
      targetFilter: const ComplaintFilter(
        statuses: {ComplaintStatus.open},
        technicianId: 'unassigned',
      ),
      matchedComplaints: unassignedList,
    ));
  }

  // 2. SLA breached or at risk (response not recorded in time or past expected resolution)
  final slaList = complaints.where((c) {
    if (c.status == ComplaintStatus.closed || c.status == ComplaintStatus.cancelled) {
      return false;
    }
    // Breached resolution target if resolvedAt is null and expectedResolution is past
    if (c.expectedResolution != null && now.isAfter(c.expectedResolution!) && c.resolvedAt == null) {
      return true;
    }
    // Breached response SLA if open and age > SLA response target (e.g. 2h for urgent, 6h for high, 24h for normal)
    final age = now.difference(c.createdAt);
    if (c.status == ComplaintStatus.open) {
      if (c.priority == ComplaintPriority.urgent && age.inHours >= 2) return true;
      if (c.priority == ComplaintPriority.high && age.inHours >= 6) return true;
      if (age.inHours >= 24) return true;
    }
    return false;
  }).toList();

  if (slaList.isNotEmpty) {
    slaList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final oldestAge = now.difference(slaList.first.createdAt);
    // If any breached expectedResolution or urgent breached, it is urgent
    final isUrgent = slaList.any((c) =>
        (c.expectedResolution != null && now.isAfter(c.expectedResolution!)) ||
        (c.priority == ComplaintPriority.urgent));

    items.add(AttentionItem(
      type: AttentionType.slaRiskOrBreached,
      severity: isUrgent ? AttentionSeverity.urgent : AttentionSeverity.amber,
      title: 'SLA breached or at risk',
      subtitle: '${slaList.length} past response or resolution threshold',
      count: slaList.length,
      oldestAge: oldestAge,
      targetFilter: ComplaintFilter(
        statuses: {
          ComplaintStatus.open,
          ComplaintStatus.assigned,
          ComplaintStatus.inProgress,
          ComplaintStatus.waitingForParts,
          ComplaintStatus.reopened,
        },
      ),
      matchedComplaints: slaList,
    ));
  }

  // 3. Urgent or high priority complaints not yet accepted or visited
  final urgentUnvisitedList = complaints.where((c) {
    final isUrgentOrHigh =
        c.priority == ComplaintPriority.urgent || c.priority == ComplaintPriority.high;
    if (!isUrgentOrHigh) return false;
    if (c.status != ComplaintStatus.open && c.status != ComplaintStatus.assigned) {
      return false;
    }
    return c.visitCount == 0;
  }).toList();

  if (urgentUnvisitedList.isNotEmpty) {
    urgentUnvisitedList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final oldestAge = now.difference(urgentUnvisitedList.first.createdAt);
    final hasUrgent =
        urgentUnvisitedList.any((c) => c.priority == ComplaintPriority.urgent);

    items.add(AttentionItem(
      type: AttentionType.urgentUnvisited,
      severity: hasUrgent ? AttentionSeverity.urgent : AttentionSeverity.amber,
      title: 'Urgent/high issues unvisited',
      subtitle: '${urgentUnvisitedList.length} awaiting initial visit',
      count: urgentUnvisitedList.length,
      oldestAge: oldestAge,
      targetFilter: const ComplaintFilter(
        priorities: {ComplaintPriority.urgent, ComplaintPriority.high},
        statuses: {ComplaintStatus.open, ComplaintStatus.assigned},
      ),
      matchedComplaints: urgentUnvisitedList,
    ));
  }

  // 4. Recurring issues (2 or more complaints in the same unit and category within 60 days)
  final recurringList = complaints.where((c) {
    if (c.status == ComplaintStatus.closed || c.status == ComplaintStatus.cancelled) {
      return false;
    }
    final info = repeatInfo(c, complaints);
    return info.recurringIssue;
  }).toList();

  if (recurringList.isNotEmpty) {
    recurringList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final oldestAge = now.difference(recurringList.first.createdAt);

    items.add(AttentionItem(
      type: AttentionType.recurringIssues,
      severity: AttentionSeverity.amber,
      title: 'Recurring issues',
      subtitle: '${recurringList.length} repeated unit complaints in 60d',
      count: recurringList.length,
      oldestAge: oldestAge,
      targetFilter: ComplaintFilter(
        statuses: {
          ComplaintStatus.open,
          ComplaintStatus.assigned,
          ComplaintStatus.inProgress,
          ComplaintStatus.waitingForParts,
          ComplaintStatus.reopened,
        },
      ),
      matchedComplaints: recurringList,
    ));
  }

  // 5. Waiting for parts past expected date or overdue (>48h)
  final partsOverdueList = complaints.where((c) {
    if (c.status != ComplaintStatus.waitingForParts) return false;
    final age = now.difference(c.updatedAt);
    return age.inHours >= 48;
  }).toList();

  if (partsOverdueList.isNotEmpty) {
    partsOverdueList.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    final oldestAge = now.difference(partsOverdueList.first.updatedAt);

    items.add(AttentionItem(
      type: AttentionType.waitingForParts,
      severity: AttentionSeverity.amber,
      title: 'Parts delayed or waiting',
      subtitle: '${partsOverdueList.length} waiting for parts >48h',
      count: partsOverdueList.length,
      oldestAge: oldestAge,
      targetFilter: const ComplaintFilter(
        statuses: {ComplaintStatus.waitingForParts},
      ),
      matchedComplaints: partsOverdueList,
    ));
  }

  // 6. Resolved but not confirmed by the tenant for >48h
  final unconfirmedList = complaints.where((c) {
    if (c.status != ComplaintStatus.resolved) return false;
    final resolvedTime = c.resolvedAt ?? c.updatedAt;
    final age = now.difference(resolvedTime);
    return age.inHours >= 48;
  }).toList();

  if (unconfirmedList.isNotEmpty) {
    unconfirmedList.sort((a, b) =>
        (a.resolvedAt ?? a.updatedAt).compareTo(b.resolvedAt ?? b.updatedAt));
    final oldestAge =
        now.difference(unconfirmedList.first.resolvedAt ?? unconfirmedList.first.updatedAt);

    items.add(AttentionItem(
      type: AttentionType.unconfirmedResolution,
      severity: AttentionSeverity.amber,
      title: 'Unconfirmed resolutions',
      subtitle: '${unconfirmedList.length} resolved >48h without tenant confirmation',
      count: unconfirmedList.length,
      oldestAge: oldestAge,
      targetFilter: const ComplaintFilter(
        statuses: {ComplaintStatus.resolved},
      ),
      matchedComplaints: unconfirmedList,
    ));
  }

  // 7. Reopened complaints
  final reopenedList = complaints.where((c) {
    return c.status == ComplaintStatus.reopened;
  }).toList();

  if (reopenedList.isNotEmpty) {
    reopenedList.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    final oldestAge = now.difference(reopenedList.first.updatedAt);

    items.add(AttentionItem(
      type: AttentionType.reopened,
      severity: AttentionSeverity.urgent,
      title: 'Reopened complaints',
      subtitle: '${reopenedList.length} complaints reopened by tenant',
      count: reopenedList.length,
      oldestAge: oldestAge,
      targetFilter: const ComplaintFilter(
        statuses: {ComplaintStatus.reopened},
      ),
      matchedComplaints: reopenedList,
    ));
  }

  // 8. Overdue rent (count and total)
  final overdueRent = rentRecords.where((r) {
    final status = effectiveStatus(r, now);
    return status == RentStatus.overdue;
  }).toList();

  if (overdueRent.isNotEmpty) {
    final totalOverdue = overdueRent.fold<double>(
      0.0,
      (sum, r) => sum + balance(r),
    );
    // Find oldest overdue month
    overdueRent.sort((a, b) => a.month.compareTo(b.month));
    final oldestAge = now.difference(overdueRent.first.month);

    items.add(AttentionItem(
      type: AttentionType.overdueRent,
      severity: AttentionSeverity.urgent,
      title: 'Overdue rent',
      subtitle: '${overdueRent.length} units overdue (${formatIndianCurrency(totalOverdue)})',
      count: overdueRent.length,
      oldestAge: oldestAge,
      targetRoute: '/rent?status=overdue',
    ));
  }

  // 9. Broken promises due today / broken promises
  final brokenPromiseRecords = rentRecords.where((r) {
    if (r.status == RentStatus.paid) return false;
    // Check if brokenPromises utility returns > 0 or promise date <= today
    final brokenCount = brokenPromises(r.followUps, now);
    if (brokenCount > 0) return true;
    if (r.status == RentStatus.promised && r.promisedDate != null) {
      return !now.isBefore(r.promisedDate!);
    }
    return false;
  }).toList();

  if (brokenPromiseRecords.isNotEmpty) {
    brokenPromiseRecords.sort((a, b) => (a.promisedDate ?? a.month).compareTo(b.promisedDate ?? b.month));
    final oldestAge = now.difference(brokenPromiseRecords.first.promisedDate ?? brokenPromiseRecords.first.month);

    items.add(AttentionItem(
      type: AttentionType.brokenPromises,
      severity: AttentionSeverity.amber,
      title: 'Broken payment promises',
      subtitle: '${brokenPromiseRecords.length} promise to pay due or past',
      count: brokenPromiseRecords.length,
      oldestAge: oldestAge,
      targetRoute: '/rent?status=promised',
    ));
  }

  // Sort by severity (urgent first, then amber), then age descending (oldest first)
  items.sort((a, b) {
    if (a.severity != b.severity) {
      return a.severity == AttentionSeverity.urgent ? -1 : 1;
    }
    return b.oldestAge.compareTo(a.oldestAge);
  });

  // Calculate health score: 100 - (urgent * 15 + amber * 5)
  var urgentCount = 0;
  var amberCount = 0;
  for (final item in items) {
    if (item.severity == AttentionSeverity.urgent) {
      urgentCount += item.count;
    } else {
      amberCount += item.count;
    }
  }

  final deduction = (urgentCount * 12) + (amberCount * 4);
  final healthScore = (100 - deduction).clamp(0, 100);

  return AttentionAnalysis(
    items: items,
    healthScore: healthScore,
  );
}

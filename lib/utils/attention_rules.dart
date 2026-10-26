import 'package:flutter/foundation.dart';

import '../core/enums/complaint_priority.dart';
import '../core/enums/complaint_status.dart';
import '../core/enums/rent_status.dart';
import '../core/models/complaint.dart';
import '../core/models/rent_record.dart';
import 'app_clock.dart';
import 'complaint_query.dart';
import 'rent_rules.dart';
import 'visit_history.dart';

enum AttentionSeverity { amber, urgent }

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

  const AttentionAnalysis({required this.items, required this.healthScore});

  bool get isAllClear => items.isEmpty;
}

/// Computes expected resolution deadline based on complaint priority.
DateTime expectedResolutionDeadline(Complaint c) {
  final created = c.createdAt ?? AppClock.nowDateTime;
  final hours = switch (c.priority) {
    ComplaintPriority.urgent => 24,
    ComplaintPriority.high => 48,
    ComplaintPriority.medium => 72,
    ComplaintPriority.low => 120,
  };
  return created.add(Duration(hours: hours));
}

/// Computes expected first-response SLA target hours based on complaint priority.
int expectedResponseSlaHours(Complaint c) {
  return switch (c.priority) {
    ComplaintPriority.urgent => 2,
    ComplaintPriority.high => 6,
    ComplaintPriority.medium => 24,
    ComplaintPriority.low => 48,
  };
}

AttentionAnalysis analyzeAttention({
  required List<Complaint> complaints,
  required List<RentRecord> rentRecords,
  required DateTime now,
}) {
  final items = <AttentionItem>[];

  // 1. Unassigned complaints (>4 h amber, >24 h urgent)
  final unassignedList = complaints.where((c) {
    final isOpen = c.status == ComplaintStatus.open;
    final noTech =
        c.currentTechnicianId == null || c.currentTechnicianId!.isEmpty;
    if (!isOpen || !noTech) return false;
    final created = c.createdAt ?? now;
    final age = now.difference(created);
    return age.inHours >= 4;
  }).toList();

  if (unassignedList.isNotEmpty) {
    unassignedList.sort(
      (a, b) => (a.createdAt ?? now).compareTo(b.createdAt ?? now),
    );
    final oldestAge = now.difference(unassignedList.first.createdAt ?? now);
    final hasUrgent = unassignedList.any(
      (c) => now.difference(c.createdAt ?? now).inHours >= 24,
    );

    items.add(
      AttentionItem(
        type: AttentionType.unassigned,
        severity: hasUrgent
            ? AttentionSeverity.urgent
            : AttentionSeverity.amber,
        title: 'Unassigned complaints',
        subtitle: '${unassignedList.length} awaiting technician assignment',
        count: unassignedList.length,
        oldestAge: oldestAge,
        targetFilter: const ComplaintFilter(
          statuses: {ComplaintStatus.open},
          technicianId: 'unassigned',
        ),
        matchedComplaints: unassignedList,
      ),
    );
  }

  // 2. SLA breached or at risk (response not recorded in time or past expected resolution)
  final slaList = complaints.where((c) {
    if (c.status == ComplaintStatus.closed ||
        c.status == ComplaintStatus.cancelled) {
      return false;
    }
    final created = c.createdAt ?? now;
    final deadline = expectedResolutionDeadline(c);

    // Breached resolution target if resolvedAt is null and past deadline
    if (c.resolvedAt == null && now.isAfter(deadline)) {
      return true;
    }

    // Breached response SLA if open and no technician assigned past response target
    if (c.status == ComplaintStatus.open && c.firstAssignedAt == null) {
      final responseTarget = expectedResponseSlaHours(c);
      if (now.difference(created).inHours >= responseTarget) {
        return true;
      }
    }
    return false;
  }).toList();

  if (slaList.isNotEmpty) {
    slaList.sort((a, b) => (a.createdAt ?? now).compareTo(b.createdAt ?? now));
    final oldestAge = now.difference(slaList.first.createdAt ?? now);
    final isUrgent = slaList.any((c) {
      final deadline = expectedResolutionDeadline(c);
      return (c.resolvedAt == null && now.isAfter(deadline)) ||
          c.priority == ComplaintPriority.urgent;
    });

    items.add(
      AttentionItem(
        type: AttentionType.slaRiskOrBreached,
        severity: isUrgent ? AttentionSeverity.urgent : AttentionSeverity.amber,
        title: 'SLA breached or at risk',
        subtitle: '${slaList.length} past response or resolution threshold',
        count: slaList.length,
        oldestAge: oldestAge,
        targetFilter: const ComplaintFilter(
          statuses: {
            ComplaintStatus.open,
            ComplaintStatus.assigned,
            ComplaintStatus.inProgress,
            ComplaintStatus.waitingForParts,
            ComplaintStatus.reopened,
          },
        ),
        matchedComplaints: slaList,
      ),
    );
  }

  // 3. Urgent or high priority complaints not yet accepted or visited
  final urgentUnvisitedList = complaints.where((c) {
    final isUrgentOrHigh =
        c.priority == ComplaintPriority.urgent ||
        c.priority == ComplaintPriority.high;
    if (!isUrgentOrHigh) return false;
    if (c.status != ComplaintStatus.open &&
        c.status != ComplaintStatus.assigned) {
      return false;
    }
    return c.visitCount == 0;
  }).toList();

  if (urgentUnvisitedList.isNotEmpty) {
    urgentUnvisitedList.sort(
      (a, b) => (a.createdAt ?? now).compareTo(b.createdAt ?? now),
    );
    final oldestAge = now.difference(
      urgentUnvisitedList.first.createdAt ?? now,
    );
    final hasUrgent = urgentUnvisitedList.any(
      (c) => c.priority == ComplaintPriority.urgent,
    );

    items.add(
      AttentionItem(
        type: AttentionType.urgentUnvisited,
        severity: hasUrgent
            ? AttentionSeverity.urgent
            : AttentionSeverity.amber,
        title: 'Urgent/high issues unvisited',
        subtitle: '${urgentUnvisitedList.length} awaiting initial visit',
        count: urgentUnvisitedList.length,
        oldestAge: oldestAge,
        targetFilter: const ComplaintFilter(
          priorities: {ComplaintPriority.urgent, ComplaintPriority.high},
          statuses: {ComplaintStatus.open, ComplaintStatus.assigned},
        ),
        matchedComplaints: urgentUnvisitedList,
      ),
    );
  }

  // 4. Recurring issues (2 or more complaints in the same unit and category within 60 days)
  final recurringList = complaints.where((c) {
    if (c.status == ComplaintStatus.closed ||
        c.status == ComplaintStatus.cancelled) {
      return false;
    }
    final info = repeatInfo(c, complaints);
    return info.recurringIssue;
  }).toList();

  if (recurringList.isNotEmpty) {
    recurringList.sort(
      (a, b) => (a.createdAt ?? now).compareTo(b.createdAt ?? now),
    );
    final oldestAge = now.difference(recurringList.first.createdAt ?? now);

    items.add(
      AttentionItem(
        type: AttentionType.recurringIssues,
        severity: AttentionSeverity.amber,
        title: 'Recurring issues',
        subtitle: '${recurringList.length} repeated unit complaints in 60d',
        count: recurringList.length,
        oldestAge: oldestAge,
        targetFilter: const ComplaintFilter(
          statuses: {
            ComplaintStatus.open,
            ComplaintStatus.assigned,
            ComplaintStatus.inProgress,
            ComplaintStatus.waitingForParts,
            ComplaintStatus.reopened,
          },
        ),
        matchedComplaints: recurringList,
      ),
    );
  }

  // 5. Waiting for parts past 48h
  final partsOverdueList = complaints.where((c) {
    if (c.status != ComplaintStatus.waitingForParts) return false;
    final updated = c.updatedAt ?? c.createdAt ?? now;
    final age = now.difference(updated);
    return age.inHours >= 48;
  }).toList();

  if (partsOverdueList.isNotEmpty) {
    partsOverdueList.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt ?? now;
      final bDate = b.updatedAt ?? b.createdAt ?? now;
      return aDate.compareTo(bDate);
    });
    final oldestDate =
        partsOverdueList.first.updatedAt ??
        partsOverdueList.first.createdAt ??
        now;
    final oldestAge = now.difference(oldestDate);

    items.add(
      AttentionItem(
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
      ),
    );
  }

  // 6. Resolved but not confirmed by the tenant for >48h
  final unconfirmedList = complaints.where((c) {
    if (c.status != ComplaintStatus.resolved) return false;
    final resolvedTime = c.resolvedAt ?? c.updatedAt ?? c.createdAt ?? now;
    final age = now.difference(resolvedTime);
    return age.inHours >= 48;
  }).toList();

  if (unconfirmedList.isNotEmpty) {
    unconfirmedList.sort((a, b) {
      final aTime = a.resolvedAt ?? a.updatedAt ?? a.createdAt ?? now;
      final bTime = b.resolvedAt ?? b.updatedAt ?? b.createdAt ?? now;
      return aTime.compareTo(bTime);
    });
    final oldestTime =
        unconfirmedList.first.resolvedAt ??
        unconfirmedList.first.updatedAt ??
        unconfirmedList.first.createdAt ??
        now;
    final oldestAge = now.difference(oldestTime);

    items.add(
      AttentionItem(
        type: AttentionType.unconfirmedResolution,
        severity: AttentionSeverity.amber,
        title: 'Unconfirmed resolutions',
        subtitle:
            '${unconfirmedList.length} resolved >48h without tenant confirmation',
        count: unconfirmedList.length,
        oldestAge: oldestAge,
        targetFilter: const ComplaintFilter(
          statuses: {ComplaintStatus.resolved},
        ),
        matchedComplaints: unconfirmedList,
      ),
    );
  }

  // 7. Reopened complaints
  final reopenedList = complaints.where((c) {
    return c.status == ComplaintStatus.reopened;
  }).toList();

  if (reopenedList.isNotEmpty) {
    reopenedList.sort((a, b) {
      final aTime = a.reopenedAt ?? a.updatedAt ?? a.createdAt ?? now;
      final bTime = b.reopenedAt ?? b.updatedAt ?? b.createdAt ?? now;
      return aTime.compareTo(bTime);
    });
    final oldestTime =
        reopenedList.first.reopenedAt ??
        reopenedList.first.updatedAt ??
        reopenedList.first.createdAt ??
        now;
    final oldestAge = now.difference(oldestTime);

    items.add(
      AttentionItem(
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
      ),
    );
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
    overdueRent.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final oldestAge = now.difference(overdueRent.first.dueDate);

    items.add(
      AttentionItem(
        type: AttentionType.overdueRent,
        severity: AttentionSeverity.urgent,
        title: 'Overdue rent',
        subtitle:
            '${overdueRent.length} units overdue (${formatIndianCurrency(totalOverdue)})',
        count: overdueRent.length,
        oldestAge: oldestAge,
        targetRoute: '/rent?status=overdue',
      ),
    );
  }

  // 9. Broken payment promises due today or past
  final brokenPromiseRecords = rentRecords.where((r) {
    if (r.status == RentStatus.paid) return false;
    if (r.status == RentStatus.promised) {
      final promiseDate = r.nextFollowUpAt ?? r.dueDate;
      return !now.isBefore(promiseDate);
    }
    return false;
  }).toList();

  if (brokenPromiseRecords.isNotEmpty) {
    brokenPromiseRecords.sort((a, b) {
      final aDate = a.nextFollowUpAt ?? a.dueDate;
      final bDate = b.nextFollowUpAt ?? b.dueDate;
      return aDate.compareTo(bDate);
    });
    final oldestDate =
        brokenPromiseRecords.first.nextFollowUpAt ??
        brokenPromiseRecords.first.dueDate;
    final oldestAge = now.difference(oldestDate);

    items.add(
      AttentionItem(
        type: AttentionType.brokenPromises,
        severity: AttentionSeverity.amber,
        title: 'Broken payment promises',
        subtitle: '${brokenPromiseRecords.length} promise to pay due or past',
        count: brokenPromiseRecords.length,
        oldestAge: oldestAge,
        targetRoute: '/rent?status=promised',
      ),
    );
  }

  // Sort by severity (urgent first, then amber), then age descending (oldest first)
  items.sort((a, b) {
    if (a.severity != b.severity) {
      return a.severity == AttentionSeverity.urgent ? -1 : 1;
    }
    return b.oldestAge.compareTo(a.oldestAge);
  });

  // Calculate health score: 100 - (urgent * 12 + amber * 4)
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

  return AttentionAnalysis(items: items, healthScore: healthScore);
}

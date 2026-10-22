import 'package:flutter/material.dart';

import '../core/enums/complaint_category.dart';
import '../core/enums/complaint_priority.dart';
import '../core/enums/complaint_status.dart';
import '../core/fixtures/sample_fixtures.dart';
import '../core/models/complaint.dart';

/// Available sort options for complaint list.
enum ComplaintSort {
  newest('Newest'),
  oldest('Oldest'),
  priority('Priority'),
  lastUpdated('Last updated'),
  longestOpen('Longest open');

  const ComplaintSort(this.label);
  final String label;
}

/// Representation of an active filter chip displayed in UI.
class FilterChipData {
  const FilterChipData({required this.id, required this.label, this.onRemove});

  final String id;
  final String label;
  final ComplaintFilter Function(ComplaintFilter current)? onRemove;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterChipData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// Immutable complaint filter model supporting text search, faceted filtering,
/// range constraints, and sort specification.
@immutable
class ComplaintFilter {
  const ComplaintFilter({
    this.text,
    this.statuses = const <ComplaintStatus>{},
    this.priorities = const <ComplaintPriority>{},
    this.categories = const <ComplaintCategory>{},
    this.propertyId,
    this.unitId,
    this.technicianId,
    this.repeatOnly = false,
    this.overdueOnly = false,
    this.createdDateRange,
    this.sort = ComplaintSort.newest,
  });

  final String? text;
  final Set<ComplaintStatus> statuses;
  final Set<ComplaintPriority> priorities;
  final Set<ComplaintCategory> categories;
  final String? propertyId;
  final String? unitId;
  final String? technicianId;
  final bool repeatOnly;
  final bool overdueOnly;
  final DateTimeRange? createdDateRange;
  final ComplaintSort sort;

  /// Returns true if no filter constraint is currently active.
  bool get isEmpty =>
      (text == null || text!.trim().isEmpty) &&
      statuses.isEmpty &&
      priorities.isEmpty &&
      categories.isEmpty &&
      (propertyId == null || propertyId!.trim().isEmpty) &&
      (unitId == null || unitId!.trim().isEmpty) &&
      (technicianId == null || technicianId!.trim().isEmpty) &&
      !repeatOnly &&
      !overdueOnly &&
      createdDateRange == null;

  /// Returns total number of active filter criteria.
  int get activeCount {
    var count = 0;
    if (text != null && text!.trim().isNotEmpty) count++;
    count += statuses.length;
    count += priorities.length;
    count += categories.length;
    if (propertyId != null && propertyId!.trim().isNotEmpty) count++;
    if (unitId != null && unitId!.trim().isNotEmpty) count++;
    if (technicianId != null && technicianId!.trim().isNotEmpty) count++;
    if (repeatOnly) count++;
    if (overdueOnly) count++;
    if (createdDateRange != null) count++;
    return count;
  }

  ComplaintFilter copyWith({
    String? text,
    bool clearText = false,
    Set<ComplaintStatus>? statuses,
    Set<ComplaintPriority>? priorities,
    Set<ComplaintCategory>? categories,
    String? propertyId,
    bool clearPropertyId = false,
    String? unitId,
    bool clearUnitId = false,
    String? technicianId,
    bool clearTechnicianId = false,
    bool? repeatOnly,
    bool? overdueOnly,
    DateTimeRange? createdDateRange,
    bool clearCreatedDateRange = false,
    ComplaintSort? sort,
  }) {
    return ComplaintFilter(
      text: clearText ? null : (text ?? this.text),
      statuses: statuses ?? this.statuses,
      priorities: priorities ?? this.priorities,
      categories: categories ?? this.categories,
      propertyId: clearPropertyId ? null : (propertyId ?? this.propertyId),
      unitId: clearUnitId ? null : (unitId ?? this.unitId),
      technicianId: clearTechnicianId
          ? null
          : (technicianId ?? this.technicianId),
      repeatOnly: repeatOnly ?? this.repeatOnly,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      createdDateRange: clearCreatedDateRange
          ? null
          : (createdDateRange ?? this.createdDateRange),
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComplaintFilter &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          _setEquals(statuses, other.statuses) &&
          _setEquals(priorities, other.priorities) &&
          _setEquals(categories, other.categories) &&
          propertyId == other.propertyId &&
          unitId == other.unitId &&
          technicianId == other.technicianId &&
          repeatOnly == other.repeatOnly &&
          overdueOnly == other.overdueOnly &&
          createdDateRange == other.createdDateRange &&
          sort == other.sort;

  @override
  int get hashCode => Object.hash(
    text,
    Object.hashAll(statuses),
    Object.hashAll(priorities),
    Object.hashAll(categories),
    propertyId,
    unitId,
    technicianId,
    repeatOnly,
    overdueOnly,
    createdDateRange,
    sort,
  );

  static bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

/// Returns a human-readable list of chips representing active filter values.
List<FilterChipData> describe(ComplaintFilter filter) {
  final chips = <FilterChipData>[];

  final query = filter.text?.trim();
  if (query != null && query.isNotEmpty) {
    chips.add(
      FilterChipData(
        id: 'text',
        label: 'Search: "$query"',
        onRemove: (f) => f.copyWith(clearText: true),
      ),
    );
  }

  for (final status in filter.statuses) {
    chips.add(
      FilterChipData(
        id: 'status_${status.name}',
        label: status.displayLabel,
        onRemove: (f) => f.copyWith(statuses: f.statuses.difference({status})),
      ),
    );
  }

  for (final priority in filter.priorities) {
    chips.add(
      FilterChipData(
        id: 'priority_${priority.name}',
        label: priority.displayLabel,
        onRemove: (f) =>
            f.copyWith(priorities: f.priorities.difference({priority})),
      ),
    );
  }

  for (final category in filter.categories) {
    chips.add(
      FilterChipData(
        id: 'category_${category.name}',
        label: category.displayLabel,
        onRemove: (f) =>
            f.copyWith(categories: f.categories.difference({category})),
      ),
    );
  }

  final propId = filter.propertyId?.trim();
  if (propId != null && propId.isNotEmpty) {
    var name = propId;
    for (final p in SampleFixtures.sampleProperties) {
      if (p.id == propId) {
        name = p.name;
        break;
      }
    }
    chips.add(
      FilterChipData(
        id: 'property',
        label: 'Property: $name',
        onRemove: (f) => f.copyWith(clearPropertyId: true),
      ),
    );
  }

  final uId = filter.unitId?.trim();
  if (uId != null && uId.isNotEmpty) {
    var unitNum = uId;
    for (final u in SampleFixtures.sampleUnits) {
      if (u.id == uId) {
        unitNum = u.unitNumber;
        break;
      }
    }
    chips.add(
      FilterChipData(
        id: 'unit',
        label: 'Unit: $unitNum',
        onRemove: (f) => f.copyWith(clearUnitId: true),
      ),
    );
  }

  final techId = filter.technicianId?.trim();
  if (techId != null && techId.isNotEmpty) {
    final isUnassigned = techId.toLowerCase() == 'unassigned';
    var techName = 'Unassigned';
    if (!isUnassigned) {
      techName = techId;
      for (final u in SampleFixtures.sampleUsers) {
        if (u.id == techId) {
          techName = u.name;
          break;
        }
      }
    }
    chips.add(
      FilterChipData(
        id: 'technician',
        label: isUnassigned ? 'Unassigned' : 'Tech: $techName',
        onRemove: (f) => f.copyWith(clearTechnicianId: true),
      ),
    );
  }

  if (filter.repeatOnly) {
    chips.add(
      FilterChipData(
        id: 'repeat',
        label: 'Repeat only',
        onRemove: (f) => f.copyWith(repeatOnly: false),
      ),
    );
  }

  if (filter.overdueOnly) {
    chips.add(
      FilterChipData(
        id: 'overdue',
        label: 'Overdue only',
        onRemove: (f) => f.copyWith(overdueOnly: false),
      ),
    );
  }

  if (filter.createdDateRange != null) {
    final start = filter.createdDateRange!.start;
    final end = filter.createdDateRange!.end;
    chips.add(
      FilterChipData(
        id: 'date_range',
        label: '${start.day}/${start.month} - ${end.day}/${end.month}',
        onRemove: (f) => f.copyWith(clearCreatedDateRange: true),
      ),
    );
  }

  return chips;
}

/// Standard SLA duration based on complaint priority.
Duration slaDurationForPriority(ComplaintPriority priority) =>
    switch (priority) {
      ComplaintPriority.urgent => const Duration(hours: 24),
      ComplaintPriority.high => const Duration(hours: 48),
      ComplaintPriority.medium => const Duration(hours: 72),
      ComplaintPriority.low => const Duration(hours: 120),
    };

/// Determines whether a complaint has breached its SLA deadline.
bool isComplaintOverdue(Complaint complaint, {DateTime? now}) {
  // Terminal states cannot be overdue
  if (complaint.status == ComplaintStatus.resolved ||
      complaint.status == ComplaintStatus.closed ||
      complaint.status == ComplaintStatus.cancelled) {
    return false;
  }
  final current = now ?? DateTime.now();
  final created = complaint.createdAt ?? current;
  final deadline = created.add(slaDurationForPriority(complaint.priority));
  return current.isAfter(deadline);
}

String _lookupTenantName(String tenantId) {
  for (final t in SampleFixtures.sampleTenants) {
    if (t.id == tenantId) return t.name;
  }
  return '';
}

String _lookupTechnicianName(String? technicianId) {
  if (technicianId == null) return '';
  for (final u in SampleFixtures.sampleUsers) {
    if (u.id == technicianId) return u.name;
  }
  return '';
}

String _lookupUnitNumber(String unitId) {
  for (final u in SampleFixtures.sampleUnits) {
    if (u.id == unitId) return u.unitNumber;
  }
  return '';
}

/// Pure filtering function applying search query and facet combinations.
///
/// Text query matches id, title, description, unit, tenant name, and technician
/// name case-insensitively with all words required (AND logic between words).
/// Filters combine with AND between different filter dimensions, and OR within
/// multi-select groups.
List<Complaint> applyFilter(
  List<Complaint> complaints,
  ComplaintFilter filter, {
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  final query = filter.text?.trim().toLowerCase();
  final words = query != null && query.isNotEmpty
      ? query.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList()
      : const <String>[];

  final filtered = complaints.where((c) {
    // 1. Text search: matches id, title, description, unit, tenant name, technician name
    if (words.isNotEmpty) {
      final unitNum = _lookupUnitNumber(c.unitId);
      final tenantName = _lookupTenantName(c.tenantId);
      final techName = _lookupTechnicianName(c.currentTechnicianId);
      final searchable =
          '${c.id} ${c.title} ${c.description} ${c.unitId} $unitNum ${c.tenantId} $tenantName ${c.currentTechnicianId ?? ''} $techName'
              .toLowerCase();

      final matchesAllWords = words.every((word) => searchable.contains(word));
      if (!matchesAllWords) return false;
    }

    // 2. Statuses (OR within group)
    if (filter.statuses.isNotEmpty && !filter.statuses.contains(c.status)) {
      return false;
    }

    // 3. Priorities (OR within group)
    if (filter.priorities.isNotEmpty &&
        !filter.priorities.contains(c.priority)) {
      return false;
    }

    // 4. Categories (OR within group)
    if (filter.categories.isNotEmpty &&
        !filter.categories.contains(c.category)) {
      return false;
    }

    // 5. Property
    if (filter.propertyId != null &&
        filter.propertyId!.trim().isNotEmpty &&
        c.propertyId != filter.propertyId!.trim()) {
      return false;
    }

    // 6. Unit
    if (filter.unitId != null &&
        filter.unitId!.trim().isNotEmpty &&
        c.unitId != filter.unitId!.trim()) {
      return false;
    }

    // 7. Technician (including "Unassigned")
    if (filter.technicianId != null && filter.technicianId!.trim().isNotEmpty) {
      final tech = filter.technicianId!.trim();
      final isUnassigned = tech.toLowerCase() == 'unassigned';
      if (isUnassigned) {
        if (c.currentTechnicianId != null &&
            c.currentTechnicianId!.trim().isNotEmpty &&
            c.currentTechnicianId!.toLowerCase() != 'unassigned') {
          return false;
        }
      } else {
        if (c.currentTechnicianId != tech) {
          return false;
        }
      }
    }

    // 8. Repeat only
    if (filter.repeatOnly && (!c.isRepeatVisit && c.visitCount < 2)) {
      return false;
    }

    // 9. Overdue only (SLA breached)
    if (filter.overdueOnly && !isComplaintOverdue(c, now: effectiveNow)) {
      return false;
    }

    // 10. Created date range
    if (filter.createdDateRange != null) {
      final created = c.createdAt;
      if (created == null) return false;
      final start = filter.createdDateRange!.start;
      final end = filter.createdDateRange!.end;
      // Allow inclusive of start and end day
      if (created.isBefore(start) ||
          created.isAfter(end.add(const Duration(days: 1)))) {
        return false;
      }
    }

    return true;
  }).toList();

  // Apply sorting
  switch (filter.sort) {
    case ComplaintSort.newest:
      filtered.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    case ComplaintSort.oldest:
      filtered.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
    case ComplaintSort.priority:
      filtered.sort((a, b) {
        // urgent (highest index or priority rank) to low
        final aRank = _priorityRank(a.priority);
        final bRank = _priorityRank(b.priority);
        final comp = bRank.compareTo(aRank); // higher rank first
        if (comp != 0) return comp;
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    case ComplaintSort.lastUpdated:
      filtered.sort((a, b) {
        final aDate =
            a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    case ComplaintSort.longestOpen:
      filtered.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
  }

  return filtered;
}

int _priorityRank(ComplaintPriority priority) => switch (priority) {
  ComplaintPriority.urgent => 4,
  ComplaintPriority.high => 3,
  ComplaintPriority.medium => 2,
  ComplaintPriority.low => 1,
};

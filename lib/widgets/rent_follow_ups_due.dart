import 'package:flutter/material.dart';

import '../core/enums/rent_status.dart';
import '../screens/rent/rent_models.dart';
import '../utils/date_time_formatters.dart';
import '../utils/rent_rules.dart';
import 'app_spacing.dart';
import 'attention_list_tile.dart';
import 'empty_state.dart';
import 'status_badge.dart';

/// Small immutable presentation model for a scheduled or overdue rent follow-up.
///
/// Contains strictly the display and navigation fields required by the UI.
class RentFollowUpDueItem {
  const RentFollowUpDueItem({
    required this.id,
    required this.rentRecordId,
    required this.tenantName,
    this.propertyContext,
    this.propertyName,
    this.unitNumber,
    required this.dueDate,
    required this.isOverdue,
    this.daysOverdue = 0,
    this.statusLabel,
    this.contactMethod,
    this.notes,
  });

  /// Stable follow-up identifier (or rent record ID if no follow-up ID exists).
  final String id;

  /// Underlying rent record identifier for navigation.
  final String rentRecordId;

  /// Display name of the tenant.
  final String tenantName;

  /// Combined property and unit context, e.g. "Emerald Heights • Unit 201".
  final String? propertyContext;

  /// Property name when available.
  final String? propertyName;

  /// Unit number when available.
  final String? unitNumber;

  /// Scheduled follow-up date.
  final DateTime dueDate;

  /// Whether the scheduled follow-up is past due relative to the reference date.
  final bool isOverdue;

  /// Number of calendar days the follow-up is overdue (0 if due today or upcoming).
  final int daysOverdue;

  /// Prepared display label for due status, e.g. "3d overdue" or "Due today".
  final String? statusLabel;

  /// Method used in last follow-up contact attempt if available.
  final String? contactMethod;

  /// Optional contextual note.
  final String? notes;
}

/// Prepares and filters a list of [RentItem] models into [RentFollowUpDueItem] view models.
///
/// Eligibility Rules:
/// 1. Paid or fully settled records (`isPaid`, `balance <= 0`, or `effectiveStatus == RentStatus.paid`)
///    are excluded from actionable follow-ups.
/// 2. Records without an explicit scheduled follow-up date (`nextFollowUpAt` or
///    `lastFollowUp.nextFollowUpDate`) are excluded; no dates are invented or assumed.
/// 3. If [dueAndOverdueOnly] is true, items whose scheduled date is in the future
///    (after [now]) are excluded.
/// 4. An item is marked overdue if its calendar day is strictly before [now]'s calendar day.
///    On the due date itself, the item is considered due today (not overdue).
/// 5. Overdue items are prioritized and sorted first (greatest days overdue first),
///    followed by items due today, then upcoming items.
List<RentFollowUpDueItem> prepareRentFollowUpsDue(
  List<RentItem> items, {
  DateTime? now,
  bool dueAndOverdueOnly = true,
}) {
  final ref = now ?? DateTime.now();
  final refDay = DateTime(ref.year, ref.month, ref.day);

  final results = <RentFollowUpDueItem>[];

  for (final item in items) {
    // Exclude paid and settled records
    if (item.isPaid || balance(item.record, item.payments) <= 0) {
      continue;
    }
    if (effectiveStatus(item.record, ref, item.payments) == RentStatus.paid) {
      continue;
    }

    // Scheduled follow-up date from record or most recent follow-up
    final scheduledDate =
        item.nextFollowUpAt ?? item.lastFollowUp?.nextFollowUpDate;
    if (scheduledDate == null) {
      continue;
    }

    final targetDay = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );

    final isOverdue = targetDay.isBefore(refDay);
    final isDueToday = targetDay.isAtSameMomentAs(refDay);

    if (dueAndOverdueOnly && !isOverdue && !isDueToday) {
      continue;
    }

    final days = isOverdue ? refDay.difference(targetDay).inDays : 0;

    // Compose property and unit context cleanly without fabricating data
    String? propertyContext;
    final propName = item.propertyName.trim();
    final unitNum = item.unitNumber.trim();
    if (propName.isNotEmpty && unitNum.isNotEmpty) {
      propertyContext = '$propName • $unitNum';
    } else if (propName.isNotEmpty) {
      propertyContext = propName;
    } else if (unitNum.isNotEmpty) {
      propertyContext = unitNum;
    }

    final statusLabel = isOverdue
        ? (days > 0 ? '${days}d overdue' : 'Overdue')
        : (isDueToday ? 'Due today' : formatDate(scheduledDate));

    final tenantDisplay = item.tenantName.trim().isNotEmpty
        ? item.tenantName.trim()
        : 'Tenant';

    results.add(
      RentFollowUpDueItem(
        id: item.lastFollowUp?.id ?? item.id,
        rentRecordId: item.id,
        tenantName: tenantDisplay,
        propertyContext: propertyContext,
        propertyName: propName.isNotEmpty ? propName : null,
        unitNumber: unitNum.isNotEmpty ? unitNum : null,
        dueDate: scheduledDate,
        isOverdue: isOverdue,
        daysOverdue: days,
        statusLabel: statusLabel,
        contactMethod: item.lastFollowUp?.method.label,
        notes: item.lastFollowUp?.note,
      ),
    );
  }

  // Sort: overdue first (highest daysOverdue descending), then due today / upcoming ascending
  results.sort((a, b) {
    if (a.isOverdue && !b.isOverdue) return -1;
    if (!a.isOverdue && b.isOverdue) return 1;
    if (a.isOverdue && b.isOverdue) {
      final daysDiff = b.daysOverdue.compareTo(a.daysOverdue);
      if (daysDiff != 0) return daysDiff;
      return a.dueDate.compareTo(b.dueDate);
    }
    return a.dueDate.compareTo(b.dueDate);
  });

  return results;
}

/// Reusable widget rendering a prepared list of due and overdue rent follow-ups.
///
/// This component is strictly presentational and does not perform any data fetching,
/// repository queries, or Firestore operations.
class RentFollowUpsDue extends StatelessWidget {
  const RentFollowUpsDue({
    super.key,
    required this.items,
    this.onItemTap,
    this.header,
    this.emptyTitle = 'No follow-ups due',
    this.emptyMessage = 'All tenant rent follow-ups are currently up to date.',
  });

  /// Prepared view-model items to render.
  final List<RentFollowUpDueItem> items;

  /// Callback fired with [RentFollowUpDueItem] when a follow-up tile is tapped.
  final ValueChanged<RentFollowUpDueItem>? onItemTap;

  /// Optional header widget (such as a [SectionHeader]) placed above the list.
  final Widget? header;

  /// Title for empty state when [items] is empty.
  final String emptyTitle;

  /// Message for empty state when [items] is empty.
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      final emptyContent = EmptyState.compact(
        icon: Icons.event_available_outlined,
        title: emptyTitle,
        message: emptyMessage,
      );

      if (header != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header!,
            const SizedBox(height: AppSpacing.md),
            emptyContent,
          ],
        );
      }
      return emptyContent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[header!, const SizedBox(height: AppSpacing.md)],
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _buildTile(context, items[i]),
        ],
      ],
    );
  }

  Widget _buildTile(BuildContext context, RentFollowUpDueItem item) {
    return AttentionListTile(
      key: ValueKey('rent_follow_up_tile_${item.id}'),
      title: item.tenantName,
      subtitle: item.propertyContext,
      leadingIcon: item.isOverdue
          ? Icons.warning_amber_rounded
          : Icons.phone_forwarded,
      isUrgent: item.isOverdue,
      statusLabel:
          item.statusLabel ?? (item.isOverdue ? 'Overdue' : 'Due today'),
      statusTone: item.isOverdue
          ? StatusBadgeTone.danger
          : StatusBadgeTone.warning,
      trailingIcon: Icons.chevron_right,
      onTap: onItemTap != null ? () => onItemTap!(item) : null,
    );
  }
}

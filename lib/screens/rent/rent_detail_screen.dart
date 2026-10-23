import 'package:flutter/material.dart';

import '../../core/enums/rent_status.dart';
import '../../repositories/rent_repository.dart';
import '../../theme/app_palette.dart';
import '../../utils/rent_rules.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'add_follow_up_sheet.dart';
import 'mark_paid_sheet.dart';
import 'rent_models.dart';
import 'widgets/rent_follow_up_history_item.dart';
import '../tenant/tenant_detail_context_screen.dart';

/// Screen and panel for viewing complete Rent details, payments,
/// tenant contact shortcuts, and follow-up history timeline.
class RentDetailScreen extends StatefulWidget {
  const RentDetailScreen({
    super.key,
    required this.item,
    required this.repository,
    this.readOnly = false,
    this.isEmbedded = false,
    this.onItemUpdated,
    this.now,
  });

  final RentItem item;
  final RentRepository repository;
  final bool readOnly;
  final bool isEmbedded;
  final ValueChanged<RentItem>? onItemUpdated;
  final DateTime? now;

  @override
  State<RentDetailScreen> createState() => _RentDetailScreenState();
}

class _RentDetailScreenState extends State<RentDetailScreen> {
  late RentItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  @override
  void didUpdateWidget(covariant RentDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.followUps.length != widget.item.followUps.length ||
        oldWidget.item.payments.length != widget.item.payments.length ||
        oldWidget.item.status != widget.item.status) {
      _item = widget.item;
    }
  }

  DateTime get _referenceNow => widget.now ?? DateTime.now();

  Future<void> _openAddFollowUp() async {
    final updated = await AddFollowUpSheet.show(
      context,
      item: _item,
      repository: widget.repository,
      now: _referenceNow,
    );
    if (updated != null && mounted) {
      setState(() => _item = updated);
      widget.onItemUpdated?.call(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow-up recorded successfully')),
      );
    }
  }

  Future<void> _openMarkPaid() async {
    final updated = await MarkPaidSheet.show(
      context,
      item: _item,
      repository: widget.repository,
      now: _referenceNow,
    );
    if (updated != null && mounted) {
      setState(() => _item = updated);
      widget.onItemUpdated?.call(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully')),
      );
    }
  }

  StatusBadgeTone _statusTone(RentStatus status) {
    return switch (status) {
      RentStatus.paid => StatusBadgeTone.success,
      RentStatus.overdue => StatusBadgeTone.danger,
      RentStatus.promised => StatusBadgeTone.warning,
      RentStatus.contacted => StatusBadgeTone.accent,
      RentStatus.due => StatusBadgeTone.neutral,
    };
  }

  String _formatElapsedSince(DateTime current, DateTime previous) {
    final difference = current.difference(previous);
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    if (days > 0) {
      return '$days day${days == 1 ? '' : 's'}${hours > 0 ? ' $hours hr' : ''} after previous';
    }
    final mins = difference.inMinutes;
    if (hours > 0) {
      return '$hours hr${hours == 1 ? '' : 's'} after previous';
    }
    if (mins > 0) {
      return '$mins min${mins == 1 ? '' : 's'} after previous';
    }
    return 'Shortly after previous';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final currentStatus = effectiveStatus(
      _item.record,
      _referenceNow,
      _item.payments,
    );
    final overdueDays = daysOverdue(_item.dueDate, _referenceNow);

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _item.tenantName,
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Unit ${_item.unitNumber} • ${_item.propertyName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: currentStatus.displayLabel,
                      tone: _statusTone(currentStatus),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(color: palette.border, height: 1),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Month',
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _item.month,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total rent',
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatIndianCurrency(_item.amountDue),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: palette.ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. Payment & Balance Card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Payment & Settlement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Due date',
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_item.dueDate.day}/${_item.dueDate.month}/${_item.dueDate.year}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: overdueDays > 0 && !_item.isPaid
                                ? palette.danger
                                : palette.ink,
                          ),
                        ),
                        if (overdueDays > 0 && !_item.isPaid)
                          Text(
                            '$overdueDays days overdue',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Amount paid',
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatIndianCurrency(_item.amountPaid),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: palette.success,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Remaining balance',
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatIndianCurrency(_item.balance),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _item.balance > 0
                                ? palette.accent
                                : palette.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_item.payments.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Divider(color: palette.border, height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Settlement records',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final p in _item.payments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${p.mode.label} • ${p.date.day}/${p.date.month}/${p.date.year}',
                            style: TextStyle(fontSize: 13, color: palette.ink),
                          ),
                          Text(
                            formatIndianCurrency(p.amount),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 3. Tenant Contact Shortcuts Card
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: palette.accentSoft,
                  child: Icon(Icons.person, color: palette.accent),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: InkWell(
                    key: const Key('rent_tenant_info_tap'),
                    onTap: () {
                      TenantDetailContextScreen.open(
                        context,
                        tenantId: _item.tenant.id,
                        initialTenant: _item.tenant,
                        rentRepository: widget.repository,
                        referenceNow: _referenceNow,
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.tenantName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                        Text(
                          _item.tenantPhone,
                          style: TextStyle(fontSize: 13, color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('rent_view_tenant_context_button'),
                  tooltip: 'View tenant context',
                  icon: Icon(Icons.badge_outlined, color: palette.accent),
                  onPressed: () {
                    TenantDetailContextScreen.open(
                      context,
                      tenantId: _item.tenant.id,
                      initialTenant: _item.tenant,
                      rentRepository: widget.repository,
                      referenceNow: _referenceNow,
                    );
                  },
                ),
                IconButton(
                  key: const Key('rent_contact_call_button'),
                  tooltip: 'Call tenant',
                  icon: Icon(Icons.phone_outlined, color: palette.accent),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Calling ${_item.tenantPhone}...'),
                      ),
                    );
                  },
                ),
                IconButton(
                  key: const Key('rent_contact_message_button'),
                  tooltip: 'Message tenant',
                  icon: Icon(Icons.chat_bubble_outline, color: palette.accent),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Messaging ${_item.tenantPhone}...'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 4. Staff Actions Bar (Omitted if readOnly)
          if (!widget.readOnly) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('rent_detail_add_follow_up_button'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: BorderSide(color: palette.accent),
                      foregroundColor: palette.accent,
                    ),
                    icon: const Icon(Icons.add_call, size: 18),
                    label: const Text('Add follow-up'),
                    onPressed: _openAddFollowUp,
                  ),
                ),
                if (!_item.isPaid) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('rent_detail_mark_paid_button'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: palette.accent,
                        foregroundColor: palette.surface,
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark as paid'),
                      onPressed: _openMarkPaid,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // 5. Follow-up Timeline
          Row(
            children: [
              Icon(Icons.history, size: 20, color: palette.accent),
              const SizedBox(width: 8),
              Text(
                'Follow-up history (${_item.followUps.length})',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: palette.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (_item.followUps.isEmpty)
            const EmptyState.compact(
              icon: Icons.history_toggle_off,
              title: 'No follow-ups recorded',
              message: 'Follow-ups and communication logs with this tenant will appear here.',
            )
          else ...[
            Builder(
              builder: (context) {
                final sorted = List<RentFollowUp>.from(_item.followUps)
                  ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final followUp = sorted[index];
                    final previous = (index < sorted.length - 1)
                        ? sorted[index + 1]
                        : null;
                    final elapsed = previous != null
                        ? _formatElapsedSince(
                            followUp.timestamp,
                            previous.timestamp,
                          )
                        : 'Initial follow-up';

                    return RentFollowUpHistoryItem(
                      key: Key('rent_follow_up_history_item_${followUp.id}'),
                      followUp: followUp,
                      elapsed: elapsed,
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: Text(
          'Rent • ${_item.unitNumber}',
          style: const TextStyle(fontFamily: 'Fraunces'),
        ),
      ),
      body: content,
    );
  }
}

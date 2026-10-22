import 'package:flutter/material.dart';

import '../../core/enums/rent_status.dart';
import '../../repositories/rent_repository.dart';
import '../../theme/app_palette.dart';
import '../../utils/rent_rules.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/status_badge.dart';
import 'rent_detail_screen.dart';
import 'rent_models.dart';

/// The Rent tab screen displaying summary collection metrics, filterable list,
/// and responsive master-detail view on wide screens.
class RentListScreen extends StatefulWidget {
  const RentListScreen({
    super.key,
    this.initialStatusFilter,
    this.repository,
    this.readOnly = false,
    this.filterTenantId,
    this.showAppBar = true,
    this.now,
  });

  final RentStatus? initialStatusFilter;
  final RentRepository? repository;
  final bool readOnly;
  final String? filterTenantId;
  final bool showAppBar;
  final DateTime? now;

  @override
  State<RentListScreen> createState() => _RentListScreenState();
}

class _RentListScreenState extends State<RentListScreen> {
  late final RentRepository _repo =
      widget.repository ?? InMemoryRentRepository();

  bool _isLoading = true;
  String? _errorMessage;
  List<RentItem> _items = [];

  // Filter & Search states
  String _searchQuery = '';
  RentStatus? _selectedStatusFilter; // null means "All"
  String? _selectedMonth; // null means "All months"

  String? _selectedItemId;

  @override
  void initState() {
    super.initState();
    _selectedStatusFilter = widget.initialStatusFilter;
    _loadData();
  }

  DateTime get _referenceNow => widget.now ?? DateTime.now();

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _repo.list(tenantId: widget.filterTenantId);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
          if (_items.isNotEmpty && _selectedItemId == null) {
            _selectedItemId = _sortedItems(items).first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  List<RentItem> _sortedItems(List<RentItem> input) {
    final list = List<RentItem>.from(input);
    list.sort((a, b) {
      final aStatus = effectiveStatus(a.record, _referenceNow, a.payments);
      final bStatus = effectiveStatus(b.record, _referenceNow, b.payments);
      final aIsOverdue = aStatus == RentStatus.overdue;
      final bIsOverdue = bStatus == RentStatus.overdue;

      // Overdue rows are sorted first
      if (aIsOverdue && !bIsOverdue) return -1;
      if (!aIsOverdue && bIsOverdue) return 1;

      if (aIsOverdue && bIsOverdue) {
        final aDays = daysOverdue(a.dueDate, _referenceNow);
        final bDays = daysOverdue(b.dueDate, _referenceNow);
        return bDays.compareTo(aDays);
      }

      return a.dueDate.compareTo(b.dueDate);
    });
    return list;
  }

  List<RentItem> get _filteredItems {
    var list = _items;

    // Month filter
    if (_selectedMonth != null && _selectedMonth != 'All') {
      list = list.where((i) => i.month == _selectedMonth).toList();
    }

    // Status filter
    if (_selectedStatusFilter != null) {
      list = list.where((i) {
        final eff = effectiveStatus(i.record, _referenceNow, i.payments);
        return eff == _selectedStatusFilter;
      }).toList();
    }

    // Search query filter (unit or tenant)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((i) {
        return i.tenantName.toLowerCase().contains(q) ||
            i.unitNumber.toLowerCase().contains(q) ||
            i.propertyName.toLowerCase().contains(q);
      }).toList();
    }

    return _sortedItems(list);
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedStatusFilter = null;
      _selectedMonth = null;
    });
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

  String _formatLastFollowUp(RentFollowUp? followUp) {
    if (followUp == null) return 'No follow-up yet';
    final diff = _referenceNow.difference(followUp.timestamp);
    final days = diff.inDays;
    final action = switch (followUp.method) {
      FollowUpMethod.call => 'Called',
      FollowUpMethod.message => 'Messaged',
      FollowUpMethod.visit => 'Visited',
      FollowUpMethod.email => 'Emailed',
    };
    if (days <= 0) {
      final hours = diff.inHours;
      if (hours <= 0) return '$action just now';
      return '$action $hours hr${hours == 1 ? '' : 's'} ago';
    }
    if (days == 1) return '$action yesterday';
    return '$action $days days ago';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    final scaffold = Scaffold(
      backgroundColor: palette.canvas,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Rent Collection',
                style: TextStyle(fontFamily: 'Fraunces'),
              ),
            )
          : null,
      body: SafeArea(child: _buildBody(context, isWide)),
    );

    return scaffold;
  }

  Widget _buildBody(BuildContext context, bool isWide) {
    final palette = context.palette;

    if (_isLoading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            SkeletonCard(),
            SizedBox(height: AppSpacing.md),
            SkeletonList(itemCount: 2),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: 'Could not load rent records: $_errorMessage',
        onRetry: _loadData,
      );
    }

    if (_items.isEmpty) {
      return const EmptyState.noData(
        title: 'No rent records',
        message: 'There are no rent records configured for this workspace.',
      );
    }

    final filtered = _filteredItems;

    // Distinct months for selector
    final months = _items.map((i) => i.month).toSet().toList()..sort();

    // Summary calculations
    final monthItems = _selectedMonth != null && _selectedMonth != 'All'
        ? _items.where((i) => i.month == _selectedMonth).toList()
        : _items;

    final totalDue = monthItems.fold<double>(0.0, (s, i) => s + i.amountDue);
    final collected = monthItems.fold<double>(0.0, (s, i) => s + i.amountPaid);
    final overdueItems = monthItems.where((i) {
      return effectiveStatus(i.record, _referenceNow, i.payments) ==
          RentStatus.overdue;
    }).toList();
    final overdueAmount = overdueItems.fold<double>(
      0.0,
      (s, i) => s + i.balance,
    );
    final overdueCount = overdueItems.length;

    final collectionRate = totalDue > 0
        ? (collected / totalDue).clamp(0.0, 1.0)
        : 0.0;

    final listView = RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // Summary Strip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: _buildSummaryStrip(
                context,
                totalDue: totalDue,
                overdueAmount: overdueAmount,
                overdueCount: overdueCount,
                collected: collected,
                collectionRate: collectionRate,
              ),
            ),
          ),

          // Search & Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Bar & Month selector
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('rent_search_field'),
                          decoration: InputDecoration(
                            hintText: 'Search unit or tenant...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () =>
                                        setState(() => _searchQuery = ''),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                        ),
                      ),
                      if (months.length > 1) ...[
                        const SizedBox(width: AppSpacing.sm),
                        DropdownButton<String>(
                          key: const Key('rent_month_selector'),
                          value: _selectedMonth ?? 'All',
                          items: [
                            const DropdownMenuItem(
                              value: 'All',
                              child: Text('All Months'),
                            ),
                            for (final m in months)
                              DropdownMenuItem(value: m, child: Text(m)),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedMonth = val == 'All' ? null : val;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          key: const Key('rent_filter_chip_all'),
                          label: const Text('All'),
                          selected: _selectedStatusFilter == null,
                          onSelected: (_) =>
                              setState(() => _selectedStatusFilter = null),
                        ),
                        const SizedBox(width: 8),
                        for (final status in RentStatus.values) ...[
                          FilterChip(
                            key: Key('rent_filter_chip_${status.name}'),
                            label: Text(status.displayLabel),
                            selected: _selectedStatusFilter == status,
                            onSelected: (selected) {
                              setState(() {
                                _selectedStatusFilter = selected
                                    ? status
                                    : null;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List Items or No Results
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyState.noResults(
                  title: 'No matching rent records',
                  message: 'No records match the current search or filters.',
                  actionLabel: 'Clear filters',
                  onAction: _clearFilters,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = filtered[index];
                  final currentStatus = effectiveStatus(
                    item.record,
                    _referenceNow,
                    item.payments,
                  );
                  final overdueDays = daysOverdue(item.dueDate, _referenceNow);
                  final isSelected = isWide && item.id == _selectedItemId;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      key: Key('rent_row_${item.id}'),
                      selected: isSelected,
                      onTap: () {
                        if (isWide) {
                          setState(() => _selectedItemId = item.id);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RentDetailScreen(
                                item: item,
                                repository: _repo,
                                readOnly: widget.readOnly,
                                now: _referenceNow,
                                onItemUpdated: (updated) => _loadData(),
                              ),
                            ),
                          );
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.tenantName} • Unit ${item.unitNumber}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: palette.ink,
                                  ),
                                ),
                              ),
                              StatusBadge(
                                label: currentStatus.displayLabel,
                                tone: _statusTone(currentStatus),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Due: ${item.dueDate.day}/${item.dueDate.month}/${item.dueDate.year}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.muted,
                                ),
                              ),
                              Text(
                                formatIndianCurrency(item.amountDue),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: palette.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatLastFollowUp(item.lastFollowUp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.muted,
                                ),
                              ),
                              if (overdueDays > 0 && !item.isPaid)
                                Text(
                                  '$overdueDays days overdue',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: palette.danger,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: filtered.length),
              ),
            ),
        ],
      ),
    );

    if (!isWide) {
      return listView;
    }

    // Wide screens: Master-detail split layout
    final selectedItem = _items.firstWhere(
      (i) => i.id == _selectedItemId,
      orElse: () => filtered.isNotEmpty ? filtered.first : _items.first,
    );

    return Row(
      children: [
        SizedBox(
          width: 420,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: palette.border)),
            ),
            child: listView,
          ),
        ),
        Expanded(
          child: RentDetailScreen(
            key: ValueKey('detail_${selectedItem.id}'),
            item: selectedItem,
            repository: _repo,
            readOnly: widget.readOnly,
            isEmbedded: true,
            now: _referenceNow,
            onItemUpdated: (updated) => _loadData(),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStrip(
    BuildContext context, {
    required double totalDue,
    required double overdueAmount,
    required int overdueCount,
    required double collected,
    required double collectionRate,
  }) {
    final palette = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collection overview',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: palette.ink,
                ),
              ),
              Text(
                '${(collectionRate * 100).toStringAsFixed(0)}% collected',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: palette.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: collectionRate,
              minHeight: 8,
              backgroundColor: palette.shimmer,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total due',
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatIndianCurrency(totalDue),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collected',
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatIndianCurrency(collected),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: palette.success,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overdue ($overdueCount)',
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatIndianCurrency(overdueAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: overdueCount > 0 ? palette.danger : palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

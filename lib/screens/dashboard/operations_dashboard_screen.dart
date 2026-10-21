import 'package:flutter/material.dart';

import '../../core/enums/complaint_status.dart';
import '../../core/enums/rent_status.dart';
import '../../core/models/complaint.dart';
import '../../core/models/user.dart';
import '../../repositories/complaint_repository.dart';
import '../../repositories/property_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../theme/app_palette.dart';
import '../../utils/rent_rules.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/error_state.dart';
import '../../widgets/rent_follow_ups_due.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';
import '../complaints/complaint_list_screen.dart';
import '../rent/rent_detail_screen.dart';
import '../rent/rent_list_screen.dart';
import '../rent/rent_models.dart';

/// The Operations Dashboard screen for staff roles (Property Operations & Complaint Operations).
///
/// Composes reusable KPI cards ([StatTile]), the follow-ups due widget ([RentFollowUpsDue]),
/// section headings, and operational navigation.
class OperationsDashboardScreen extends StatefulWidget {
  const OperationsDashboardScreen({
    super.key,
    this.profile,
    this.complaintRepository,
    this.propertyRepository,
    this.rentRepository,
    this.now,
  });

  final AppUser? profile;
  final ComplaintRepository? complaintRepository;
  final PropertyRepository? propertyRepository;
  final RentRepository? rentRepository;
  final DateTime? now;

  @override
  State<OperationsDashboardScreen> createState() =>
      _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState extends State<OperationsDashboardScreen> {
  late final RentRepository _rentRepo =
      widget.rentRepository ?? InMemoryRentRepository();

  bool _isLoading = true;
  String? _errorMessage;
  List<RentItem> _rentItems = [];
  List<Complaint> _complaints = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime get _referenceNow => widget.now ?? DateTime.now();

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rentItems = await _rentRepo.list();
      List<Complaint> complaints = [];

      final complaintRepo = widget.complaintRepository;
      if (complaintRepo != null) {
        try {
          complaints = await complaintRepo.watchComplaints().first.timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () => [],
          );
        } catch (_) {
          // If watchComplaints stream isn't active or times out, proceed with empty complaints
          complaints = [];
        }
      }

      if (mounted) {
        setState(() {
          _rentItems = rentItems;
          _complaints = complaints;
          _isLoading = false;
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

  void _onFollowUpTap(RentFollowUpDueItem dueItem) {
    final rentItem = _rentItems.cast<RentItem?>().firstWhere(
      (i) => i?.id == dueItem.rentRecordId,
      orElse: () => null,
    );
    if (rentItem != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RentDetailScreen(
            item: rentItem,
            repository: _rentRepo,
            now: _referenceNow,
            onItemUpdated: (_) => _loadData(),
          ),
        ),
      );
    }
  }

  void _openRentList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RentListScreen(repository: _rentRepo, now: _referenceNow),
      ),
    );
  }

  void _openComplaintList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComplaintListScreen(
          profile: widget.profile,
          complaintRepository: widget.complaintRepository,
          propertyRepository: widget.propertyRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: palette.accent));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ErrorState(message: _errorMessage!, onRetry: _loadData),
        ),
      );
    }

    final dueFollowUps = prepareRentFollowUpsDue(
      _rentItems,
      now: _referenceNow,
    );
    final overdueFollowUpsCount = dueFollowUps.where((i) => i.isOverdue).length;

    // Overdue rent calculation
    final overdueRentItems = _rentItems.where((i) {
      return effectiveStatus(i.record, _referenceNow, i.payments) ==
          RentStatus.overdue;
    }).toList();
    final overdueRentTotal = overdueRentItems.fold<double>(
      0.0,
      (s, i) => s + i.balance,
    );

    // Complaint metrics
    final openComplaints = _complaints
        .where((c) => !c.status.isTerminal)
        .toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: palette.accent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final kpiColumns = width >= 900 ? 4 : (width >= 560 ? 2 : 1);

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(title: 'Overview'),
                    const SizedBox(height: AppSpacing.md),
                    _buildKpiGrid(
                      columns: kpiColumns,
                      totalFollowUpsDue: dueFollowUps.length,
                      overdueFollowUpsCount: overdueFollowUpsCount,
                      overdueRentTotal: overdueRentTotal,
                      overdueUnitsCount: overdueRentItems.length,
                      openComplaintsCount: openComplaints.length,
                      totalUnitsTracked: _rentItems.length,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    RentFollowUpsDue(
                      header: SectionHeader(
                        title: 'Follow-ups due',
                        trailing: TextButton.icon(
                          onPressed: _openRentList,
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('View rent'),
                        ),
                      ),
                      items: dueFollowUps,
                      onItemTap: _onFollowUpTap,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiGrid({
    required int columns,
    required int totalFollowUpsDue,
    required int overdueFollowUpsCount,
    required double overdueRentTotal,
    required int overdueUnitsCount,
    required int openComplaintsCount,
    required int totalUnitsTracked,
  }) {
    final kpis = <Widget>[
      StatTile(
        key: const Key('kpi_follow_ups_due'),
        label: 'Follow-ups due',
        value: '$totalFollowUpsDue',
        delta: overdueFollowUpsCount > 0
            ? '$overdueFollowUpsCount overdue'
            : null,
        icon: Icons.event_repeat_outlined,
        onTap: _openRentList,
      ),
      StatTile(
        key: const Key('kpi_overdue_rent'),
        label: 'Overdue rent',
        value: formatIndianCurrency(overdueRentTotal),
        delta: overdueUnitsCount > 0
            ? '$overdueUnitsCount units overdue'
            : null,
        icon: Icons.receipt_long_outlined,
        onTap: _openRentList,
      ),
      StatTile(
        key: const Key('kpi_open_complaints'),
        label: 'Open complaints',
        value: '$openComplaintsCount',
        icon: Icons.report_outlined,
        onTap: _openComplaintList,
      ),
      StatTile(
        key: const Key('kpi_tracked_units'),
        label: 'Tracked units',
        value: '$totalUnitsTracked',
        icon: Icons.apartment_outlined,
      ),
    ];

    if (columns == 1) {
      return Column(
        children: [
          for (var i = 0; i < kpis.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            kpis[i],
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - (columns - 1) * AppSpacing.md) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final kpi in kpis) SizedBox(width: itemWidth, child: kpi),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/user_role.dart' as app_role;
import '../../core/enums/complaint_status.dart';
import '../../core/enums/rent_status.dart';
import '../../core/enums/tenant_status.dart';
import '../../core/enums/user_role.dart';
import '../../core/models/complaint.dart';
import '../../core/models/tenant.dart';
import '../../repositories/complaint_repository.dart';
import '../../repositories/property_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../repositories/tenant_repository.dart';
import '../../theme/app_palette.dart';
import '../../utils/date_time_formatters.dart';
import '../../utils/rent_rules.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/complaint_chips.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton_box.dart';
import '../complaints/complaint_detail_screen.dart';
import '../rent/rent_detail_screen.dart';
import '../rent/rent_models.dart';
import '../rent/widgets/rent_follow_up_history_item.dart';

/// Staff-facing screen displaying tenant details, property/unit location,
/// active and historical complaints, and rent follow-up history.
class TenantDetailContextScreen extends StatelessWidget {
  const TenantDetailContextScreen({
    super.key,
    required this.tenantId,
    this.initialTenant,
    this.tenantRepository,
    this.complaintRepository,
    this.propertyRepository,
    this.rentRepository,
    this.userRole = UserRole.propertyOperations,
    this.referenceNow,
    this.showAppBar = true,
  });

  final String tenantId;
  final Tenant? initialTenant;
  final TenantRepository? tenantRepository;
  final ComplaintRepository? complaintRepository;
  final PropertyRepository? propertyRepository;
  final RentRepository? rentRepository;
  final UserRole userRole;
  final DateTime? referenceNow;
  final bool showAppBar;

  /// Canonical navigation helper to push the tenant detail context screen.
  static Future<void> open(
    BuildContext context, {
    required String tenantId,
    Tenant? initialTenant,
    TenantRepository? tenantRepository,
    ComplaintRepository? complaintRepository,
    PropertyRepository? propertyRepository,
    RentRepository? rentRepository,
    UserRole userRole = UserRole.propertyOperations,
    DateTime? referenceNow,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TenantDetailContextScreen(
          tenantId: tenantId,
          initialTenant: initialTenant,
          tenantRepository: tenantRepository,
          complaintRepository: complaintRepository,
          propertyRepository: propertyRepository,
          rentRepository: rentRepository,
          userRole: userRole,
          referenceNow: referenceNow,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: showAppBar
          ? AppBar(
              title: const Text('Tenant Context'),
              backgroundColor: palette.surface,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: TenantDetailContextPanel(
          tenantId: tenantId,
          initialTenant: initialTenant,
          tenantRepository: tenantRepository,
          complaintRepository: complaintRepository,
          propertyRepository: propertyRepository,
          rentRepository: rentRepository,
          userRole: userRole,
          referenceNow: referenceNow,
        ),
      ),
    );
  }
}

/// Reusable panel containing tenant contact summary, complaints, and rent follow-up history.
class TenantDetailContextPanel extends StatefulWidget {
  const TenantDetailContextPanel({
    super.key,
    required this.tenantId,
    this.initialTenant,
    this.tenantRepository,
    this.complaintRepository,
    this.propertyRepository,
    this.rentRepository,
    this.userRole = UserRole.propertyOperations,
    this.referenceNow,
    this.onClose,
  });

  final String tenantId;
  final Tenant? initialTenant;
  final TenantRepository? tenantRepository;
  final ComplaintRepository? complaintRepository;
  final PropertyRepository? propertyRepository;
  final RentRepository? rentRepository;
  final UserRole userRole;
  final DateTime? referenceNow;
  final VoidCallback? onClose;

  @override
  State<TenantDetailContextPanel> createState() =>
      _TenantDetailContextPanelState();
}

class _TenantDetailContextPanelState extends State<TenantDetailContextPanel> {
  late final TenantRepository _tenantRepo =
      widget.tenantRepository ?? InMemoryTenantRepository();
  late final ComplaintRepository _complaintRepo =
      widget.complaintRepository ?? InMemoryComplaintRepository();
  late final PropertyRepository _propertyRepo =
      widget.propertyRepository ??
      InMemoryPropertyRepository(loadingDelay: Duration.zero);
  late final RentRepository _rentRepo =
      widget.rentRepository ??
      InMemoryRentRepository(simulatedDelay: Duration.zero);

  DateTime get _now => widget.referenceNow ?? DateTime.now();

  // Tenant Summary State
  bool _isLoadingTenant = true;
  String? _tenantError;
  Tenant? _tenant;
  String? _resolvedPropertyName;
  String? _resolvedPropertyAddress;
  String? _resolvedUnitNumber;

  // Complaints State
  bool _isLoadingComplaints = true;
  String? _complaintsError;
  List<Complaint> _complaints = const [];

  // Rent Items State
  bool _isLoadingRent = true;
  String? _rentError;
  List<RentItem> _rentItems = const [];

  @override
  void initState() {
    super.initState();
    if (widget.userRole.isOperationsStaff) {
      _loadTenant();
      _loadComplaints();
      _loadRent();
    }
  }

  @override
  void didUpdateWidget(covariant TenantDetailContextPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userRole.isOperationsStaff &&
        (oldWidget.tenantId != widget.tenantId ||
            !oldWidget.userRole.isOperationsStaff)) {
      _loadTenant();
      _loadComplaints();
      _loadRent();
    }
  }

  Future<void> _loadTenant() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTenant = true;
      _tenantError = null;
    });

    try {
      Tenant? tenant = widget.initialTenant;
      if (tenant == null || tenant.id != widget.tenantId) {
        tenant = await _tenantRepo.getById(widget.tenantId);
      }

      if (tenant == null) {
        if (!mounted) return;
        setState(() {
          _isLoadingTenant = false;
          _tenantError = 'Tenant record not found.';
        });
        return;
      }

      String? propName;
      String? propAddress;
      String? unitNum;

      if (tenant.propertyId != null && tenant.propertyId!.trim().isNotEmpty) {
        try {
          final properties = await _propertyRepo.getProperties();
          for (final p in properties) {
            if (p.id == tenant.propertyId) {
              propName = p.name;
              propAddress = p.address;
              break;
            }
          }
        } catch (_) {
          // Graceful fallback to raw ID
        }
      }

      if (tenant.unitId != null && tenant.unitId!.trim().isNotEmpty) {
        try {
          if (tenant.propertyId != null &&
              tenant.propertyId!.trim().isNotEmpty) {
            final units = await _propertyRepo.getUnits(tenant.propertyId!);
            for (final u in units) {
              if (u.id == tenant.unitId) {
                unitNum = u.unitNumber;
                break;
              }
            }
          }
        } catch (_) {
          // Graceful fallback to raw ID
        }
      }

      if (!mounted) return;
      setState(() {
        _tenant = tenant;
        _resolvedPropertyName = propName;
        _resolvedPropertyAddress = propAddress;
        _resolvedUnitNumber = unitNum;
        _isLoadingTenant = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingTenant = false;
        _tenantError = 'Could not load tenant information.';
      });
    }
  }

  Future<void> _loadComplaints() async {
    if (!mounted) return;
    setState(() {
      _isLoadingComplaints = true;
      _complaintsError = null;
    });

    try {
      List<Complaint> items;
      if (widget.complaintRepository != null) {
        items = await _complaintRepo.list(
          scope: ComplaintScope.forTenant(widget.tenantId),
        );
      } else if (widget.propertyRepository != null) {
        items = await _propertyRepo.getComplaints(tenantId: widget.tenantId);
      } else {
        items = await _complaintRepo.list(
          scope: ComplaintScope.forTenant(widget.tenantId),
        );
      }

      if (!mounted) return;
      setState(() {
        _complaints = items;
        _isLoadingComplaints = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingComplaints = false;
        _complaintsError = 'Could not load complaints history.';
      });
    }
  }

  Future<void> _loadRent() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRent = true;
      _rentError = null;
    });

    try {
      final items = await _rentRepo.list(tenantId: widget.tenantId);
      if (!mounted) return;
      setState(() {
        _rentItems = items;
        _isLoadingRent = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingRent = false;
        _rentError = 'Could not load rent history.';
      });
    }
  }

  StatusBadgeTone _tenantStatusTone(TenantStatus status) {
    return switch (status) {
      TenantStatus.active => StatusBadgeTone.success,
      TenantStatus.pending => StatusBadgeTone.warning,
      TenantStatus.ended => StatusBadgeTone.neutral,
    };
  }

  StatusBadgeTone _rentStatusTone(RentStatus status) {
    return switch (status) {
      RentStatus.paid => StatusBadgeTone.success,
      RentStatus.overdue => StatusBadgeTone.danger,
      RentStatus.promised => StatusBadgeTone.warning,
      RentStatus.contacted => StatusBadgeTone.accent,
      RentStatus.due => StatusBadgeTone.neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Role protection: Only operational office staff may view tenant context.
    if (!widget.userRole.isOperationsStaff) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: EmptyState.restricted(
          key: Key('tenant_context_restricted'),
          title: 'Access restricted',
          message: 'Tenant directory context is only accessible to authorized office staff.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 840;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTenantSummarySection(context),
                              const SizedBox(height: AppSpacing.lg),
                              _buildRentSection(context),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildActiveComplaintsSection(context),
                              const SizedBox(height: AppSpacing.lg),
                              _buildHistoricalComplaintsSection(context),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTenantSummarySection(context),
                        const SizedBox(height: AppSpacing.lg),
                        _buildActiveComplaintsSection(context),
                        const SizedBox(height: AppSpacing.lg),
                        _buildHistoricalComplaintsSection(context),
                        const SizedBox(height: AppSpacing.lg),
                        _buildRentSection(context),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TENANT SUMMARY SECTION
  // ---------------------------------------------------------------------------
  Widget _buildTenantSummarySection(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    if (_isLoadingTenant) {
      return const Column(
        key: Key('tenant_summary_loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: 'Tenant Summary'),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 180, borderRadius: 16),
        ],
      );
    }

    if (_tenantError != null) {
      return Column(
        key: const Key('tenant_summary_error'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Tenant Summary'),
          const SizedBox(height: AppSpacing.md),
          ErrorState.compact(message: _tenantError!, onRetry: _loadTenant),
        ],
      );
    }

    final tenant = _tenant;
    if (tenant == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: 'Tenant Summary'),
          SizedBox(height: AppSpacing.md),
          EmptyState.compact(
            icon: Icons.person_off_outlined,
            title: 'No tenant data',
            message: 'Tenant record is not available.',
          ),
        ],
      );
    }

    final displayName = tenant.fullName.isNotEmpty
        ? tenant.fullName
        : 'Unnamed tenant';
    final phoneDisplay =
        (tenant.phone != null && tenant.phone!.trim().isNotEmpty)
        ? tenant.phone!.trim()
        : 'No phone provided';
    final emailDisplay =
        (tenant.email != null && tenant.email!.trim().isNotEmpty)
        ? tenant.email!.trim()
        : 'No email provided';

    String propertyDisplay;
    if (_resolvedPropertyName != null && _resolvedPropertyName!.isNotEmpty) {
      final addr = _resolvedPropertyAddress;
      propertyDisplay = (addr != null && addr.isNotEmpty)
          ? '$_resolvedPropertyName · $addr'
          : _resolvedPropertyName!;
    } else if (tenant.propertyId != null &&
        tenant.propertyId!.trim().isNotEmpty) {
      propertyDisplay = tenant.propertyId!.trim();
    } else {
      propertyDisplay = 'Unassigned property';
    }

    String unitDisplay;
    if (_resolvedUnitNumber != null && _resolvedUnitNumber!.isNotEmpty) {
      unitDisplay = 'Unit $_resolvedUnitNumber';
    } else if (tenant.unitId != null && tenant.unitId!.trim().isNotEmpty) {
      unitDisplay = 'Unit ${tenant.unitId!.trim()}';
    } else {
      unitDisplay = 'Unassigned unit';
    }

    final hasOccupancy =
        tenant.occupancyStart != null || tenant.occupancyEnd != null;
    String? occupancyDisplay;
    if (hasOccupancy) {
      if (tenant.occupancyStart != null && tenant.occupancyEnd != null) {
        occupancyDisplay =
            '${formatDate(tenant.occupancyStart)} – ${formatDate(tenant.occupancyEnd)}';
      } else if (tenant.occupancyStart != null) {
        occupancyDisplay = 'Started ${formatDate(tenant.occupancyStart)}';
      } else {
        occupancyDisplay = 'Ended ${formatDate(tenant.occupancyEnd)}';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Tenant Summary'),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          key: const Key('tenant_summary_card'),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Name and Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: palette.accentSoft,
                    child: Icon(Icons.person, color: palette.accent, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          key: const Key('tenant_name_text'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: 'Fraunces',
                            color: palette.ink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'ID: ${tenant.id}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    key: const Key('tenant_status_badge'),
                    label:
                        tenant.status.name[0].toUpperCase() +
                        tenant.status.name.substring(1),
                    tone: _tenantStatusTone(tenant.status),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),

              // Contact Info
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: phoneDisplay,
                key: const Key('tenant_phone_text'),
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: emailDisplay,
                key: const Key('tenant_email_text'),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Location Info
              _InfoRow(
                icon: Icons.apartment_outlined,
                label: 'Property',
                value: propertyDisplay,
                key: const Key('tenant_property_text'),
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                icon: Icons.meeting_room_outlined,
                label: 'Unit',
                value: unitDisplay,
                key: const Key('tenant_unit_text'),
              ),

              // Occupancy (only when present)
              if (occupancyDisplay != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(
                  icon: Icons.date_range_outlined,
                  label: 'Occupancy',
                  value: occupancyDisplay,
                  key: const Key('tenant_occupancy_text'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. ACTIVE COMPLAINTS SECTION
  // ---------------------------------------------------------------------------
  Widget _buildActiveComplaintsSection(BuildContext context) {
    if (_isLoadingComplaints) {
      return const Column(
        key: Key('tenant_active_complaints_loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: 'Active Complaints'),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 120, borderRadius: 12),
        ],
      );
    }

    if (_complaintsError != null) {
      return Column(
        key: const Key('tenant_active_complaints_error'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Active Complaints'),
          const SizedBox(height: AppSpacing.md),
          ErrorState.compact(
            message: _complaintsError!,
            onRetry: _loadComplaints,
          ),
        ],
      );
    }

    // Active complaints: not terminal (reopened is active).
    final active = _complaints.where((c) => !c.status.isTerminal).toList()
      ..sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

    return Column(
      key: const Key('tenant_active_complaints_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Active Complaints (${active.length})'),
        const SizedBox(height: AppSpacing.md),
        if (active.isEmpty)
          const EmptyState.compact(
            key: Key('tenant_active_complaints_empty'),
            icon: Icons.task_alt,
            title: 'No active complaints',
            message: 'This tenant currently has no open or active complaints.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: active.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final complaint = active[index];
              return _ComplaintItemCard(
                complaint: complaint,
                onTap: () {
                  ComplaintDetailScreen.open(
                    context,
                    complaint.id,
                    complaint: complaint,
                    complaintRepository: _complaintRepo,
                    userRole: app_role.UserRole.staff,
                    referenceNow: _now,
                  );
                },
              );
            },
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. HISTORICAL COMPLAINTS SECTION
  // ---------------------------------------------------------------------------
  Widget _buildHistoricalComplaintsSection(BuildContext context) {
    if (_isLoadingComplaints) {
      return const Column(
        key: Key('tenant_historical_complaints_loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: 'Historical Complaints'),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 120, borderRadius: 12),
        ],
      );
    }

    if (_complaintsError != null) {
      // If complaints load failed, the error state is already presented in active section.
      return const SizedBox.shrink();
    }

    // Historical complaints: terminal (resolved, closed, cancelled).
    final historical = _complaints.where((c) => c.status.isTerminal).toList()
      ..sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

    return Column(
      key: const Key('tenant_historical_complaints_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Historical Complaints (${historical.length})'),
        const SizedBox(height: AppSpacing.md),
        if (historical.isEmpty)
          const EmptyState.compact(
            key: Key('tenant_historical_complaints_empty'),
            icon: Icons.history,
            title: 'No past complaints',
            message: 'This tenant has no historical, resolved, or closed complaints.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: historical.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final complaint = historical[index];
              return _ComplaintItemCard(
                complaint: complaint,
                isHistorical: true,
                onTap: () {
                  ComplaintDetailScreen.open(
                    context,
                    complaint.id,
                    complaint: complaint,
                    complaintRepository: _complaintRepo,
                    userRole: app_role.UserRole.staff,
                    referenceNow: _now,
                  );
                },
              );
            },
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. RENT & FOLLOW-UP HISTORY SECTION
  // ---------------------------------------------------------------------------
  Widget _buildRentSection(BuildContext context) {
    if (_isLoadingRent) {
      return const Column(
        key: Key('tenant_rent_loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: 'Rent & Follow-Up History'),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 180, borderRadius: 16),
        ],
      );
    }

    if (_rentError != null) {
      return Column(
        key: const Key('tenant_rent_error'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Rent & Follow-Up History'),
          const SizedBox(height: AppSpacing.md),
          ErrorState.compact(message: _rentError!, onRetry: _loadRent),
        ],
      );
    }

    final sortedItems = List<RentItem>.from(_rentItems)
      ..sort((a, b) => b.record.dueDate.compareTo(a.record.dueDate));

    return Column(
      key: const Key('tenant_rent_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Rent & Follow-Up History (${sortedItems.length})',
        ),
        const SizedBox(height: AppSpacing.md),
        if (sortedItems.isEmpty)
          const EmptyState.compact(
            key: Key('tenant_rent_empty'),
            icon: Icons.receipt_long_outlined,
            title: 'No rent records',
            message: 'No rent history or records found for this tenant.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedItems.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = sortedItems[index];
              return _RentRecordCard(
                item: item,
                now: _now,
                repository: _rentRepo,
                statusTone: _rentStatusTone,
              );
            },
          ),
      ],
    );
  }
}

/// Helper info row for icon + label + value.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: palette.muted),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable complaint row card within the tenant context view.
class _ComplaintItemCard extends StatelessWidget {
  const _ComplaintItemCard({
    required this.complaint,
    this.isHistorical = false,
    this.onTap,
  });

  final Complaint complaint;
  final bool isHistorical;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ComplaintStatusBadge(status: complaint.status),
              const SizedBox(width: AppSpacing.xs),
              ComplaintPriorityBadge(priority: complaint.priority),
              if (complaint.isRepeatVisit) ...[
                const SizedBox(width: AppSpacing.xs),
                const StatusBadge(
                  label: 'Repeat visit',
                  tone: StatusBadgeTone.warning,
                ),
              ],
              const Spacer(),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 20, color: palette.muted),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            complaint.title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (complaint.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              complaint.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
          if (complaint.createdAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Filed: ${formatDate(complaint.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.muted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable rent item card with effective status calculation and follow-up timeline.
class _RentRecordCard extends StatelessWidget {
  const _RentRecordCard({
    required this.item,
    required this.now,
    required this.repository,
    required this.statusTone,
  });

  final RentItem item;
  final DateTime now;
  final RentRepository repository;
  final StatusBadgeTone Function(RentStatus) statusTone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final status = effectiveStatus(item.record, now, item.payments);
    final tone = statusTone(status);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Month & Effective Status Badge
          Row(
            children: [
              Expanded(
                child: Text(
                  item.month,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
              ),
              StatusBadge(label: status.displayLabel, tone: tone),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Rent Financial Details
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                'Amount due: ${formatIndianCurrency(item.amountDue)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: palette.ink,
                ),
              ),
              Text(
                'Due date: ${formatDate(item.dueDate)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                ),
              ),
              if (!item.isPaid)
                Text(
                  'Balance: ${formatIndianCurrency(item.balance)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (item.payments.isNotEmpty)
                Text(
                  'Paid: ${formatIndianCurrency(item.amountPaid)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Open detail shortcut
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RentDetailScreen(
                      item: item,
                      repository: repository,
                      readOnly: true,
                      now: now,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('View rent details'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xs),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),

          // Follow-up History Section
          Text(
            'Follow-up history (${item.followUps.length})',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          if (item.followUps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: EmptyState.compact(
                key: Key('rent_follow_ups_empty'),
                icon: Icons.history_toggle_off,
                title: 'No follow-up history',
                message: 'No follow-up communication has been recorded for this rent record.',
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: item.followUps.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final followUp = item.followUps[index];
                return RentFollowUpHistoryItem(followUp: followUp);
              },
            ),
        ],
      ),
    );
  }
}

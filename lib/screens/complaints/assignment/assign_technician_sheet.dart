import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/repositories/assignment_repository.dart';
import 'package:grihsetu/theme/app_palette.dart';
import 'package:grihsetu/utils/assignment_validators.dart';
import 'package:grihsetu/widgets/app_spacing.dart';
import 'package:grihsetu/widgets/complaint_card.dart';
import 'package:grihsetu/widgets/empty_state.dart';
import 'package:grihsetu/widgets/error_state.dart';
import 'package:grihsetu/widgets/skeleton_box.dart';
import 'package:grihsetu/widgets/status_badge.dart';

import 'scheduling_and_reason_section.dart';
import 'technician_card.dart';

enum TechnicianFilter {
  all('All'),
  matchesCategory('Matches category'),
  availableNow('Available now'),
  leastBusy('Least busy');

  const TechnicianFilter(this.label);

  final String label;
}

/// Sheet or dialog panel for assigning or reassigning a technician to a complaint.
class AssignTechnicianSheet extends StatefulWidget {
  const AssignTechnicianSheet({
    super.key,
    required this.complaint,
    required this.repository,
    this.currentTechnician,
    this.isReassign = false,
  });

  final Complaint complaint;
  final AssignmentRepository repository;
  final TechnicianOption? currentTechnician;
  final bool isReassign;

  /// Helper to launch the sheet adaptively depending on screen width.
  static Future<AssignmentResult?> show(
    BuildContext context, {
    required Complaint complaint,
    required AssignmentRepository repository,
    TechnicianOption? currentTechnician,
    bool isReassign = false,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 900) {
      return showModalBottomSheet<AssignmentResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (sheetCtx, scrollController) => AssignTechnicianSheet(
            complaint: complaint,
            repository: repository,
            currentTechnician: currentTechnician,
            isReassign: isReassign,
          ),
        ),
      );
    } else {
      return showDialog<AssignmentResult>(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 420,
            child: AssignTechnicianSheet(
              complaint: complaint,
              repository: repository,
              currentTechnician: currentTechnician,
              isReassign: isReassign,
            ),
          ),
        ),
      );
    }
  }

  @override
  State<AssignTechnicianSheet> createState() => _AssignTechnicianSheetState();
}

class _AssignTechnicianSheetState extends State<AssignTechnicianSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  TechnicianFilter _activeFilter = TechnicianFilter.all;
  List<TechnicianOption>? _technicians;
  bool _isLoading = true;
  String? _loadError;

  String? _selectedTechnicianId;
  ReassignmentReason? _selectedReason;
  DateTime? _visitDate;
  AssignmentSlot? _selectedSlot;

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadTechnicians();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTechnicians() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final list = await widget.repository.loadTechnicians(widget.complaint);
      if (mounted) {
        setState(() {
          _technicians = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  TechnicianOption? get _selectedTechnician {
    if (_selectedTechnicianId == null || _technicians == null) return null;
    try {
      return _technicians!.firstWhere((t) => t.id == _selectedTechnicianId);
    } catch (_) {
      return null;
    }
  }

  List<TechnicianOption> get _filteredTechnicians {
    if (_technicians == null) return [];
    var list = List<TechnicianOption>.from(_technicians!);

    // In reassign mode, exclude current technician from the selectable list
    if (widget.isReassign && widget.complaint.currentTechnicianId != null) {
      list = list
          .where((t) => t.id != widget.complaint.currentTechnicianId)
          .toList();
    }

    // Apply filter
    switch (_activeFilter) {
      case TechnicianFilter.all:
        break;
      case TechnicianFilter.matchesCategory:
        list = list
            .where((t) => t.matchesCategory(widget.complaint.category))
            .toList();
        break;
      case TechnicianFilter.availableNow:
        list = list
            .where((t) => t.availability == TechnicianAvailability.available)
            .toList();
        break;
      case TechnicianFilter.leastBusy:
        list.sort((a, b) => a.todayJobCount.compareTo(b.todayJobCount));
        break;
    }

    // Apply search
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((t) {
        final matchesName = t.name.toLowerCase().contains(query);
        final matchesSpecialty = t.specialties.any(
          (s) => s.displayLabel.toLowerCase().contains(query),
        );
        return matchesName || matchesSpecialty;
      }).toList();
    }

    return list;
  }

  AssignmentValidationResult _computeValidation() {
    final selectedTech = _selectedTechnician;
    return AssignmentValidators.validateAll(
      selectedTechnicianId: _selectedTechnicianId,
      currentTechnicianId: widget.complaint.currentTechnicianId,
      isReassign: widget.isReassign,
      visitDate: _visitDate,
      slot: _selectedSlot,
      note: _noteController.text,
      reason: _selectedReason,
      isOffDuty: selectedTech?.availability == TechnicianAvailability.offDuty,
      matchesCategory:
          selectedTech?.matchesCategory(widget.complaint.category) ?? true,
      todayJobCount: selectedTech?.todayJobCount ?? 0,
      complaintCategory: widget.complaint.category,
    );
  }

  Future<void> _submitAssignment() async {
    final validation = _computeValidation();
    if (!validation.isValid) return;

    final selectedTech = _selectedTechnician;
    if (selectedTech == null) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final request = AssignmentRequest(
        complaint: widget.complaint,
        selectedTechnician: selectedTech,
        isReassignment: widget.isReassign,
        previousTechnician: widget.currentTechnician,
        reason: _selectedReason,
        reasonNote: _noteController.text,
        visitDate: _visitDate,
        slot: _selectedSlot,
        note: _noteController.text,
      );

      final result = await widget.repository.assign(request);
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final validation = _computeValidation();

    final confirmLabel = validation.hasWarnings
        ? (widget.isReassign ? 'Reassign anyway' : 'Assign anyway')
        : (widget.isReassign ? 'Confirm reassignment' : 'Confirm assignment');

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) => Navigator.of(context).maybePop(),
          ),
        },
        child: Container(
          decoration: BoxDecoration(
            color: palette.canvas,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header
                _buildHeader(context),
                const Divider(height: 1),

                // Main Scrollable Area
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Currently assigned technician (Reassign mode only)
                        if (widget.isReassign &&
                            widget.currentTechnician != null) ...[
                          _buildCurrentlyAssignedCard(context),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Search and Filters
                        _buildSearchAndFilters(context),
                        const SizedBox(height: AppSpacing.md),

                        // Technician List / States
                        _buildTechnicianListSection(context),
                        const SizedBox(height: AppSpacing.lg),

                        // Scheduling, Reasons and Warnings
                        SchedulingAndReasonSection(
                          isReassign: widget.isReassign,
                          currentTechnician: widget.currentTechnician,
                          selectedReason: _selectedReason,
                          onReasonChanged: (r) => setState(() {
                            _selectedReason = r;
                          }),
                          visitDate: _visitDate,
                          onDateSelected: (d) => setState(() {
                            _visitDate = d;
                          }),
                          selectedSlot: _selectedSlot,
                          onSlotSelected: (s) => setState(() {
                            _selectedSlot = s;
                          }),
                          noteController: _noteController,
                          noteLength: _noteController.text.length,
                          onNoteChanged: (_) => setState(() {}),
                          warnings: validation.warnings,
                        ),

                        // Submission Error Banner
                        if (_submitError != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: palette.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: palette.danger.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: palette.danger,
                                  size: 20,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    _submitError!,
                                    style: TextStyle(
                                      color: palette.danger,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _submitAssignment,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1),

                // Footer Actions
                _buildFooter(context, validation, confirmLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final complaint = widget.complaint;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.isReassign
                      ? 'Reassign technician'
                      : 'Assign technician',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: palette.ink,
                  ),
                ),
              ),
              IconButton(
                key: const Key('close_assign_sheet_button'),
                icon: const Icon(Icons.close),
                tooltip: 'Close (Esc)',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            complaint.title.isEmpty ? 'Untitled complaint' : complaint.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'ID: ${complaint.id.isEmpty ? "Pending" : complaint.id}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text('·', style: TextStyle(color: palette.muted)),
              StatusBadge(
                label: complaint.category.displayLabel,
                tone: StatusBadgeTone.neutral,
              ),
              ComplaintPriorityBadge(priority: complaint.priority),
              if (complaint.unitId.isNotEmpty)
                Text(
                  'Unit: ${complaint.unitId}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentlyAssignedCard(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final tech = widget.currentTechnician!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currently assigned',
            style: theme.textTheme.labelMedium?.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.shimmer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  tech.initials,
                  style: TextStyle(
                    color: palette.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tech.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      tech.phone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const StatusBadge(
                label: 'Current',
                tone: StatusBadgeTone.neutral,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          key: const Key('technician_search_field'),
          decoration: InputDecoration(
            hintText: 'Search technicians by name or trade...',
            hintStyle: TextStyle(color: palette.muted, fontSize: 13),
            prefixIcon: Icon(Icons.search, size: 20, color: palette.muted),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18, color: palette.muted),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: palette.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: palette.border),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in TechnicianFilter.values) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    key: Key('filter_chip_${filter.name}'),
                    label: Text(filter.label),
                    selected: _activeFilter == filter,
                    selectedColor: palette.accentSoft,
                    backgroundColor: palette.surface,
                    side: BorderSide(
                      color: _activeFilter == filter
                          ? palette.accent
                          : palette.border,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: _activeFilter == filter
                          ? palette.accent
                          : palette.ink,
                      fontWeight: _activeFilter == filter
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setState(() => _activeFilter = filter);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicianListSection(BuildContext context) {
    if (_isLoading) {
      return const Column(
        children: [
          SkeletonBox(width: double.infinity, height: 72, borderRadius: 12),
          SizedBox(height: 10),
          SkeletonBox(width: double.infinity, height: 72, borderRadius: 12),
          SizedBox(height: 10),
          SkeletonBox(width: double.infinity, height: 72, borderRadius: 12),
        ],
      );
    }

    if (_loadError != null) {
      return ErrorState(
        message: 'Could not load technician roster: $_loadError',
        onRetry: _loadTechnicians,
      );
    }

    if (_technicians == null || _technicians!.isEmpty) {
      return const EmptyState(
        icon: Icons.person_off_outlined,
        title: 'No technicians found',
        message: 'There are no active technicians configured in the system.',
      );
    }

    final filtered = _filteredTechnicians;

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: 'No matching technicians',
        message: 'Try clearing the search query or changing active filter.',
        actionLabel: 'Reset filters',
        onAction: () {
          setState(() {
            _searchController.clear();
            _activeFilter = TechnicianFilter.all;
          });
        },
      );
    }

    return Column(
      children: [
        for (final tech in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TechnicianCard(
              key: Key('technician_card_${tech.id}'),
              technician: tech,
              isSelected: _selectedTechnicianId == tech.id,
              complaintCategory: widget.complaint.category,
              onSelect: () {
                setState(() {
                  _selectedTechnicianId = tech.id;
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFooter(
    BuildContext context,
    AssignmentValidationResult validation,
    String confirmLabel,
  ) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      color: palette.surface,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton(
            key: const Key('cancel_assign_button'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(88, 48),
              side: BorderSide(color: palette.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_assign_button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(140, 48),
              backgroundColor: validation.hasWarnings
                  ? palette.warning
                  : palette.accent,
              foregroundColor: validation.hasWarnings
                  ? palette.ink
                  : palette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: validation.isValid && !_isSubmitting
                ? _submitAssignment
                : null,
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        validation.hasWarnings ? palette.ink : palette.surface,
                      ),
                    ),
                  )
                : Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/enums/complaint_priority.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/fixtures/sample_fixtures.dart';
import '../../../core/models/complaint.dart';
import '../../../core/models/user.dart';
import '../../../repositories/complaint_repository.dart';
import '../../../repositories/property_repository.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_palette.dart';
import '../../../utils/complaint_query.dart';
import '../../../widgets/app_spacing.dart';
import '../../../widgets/complaint_card.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/error_state.dart';
import '../../../widgets/skeleton_box.dart';
import '../complaint_detail_screen.dart';
import '../complaint_view_models.dart';
import 'filter_sheet.dart';

/// Complaint search and filter screen for staff, owner, technician, and tenant.
class ComplaintSearchScreen extends StatefulWidget {
  const ComplaintSearchScreen({
    super.key,
    this.initial,
    this.repository,
    this.propertyRepository,
    this.authService,
    this.profile,
    this.scope,
    this.onFilterChanged,
    this.showAppBar = false,
  });

  final ComplaintFilter? initial;
  final ComplaintRepository? repository;
  final PropertyRepository? propertyRepository;
  final AuthService? authService;
  final AppUser? profile;
  final ComplaintScope? scope;
  final ValueChanged<ComplaintFilter>? onFilterChanged;
  final bool showAppBar;

  /// Canonical navigation helper to open search screen pre-filtered.
  static Future<void> open(
    BuildContext context,
    ComplaintFilter filter, {
    ComplaintRepository? repository,
    PropertyRepository? propertyRepository,
    AuthService? authService,
    AppUser? profile,
    ComplaintScope? scope,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComplaintSearchScreen(
          initial: filter,
          repository: repository,
          propertyRepository: propertyRepository,
          authService: authService,
          profile: profile,
          scope: scope,
          showAppBar: true,
        ),
      ),
    );
  }

  @override
  State<ComplaintSearchScreen> createState() => _ComplaintSearchScreenState();
}

class _ComplaintSearchScreenState extends State<ComplaintSearchScreen> {
  late ComplaintRepository _repository;
  late final ComplaintReferenceResolver _resolver;
  late ComplaintFilter _filter;
  late final TextEditingController _textController;

  Timer? _debounceTimer;
  bool _isLoading = true;
  String? _errorMessage;
  List<Complaint> _allComplaints = [];

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        FirestoreComplaintRepository(identity: widget.authService);
    _resolver = ComplaintReferenceResolver(
      propertyRepository: widget.propertyRepository,
    );
    _filter = widget.initial ?? const ComplaintFilter();
    _textController = TextEditingController(text: _filter.text ?? '');
    _loadComplaints();
  }

  @override
  void didUpdateWidget(ComplaintSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.repository != oldWidget.repository &&
        widget.repository != null) {
      _repository = widget.repository!;
      _loadComplaints();
    }
    if (widget.scope != oldWidget.scope) {
      _loadComplaints();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.list(scope: widget.scope);
      await _resolver.resolveForComplaints(list);
      if (mounted) {
        setState(() {
          _allComplaints = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Unable to load complaints. Please check your connection.';
        });
      }
    }
  }

  void _updateFilter(ComplaintFilter newFilter) {
    setState(() {
      _filter = newFilter;
    });
    widget.onFilterChanged?.call(newFilter);
  }

  void _onSearchQueryChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      final trimmed = text.trim();
      final updated = _filter.copyWith(
        text: trimmed,
        clearText: trimmed.isEmpty,
      );
      _updateFilter(updated);
    });
  }

  void _clearSearchText() {
    _debounceTimer?.cancel();
    _textController.clear();
    final updated = _filter.copyWith(clearText: true);
    _updateFilter(updated);
  }

  void _clearAllFilters() {
    _debounceTimer?.cancel();
    _textController.clear();
    final reset = const ComplaintFilter();
    _updateFilter(reset);
  }

  Future<void> _openFilterSheet() async {
    final updated = await FilterSheet.show(
      context,
      initialFilter: _filter,
      allComplaints: _allComplaints,
    );
    if (updated != null && mounted) {
      _updateFilter(updated);
      if (updated.text != _textController.text) {
        _textController.text = updated.text ?? '';
      }
    }
  }

  String _lookupTechName(String? technicianId) {
    if (technicianId == null || technicianId.trim().isEmpty) return '';
    for (final u in SampleFixtures.sampleUsers) {
      if (u.id == technicianId) return u.name;
    }
    return technicianId;
  }

  Widget _buildHighlightedTitle(
    String title,
    String? query,
    BuildContext context,
  ) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.titleMedium?.copyWith(
      color: palette.ink,
      fontWeight: FontWeight.w600,
    );
    final displayTitle = title.isEmpty ? 'Untitled complaint' : title;

    if (query == null || query.trim().isEmpty) {
      return Text(
        displayTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
    }

    final words = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return Text(
        displayTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
    }

    final pattern = RegExp(
      words.map(RegExp.escape).join('|'),
      caseSensitive: false,
    );
    final matches = pattern.allMatches(displayTitle).toList();
    if (matches.isEmpty) {
      return Text(
        displayTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
    }

    final spans = <TextSpan>[];
    var lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: displayTitle.substring(lastEnd, match.start),
            style: textStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: displayTitle.substring(match.start, match.end),
          style: textStyle?.copyWith(
            backgroundColor: palette.warning.withValues(alpha: 0.3),
            color: palette.accent,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < displayTitle.length) {
      spans.add(
        TextSpan(text: displayTitle.substring(lastEnd), style: textStyle),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final filtered = applyFilter(_allComplaints, _filter);
    final activeChips = describe(_filter);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top search bar and filters button
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Search complaints',
                  textField: true,
                  child: TextField(
                    controller: _textController,
                    onChanged: _onSearchQueryChanged,
                    decoration: InputDecoration(
                      hintText: 'Search complaints, tenant, unit...',
                      hintStyle: TextStyle(color: palette.muted),
                      prefixIcon: Icon(Icons.search, color: palette.muted),
                      suffixIcon: _textController.text.isNotEmpty
                          ? Semantics(
                              label: 'Clear search text',
                              button: true,
                              child: IconButton(
                                icon: const Icon(Icons.clear),
                                color: palette.muted,
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                onPressed: _clearSearchText,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: palette.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: palette.accent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Semantics(
                label:
                    'Open filters sheet. Active count: ${_filter.activeCount}',
                button: true,
                child: Badge(
                  isLabelVisible: _filter.activeCount > 0,
                  label: Text('${_filter.activeCount}'),
                  backgroundColor: palette.accent,
                  textColor: palette.canvas,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: palette.ink,
                      side: BorderSide(
                        color: _filter.activeCount > 0
                            ? palette.accent
                            : palette.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      Icons.tune,
                      size: 20,
                      color: _filter.activeCount > 0
                          ? palette.accent
                          : palette.muted,
                    ),
                    label: const Text('Filters'),
                    onPressed: _openFilterSheet,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Live result count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            '${filtered.length} of ${_allComplaints.length} complaints',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Horizontal Quick Chips Row
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              _buildQuickChip(
                context,
                label: 'All',
                count: _allComplaints.length,
                isSelected: _filter.isEmpty,
                onTap: () {
                  _updateFilter(const ComplaintFilter());
                  _textController.clear();
                },
              ),
              _buildQuickChip(
                context,
                label: 'Open',
                count: _allComplaints
                    .where((c) => c.status == ComplaintStatus.open)
                    .length,
                isSelected: _filter.statuses.contains(ComplaintStatus.open),
                onTap: () {
                  final has = _filter.statuses.contains(ComplaintStatus.open);
                  _updateFilter(
                    _filter.copyWith(
                      statuses: has
                          ? _filter.statuses.difference({ComplaintStatus.open})
                          : {..._filter.statuses, ComplaintStatus.open},
                    ),
                  );
                },
              ),
              _buildQuickChip(
                context,
                label: 'Unassigned',
                count: _allComplaints
                    .where(
                      (c) =>
                          c.currentTechnicianId == null ||
                          c.currentTechnicianId!.isEmpty ||
                          c.currentTechnicianId!.toLowerCase() == 'unassigned',
                    )
                    .length,
                isSelected: _filter.technicianId?.toLowerCase() == 'unassigned',
                onTap: () {
                  final isUnassigned =
                      _filter.technicianId?.toLowerCase() == 'unassigned';
                  _updateFilter(
                    _filter.copyWith(
                      technicianId: isUnassigned ? null : 'Unassigned',
                      clearTechnicianId: isUnassigned,
                    ),
                  );
                },
              ),
              _buildQuickChip(
                context,
                label: 'Urgent',
                count: _allComplaints
                    .where((c) => c.priority == ComplaintPriority.urgent)
                    .length,
                isSelected: _filter.priorities.contains(
                  ComplaintPriority.urgent,
                ),
                onTap: () {
                  final has = _filter.priorities.contains(
                    ComplaintPriority.urgent,
                  );
                  _updateFilter(
                    _filter.copyWith(
                      priorities: has
                          ? _filter.priorities.difference({
                              ComplaintPriority.urgent,
                            })
                          : {..._filter.priorities, ComplaintPriority.urgent},
                    ),
                  );
                },
              ),
              _buildQuickChip(
                context,
                label: 'Repeat',
                count: _allComplaints
                    .where((c) => c.isRepeatVisit || c.visitCount >= 2)
                    .length,
                isSelected: _filter.repeatOnly,
                onTap: () {
                  _updateFilter(
                    _filter.copyWith(repeatOnly: !_filter.repeatOnly),
                  );
                },
              ),
              _buildQuickChip(
                context,
                label: 'Overdue',
                count: _allComplaints
                    .where((c) => isComplaintOverdue(c))
                    .length,
                isSelected: _filter.overdueOnly,
                onTap: () {
                  _updateFilter(
                    _filter.copyWith(overdueOnly: !_filter.overdueOnly),
                  );
                },
              ),
              _buildQuickChip(
                context,
                label: 'Waiting for parts',
                count: _allComplaints
                    .where((c) => c.status == ComplaintStatus.waitingForParts)
                    .length,
                isSelected: _filter.statuses.contains(
                  ComplaintStatus.waitingForParts,
                ),
                onTap: () {
                  final has = _filter.statuses.contains(
                    ComplaintStatus.waitingForParts,
                  );
                  _updateFilter(
                    _filter.copyWith(
                      statuses: has
                          ? _filter.statuses.difference({
                              ComplaintStatus.waitingForParts,
                            })
                          : {
                              ..._filter.statuses,
                              ComplaintStatus.waitingForParts,
                            },
                    ),
                  );
                },
              ),
              _buildQuickChip(
                context,
                label: 'Awaiting confirmation',
                count: _allComplaints
                    .where((c) => c.status == ComplaintStatus.resolved)
                    .length,
                isSelected: _filter.statuses.contains(ComplaintStatus.resolved),
                onTap: () {
                  final has = _filter.statuses.contains(
                    ComplaintStatus.resolved,
                  );
                  _updateFilter(
                    _filter.copyWith(
                      statuses: has
                          ? _filter.statuses.difference({
                              ComplaintStatus.resolved,
                            })
                          : {..._filter.statuses, ComplaintStatus.resolved},
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Active filters row (removable chips + Clear all)
        if (activeChips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...activeChips.map((chip) {
                  return Semantics(
                    label: 'Active filter ${chip.label}. Tap to remove.',
                    button: true,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Chip(
                        label: Text(
                          chip.label,
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: palette.accentSoft,
                        side: BorderSide(color: palette.accent),
                        deleteIcon: Icon(
                          Icons.close,
                          size: 16,
                          color: palette.accent,
                        ),
                        onDeleted: () {
                          if (chip.onRemove != null) {
                            final updated = chip.onRemove!(_filter);
                            _updateFilter(updated);
                            if (chip.id == 'text') {
                              _textController.clear();
                            }
                          }
                        },
                      ),
                    ),
                  );
                }),
                Semantics(
                  label: 'Clear all active filters',
                  button: true,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: palette.danger,
                    ),
                    onPressed: _clearAllFilters,
                    child: const Text('Clear all'),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.sm),

        // Result list or states
        Expanded(child: _buildBody(context, filtered)),
      ],
    );

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Search Complaints'))
          : null,
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadComplaints,
          color: palette.accent,
          child: content,
        ),
      ),
    );
  }

  Widget _buildQuickChip(
    BuildContext context, {
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Semantics(
        label: '$label quick filter: $count complaints',
        selected: isSelected,
        button: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: FilterChip(
            label: Text('$label ($count)'),
            selected: isSelected,
            onSelected: (_) => onTap(),
            backgroundColor: palette.surface,
            selectedColor: palette.accentSoft,
            labelStyle: TextStyle(
              color: isSelected ? palette.accent : palette.ink,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? palette.accent : palette.border,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Complaint> filtered) {
    if (_isLoading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SkeletonList(itemCount: 3, spacing: AppSpacing.sm),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: ErrorState(message: _errorMessage!, onRetry: _loadComplaints),
      );
    }

    if (_allComplaints.isEmpty) {
      return const Center(
        child: EmptyState.noData(
          icon: Icons.assignment_outlined,
          title: 'No complaints found',
          message: 'There are no complaints registered in this workspace.',
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: EmptyState.noResults(
          title: _filter.text != null && _filter.text!.trim().isNotEmpty
              ? 'No results for "${_filter.text!.trim()}"'
              : 'No results found',
          message: 'Try adjusting your search terms or active filters.',
          actionLabel: 'Clear filters',
          onAction: _clearAllFilters,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final complaint = filtered[index];
        final propertyName = _resolver.getPropertyName(complaint.propertyId);
        final unitNumber = _resolver.getUnitNumber(complaint.unitId);
        final techName = _lookupTechName(complaint.currentTechnicianId);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ComplaintCard(
            complaint: complaint,
            propertyName: propertyName,
            unitNumber: unitNumber,
            technicianName: techName,
            lastUpdated: complaint.updatedAt,
            titleWidget: _buildHighlightedTitle(
              complaint.title,
              _filter.text,
              context,
            ),
            onTap: () async {
              await ComplaintDetailScreen.open(
                context,
                complaint.id,
                complaint: complaint,
                propertyName: propertyName,
                unitNumber: unitNumber,
                complaintRepository: _repository,
              );
              if (mounted) {
                // Restore and reload while keeping filter and sort
                _loadComplaints();
              }
            },
          ),
        );
      },
    );
  }
}

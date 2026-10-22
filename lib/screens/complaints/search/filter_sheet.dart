import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/enums/complaint_category.dart';
import '../../../core/enums/complaint_priority.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/fixtures/sample_fixtures.dart';
import '../../../core/models/complaint.dart';
import '../../../core/models/property.dart';
import '../../../core/models/user.dart';
import '../../../theme/app_palette.dart';
import '../../../utils/complaint_query.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_spacing.dart';
import '../../../widgets/app_switch.dart';

class _DismissIntent extends Intent {
  const _DismissIntent();
}

/// Filter panel presented as a bottom sheet on mobile screens (<900px)
/// or a 380px right-side panel on desktop and wide screens (>=900px).
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.initialFilter,
    required this.allComplaints,
    this.properties,
    this.units,
    this.technicians,
    this.isSidePanel = false,
  });

  final ComplaintFilter initialFilter;
  final List<Complaint> allComplaints;
  final List<Property>? properties;
  final List<Unit>? units;
  final List<AppUser>? technicians;
  final bool isSidePanel;

  static Future<ComplaintFilter?> show(
    BuildContext context, {
    required ComplaintFilter initialFilter,
    required List<Complaint> allComplaints,
    List<Property>? properties,
    List<Unit>? units,
    List<AppUser>? technicians,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) {
      return showGeneralDialog<ComplaintFilter>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss filter sheet',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, anim1, anim2) {
          return Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 380,
              height: double.infinity,
              child: Material(
                color: context.palette.surface,
                child: FilterSheet(
                  initialFilter: initialFilter,
                  allComplaints: allComplaints,
                  properties: properties,
                  units: units,
                  technicians: technicians,
                  isSidePanel: true,
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, anim1, anim2, child) {
          final offset = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic));
          return SlideTransition(position: offset, child: child);
        },
      );
    } else {
      return showModalBottomSheet<ComplaintFilter>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return FractionallySizedBox(
            heightFactor: 0.88,
            child: FilterSheet(
              initialFilter: initialFilter,
              allComplaints: allComplaints,
              properties: properties,
              units: units,
              technicians: technicians,
              isSidePanel: false,
            ),
          );
        },
      );
    }
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late ComplaintFilter _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialFilter;
  }

  void _reset() {
    setState(() {
      _current = ComplaintFilter(text: _current.text);
    });
  }

  void _apply() {
    Navigator.of(context).pop(_current);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final matchingCount = applyFilter(widget.allComplaints, _current).length;

    final properties = widget.properties ?? SampleFixtures.sampleProperties;
    final units = widget.units ?? SampleFixtures.sampleUnits;
    final technicians = widget.technicians ?? SampleFixtures.sampleUsers;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const _DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (intent) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: palette.border)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Filters',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Semantics(
                      label: 'Reset filters',
                      button: true,
                      child: TextButton(
                        onPressed: _reset,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: palette.accent,
                        ),
                        child: const Text('Reset'),
                      ),
                    ),
                    Semantics(
                      label: 'Close filters',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        color: palette.ink,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable filter controls
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    // Sort section
                    _buildSectionTitle(context, 'Sort by'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: ComplaintSort.values.map((s) {
                        final selected = _current.sort == s;
                        return Semantics(
                          label: 'Sort by ${s.label}',
                          selected: selected,
                          button: true,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: FilterChip(
                              label: Text(s.label),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _current = _current.copyWith(sort: s);
                                });
                              },
                              backgroundColor: palette.surface,
                              selectedColor: palette.accentSoft,
                              labelStyle: TextStyle(
                                color: selected ? palette.accent : palette.ink,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: selected
                                      ? palette.accent
                                      : palette.border,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Quick switches (Repeat only, Overdue only)
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        children: [
                          Semantics(
                            label: 'Filter by repeat visits only',
                            child: AppSwitch(
                              title: 'Repeat only',
                              value: _current.repeatOnly,
                              onChanged: (val) {
                                setState(() {
                                  _current = _current.copyWith(repeatOnly: val);
                                });
                              },
                            ),
                          ),
                          Divider(color: palette.border, height: 1),
                          Semantics(
                            label: 'Filter by SLA overdue complaints only',
                            child: AppSwitch(
                              title: 'Overdue only (SLA breached)',
                              value: _current.overdueOnly,
                              onChanged: (val) {
                                setState(() {
                                  _current = _current.copyWith(
                                    overdueOnly: val,
                                  );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Status multi-select
                    _buildSectionTitle(context, 'Status'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: ComplaintStatus.values.map((s) {
                        final selected = _current.statuses.contains(s);
                        return Semantics(
                          label: 'Filter status ${s.displayLabel}',
                          selected: selected,
                          button: true,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: FilterChip(
                              label: Text(s.displayLabel),
                              selected: selected,
                              onSelected: (active) {
                                setState(() {
                                  final next = Set<ComplaintStatus>.from(
                                    _current.statuses,
                                  );
                                  if (active) {
                                    next.add(s);
                                  } else {
                                    next.remove(s);
                                  }
                                  _current = _current.copyWith(statuses: next);
                                });
                              },
                              backgroundColor: palette.surface,
                              selectedColor: palette.accentSoft,
                              labelStyle: TextStyle(
                                color: selected ? palette.accent : palette.ink,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: selected
                                      ? palette.accent
                                      : palette.border,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Priority multi-select
                    _buildSectionTitle(context, 'Priority'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: ComplaintPriority.values.map((p) {
                        final selected = _current.priorities.contains(p);
                        return Semantics(
                          label: 'Filter priority ${p.displayLabel}',
                          selected: selected,
                          button: true,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: FilterChip(
                              label: Text(p.displayLabel),
                              selected: selected,
                              onSelected: (active) {
                                setState(() {
                                  final next = Set<ComplaintPriority>.from(
                                    _current.priorities,
                                  );
                                  if (active) {
                                    next.add(p);
                                  } else {
                                    next.remove(p);
                                  }
                                  _current = _current.copyWith(
                                    priorities: next,
                                  );
                                });
                              },
                              backgroundColor: palette.surface,
                              selectedColor: palette.accentSoft,
                              labelStyle: TextStyle(
                                color: selected ? palette.accent : palette.ink,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: selected
                                      ? palette.accent
                                      : palette.border,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Category multi-select
                    _buildSectionTitle(context, 'Category'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: ComplaintCategory.values.map((c) {
                        final selected = _current.categories.contains(c);
                        return Semantics(
                          label: 'Filter category ${c.displayLabel}',
                          selected: selected,
                          button: true,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: FilterChip(
                              label: Text(c.displayLabel),
                              selected: selected,
                              onSelected: (active) {
                                setState(() {
                                  final next = Set<ComplaintCategory>.from(
                                    _current.categories,
                                  );
                                  if (active) {
                                    next.add(c);
                                  } else {
                                    next.remove(c);
                                  }
                                  _current = _current.copyWith(
                                    categories: next,
                                  );
                                });
                              },
                              backgroundColor: palette.surface,
                              selectedColor: palette.accentSoft,
                              labelStyle: TextStyle(
                                color: selected ? palette.accent : palette.ink,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: selected
                                      ? palette.accent
                                      : palette.border,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Property & Unit
                    _buildSectionTitle(context, 'Property & Unit'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        border: Border.all(color: palette.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _current.propertyId,
                          hint: Text(
                            'All properties',
                            style: TextStyle(color: palette.muted),
                          ),
                          dropdownColor: palette.surface,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'All properties',
                                style: TextStyle(color: palette.ink),
                              ),
                            ),
                            ...properties.map(
                              (p) => DropdownMenuItem<String?>(
                                value: p.id,
                                child: Text(
                                  p.name,
                                  style: TextStyle(color: palette.ink),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _current = _current.copyWith(
                                propertyId: val,
                                clearPropertyId: val == null,
                              );
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        border: Border.all(color: palette.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _current.unitId,
                          hint: Text(
                            'All units',
                            style: TextStyle(color: palette.muted),
                          ),
                          dropdownColor: palette.surface,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'All units',
                                style: TextStyle(color: palette.ink),
                              ),
                            ),
                            ...units.map(
                              (u) => DropdownMenuItem<String?>(
                                value: u.id,
                                child: Text(
                                  'Unit ${u.unitNumber}',
                                  style: TextStyle(color: palette.ink),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _current = _current.copyWith(
                                unitId: val,
                                clearUnitId: val == null,
                              );
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Technician
                    _buildSectionTitle(context, 'Technician'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        border: Border.all(color: palette.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _current.technicianId,
                          hint: Text(
                            'All technicians',
                            style: TextStyle(color: palette.muted),
                          ),
                          dropdownColor: palette.surface,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'All technicians',
                                style: TextStyle(color: palette.ink),
                              ),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Unassigned',
                              child: Text(
                                'Unassigned',
                                style: TextStyle(
                                  color: palette.ink,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...technicians.map(
                              (t) => DropdownMenuItem<String?>(
                                value: t.id,
                                child: Text(
                                  t.name,
                                  style: TextStyle(color: palette.ink),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _current = _current.copyWith(
                                technicianId: val,
                                clearTechnicianId: val == null,
                              );
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Date range
                    _buildSectionTitle(context, 'Created Date Range'),
                    Semantics(
                      label: 'Select created date range',
                      button: true,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: palette.ink,
                          side: BorderSide(color: palette.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(Icons.date_range, color: palette.muted),
                        label: Text(
                          _current.createdDateRange == null
                              ? 'Any time'
                              : '${_current.createdDateRange!.start.day}/${_current.createdDateRange!.start.month}/${_current.createdDateRange!.start.year} - ${_current.createdDateRange!.end.day}/${_current.createdDateRange!.end.month}/${_current.createdDateRange!.end.year}',
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            initialDateRange: _current.createdDateRange,
                          );
                          if (picked != null) {
                            setState(() {
                              _current = _current.copyWith(
                                createdDateRange: picked,
                              );
                            });
                          }
                        },
                      ),
                    ),
                    if (_current.createdDateRange != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _current = _current.copyWith(
                                clearCreatedDateRange: true,
                              );
                            });
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            foregroundColor: palette.danger,
                          ),
                          child: const Text('Clear date range'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Bottom Apply button bar
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(top: BorderSide(color: palette.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Semantics(
                    label: 'Apply filters and show $matchingCount results',
                    button: true,
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: palette.canvas,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _apply,
                        child: Text(
                          'Show $matchingCount results',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs, top: AppSpacing.xs),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: palette.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

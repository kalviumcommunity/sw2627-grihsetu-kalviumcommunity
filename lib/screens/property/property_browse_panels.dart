import 'package:flutter/material.dart';

import '../../widgets/app_spacing.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_badge.dart';
import 'property_view_models.dart';

class PropertyListPanel extends StatefulWidget {
  const PropertyListPanel({
    super.key,
    required this.properties,
    required this.onSelected,
    this.selectedId,
    this.heading = 'Properties',
  });

  final List<PropertyBrowseData> properties;
  final ValueChanged<PropertyBrowseData> onSelected;
  final String? selectedId;
  final String heading;

  @override
  State<PropertyListPanel> createState() => _PropertyListPanelState();
}

class _PropertyListPanelState extends State<PropertyListPanel> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.properties
        .where((item) {
          final query = _query.trim().toLowerCase();
          return query.isEmpty ||
              '${item.property.name} ${item.locality} ${item.property.address}'
                  .toLowerCase()
                  .contains(query);
        })
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: widget.heading),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Search properties',
            prefixIcon: const Icon(Icons.search, semanticLabel: 'Search'),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${results.length} ${results.length == 1 ? 'property' : 'properties'}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: results.isEmpty
              ? EmptyState(
                  icon: Icons.apartment_outlined,
                  title: widget.properties.isEmpty
                      ? 'No properties yet'
                      : 'No results for “$_query”',
                  message: widget.properties.isEmpty
                      ? 'Properties will appear here when they are added.'
                      : 'Try another name or locality.',
                  actionLabel: _query.isEmpty ? null : 'Clear search',
                  onAction: _query.isEmpty
                      ? null
                      : () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  itemCount: results.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return _PropertyCard(
                      data: item,
                      selected: item.property.id == widget.selectedId,
                      onTap: () => widget.onSelected(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final PropertyBrowseData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    selected: selected,
    onTap: onTap,
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                data.property.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'Fraunces',
                  color: context.palette.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (data.openComplaints > 0)
              StatusBadge(
                label: '${data.openComplaints} open',
                tone: StatusBadgeTone.warning,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          data.locality,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                '${data.occupiedUnits} of ${data.totalUnits} units occupied',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.palette.ink),
              ),
            ),
            Text(
              '${data.totalUnits == 0 ? 0 : (data.occupiedUnits / data.totalUnits * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: context.palette.muted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          label: '${data.occupiedUnits} of ${data.totalUnits} units occupied',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: data.totalUnits == 0
                  ? 0
                  : data.occupiedUnits / data.totalUnits,
              backgroundColor: context.palette.shimmer,
              color: context.palette.accent,
            ),
          ),
        ),
      ],
    ),
  );
}

enum UnitFilter { all, occupied, vacant, complaints }

class UnitListPanel extends StatefulWidget {
  const UnitListPanel({
    super.key,
    required this.units,
    required this.onSelected,
    this.selectedId,
    this.requireTenant = false,
    this.heading = 'Units',
  });

  final List<UnitBrowseData> units;
  final ValueChanged<UnitBrowseData> onSelected;
  final String? selectedId;
  final bool requireTenant;
  final String heading;

  @override
  State<UnitListPanel> createState() => _UnitListPanelState();
}

class _UnitListPanelState extends State<UnitListPanel> {
  final _search = TextEditingController();
  String _query = '';
  UnitFilter _filter = UnitFilter.all;
  bool _groupByFloor = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.units
        .where((item) {
          final queryMatches = item.unit.unitNumber.toLowerCase().contains(
            _query.trim().toLowerCase(),
          );
          final filterMatches = switch (_filter) {
            UnitFilter.all => true,
            UnitFilter.occupied => item.isOccupied,
            UnitFilter.vacant => !item.isOccupied,
            UnitFilter.complaints => item.openComplaints > 0,
          };
          return queryMatches && filterMatches;
        })
        .toList(growable: false);
    final floors = filtered.map((item) => item.unit.floor).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: widget.heading),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            labelText: 'Search unit number',
            prefixIcon: const Icon(Icons.search, semanticLabel: 'Search units'),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _filterChip(context, 'All', UnitFilter.all),
            _filterChip(context, 'Occupied', UnitFilter.occupied),
            _filterChip(context, 'Vacant', UnitFilter.vacant),
            _filterChip(context, 'Has open complaints', UnitFilter.complaints),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '${filtered.length} ${filtered.length == 1 ? 'unit' : 'units'}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.palette.muted),
              ),
            ),
            const Text('Group by floor'),
            Semantics(
              label: 'Group units by floor',
              child: Switch(
                value: _groupByFloor,
                onChanged: (value) => setState(() => _groupByFloor = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.door_front_door_outlined,
                  title: widget.units.isEmpty
                      ? 'No units yet'
                      : 'No results for “${_query.isNotEmpty ? _query : _filter.label}”',
                  message: widget.units.isEmpty
                      ? 'Units for this property will appear here.'
                      : 'Clear the search or choose another filter.',
                  actionLabel: _query.isNotEmpty || _filter != UnitFilter.all
                      ? 'Clear filters'
                      : null,
                  onAction: _query.isNotEmpty || _filter != UnitFilter.all
                      ? () => setState(() {
                          _search.clear();
                          _query = '';
                          _filter = UnitFilter.all;
                        })
                      : null,
                )
              : _groupByFloor
              ? ListView(
                  children: [
                    for (final floor in floors) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Text(
                          'Floor $floor',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: context.palette.muted),
                        ),
                      ),
                      _UnitGrid(
                        units: filtered
                            .where((item) => item.unit.floor == floor)
                            .toList(),
                        selectedId: widget.selectedId,
                        requireTenant: widget.requireTenant,
                        onSelected: widget.onSelected,
                      ),
                    ],
                  ],
                )
              : _UnitGrid(
                  units: filtered,
                  selectedId: widget.selectedId,
                  requireTenant: widget.requireTenant,
                  onSelected: widget.onSelected,
                ),
        ),
      ],
    );
  }

  Widget _filterChip(BuildContext context, String label, UnitFilter filter) =>
      FilterChip(
        label: Text(label),
        selected: _filter == filter,
        onSelected: (_) => setState(() => _filter = filter),
        showCheckmark: false,
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      );
}

extension on UnitFilter {
  String get label => switch (this) {
    UnitFilter.all => 'All',
    UnitFilter.occupied => 'Occupied',
    UnitFilter.vacant => 'Vacant',
    UnitFilter.complaints => 'Has open complaints',
  };
}

class _UnitGrid extends StatelessWidget {
  const _UnitGrid({
    required this.units,
    required this.selectedId,
    required this.requireTenant,
    required this.onSelected,
  });

  final List<UnitBrowseData> units;
  final String? selectedId;
  final bool requireTenant;
  final ValueChanged<UnitBrowseData> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GridView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      itemCount: units.length,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: constraints.maxWidth >= 640 ? 220 : 360,
        mainAxisExtent: 216,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemBuilder: (context, index) {
        final item = units[index];
        final enabled =
            !requireTenant || (item.isOccupied && item.tenants.isNotEmpty);
        return _UnitTile(
          data: item,
          selected: item.unit.id == selectedId,
          enabled: enabled,
          onTap: enabled ? () => onSelected(item) : null,
        );
      },
    ),
  );
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({
    required this.data,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final UnitBrowseData data;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    selected: selected,
    onTap: onTap,
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Semantics(
              label: data.isOccupied ? 'Occupied' : 'Vacant',
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: data.isOccupied
                      ? context.palette.success
                      : context.palette.muted,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                data.unit.unitNumber,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.palette.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          data.residentLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.palette.muted),
        ),
        const Spacer(),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBadge(
              label: data.isOccupied ? 'Occupied' : 'Vacant',
              tone: data.isOccupied
                  ? StatusBadgeTone.success
                  : StatusBadgeTone.neutral,
            ),
            if (data.repeatComplaints > 0)
              Tooltip(
                message: '${data.repeatComplaints} repeat complaints',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.replay,
                      size: 16,
                      color: context.palette.warning,
                      semanticLabel: 'Repeat complaints',
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${data.repeatComplaints}',
                      style: TextStyle(color: context.palette.warning),
                    ),
                  ],
                ),
              ),
            if (!enabled)
              const Tooltip(
                message: 'Select an occupied unit to choose a tenant',
                child: Icon(
                  Icons.lock_outline,
                  size: 18,
                  semanticLabel: 'Not selectable',
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class TenantListPanel extends StatefulWidget {
  const TenantListPanel({
    super.key,
    required this.tenants,
    required this.onSelected,
    this.selectedId,
    this.heading = 'Tenants',
  });

  final List<TenantBrowseData> tenants;
  final ValueChanged<TenantBrowseData> onSelected;
  final String? selectedId;
  final String heading;

  @override
  State<TenantListPanel> createState() => _TenantListPanelState();
}

class _TenantListPanelState extends State<TenantListPanel> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.tenants
        .where((item) {
          final query = _query.trim().toLowerCase();
          return query.isEmpty ||
              '${item.tenant.name} ${item.tenant.phone}'.toLowerCase().contains(
                query,
              );
        })
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: widget.heading),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            labelText: 'Search tenants',
            prefixIcon: const Icon(
              Icons.search,
              semanticLabel: 'Search tenants',
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${results.length} ${results.length == 1 ? 'tenant' : 'tenants'}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: results.isEmpty
              ? EmptyState(
                  icon: Icons.person_search_outlined,
                  title: widget.tenants.isEmpty
                      ? 'No tenants in this unit'
                      : 'No results for “$_query”',
                  message: widget.tenants.isEmpty
                      ? 'A tenant can be assigned when the unit is occupied.'
                      : 'Try a different name or phone number.',
                  actionLabel: widget.tenants.isEmpty ? null : 'Clear search',
                  onAction: widget.tenants.isEmpty
                      ? null
                      : () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                )
              : ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final data = results[index];
                    return AppCard(
                      selected: data.tenant.id == widget.selectedId,
                      onTap: () => widget.onSelected(data),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  data.tenant.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontFamily: 'Fraunces',
                                        color: context.palette.ink,
                                      ),
                                ),
                              ),
                              if (data.isPrimary)
                                const StatusBadge(
                                  label: 'Primary',
                                  tone: StatusBadgeTone.accent,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            data.tenant.phone,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.palette.muted),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Lease started ${_date(data.leaseStart)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.palette.ink),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          StatusBadge(
                            label:
                                '${data.recentComplaints} recent ${data.recentComplaints == 1 ? 'complaint' : 'complaints'}',
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

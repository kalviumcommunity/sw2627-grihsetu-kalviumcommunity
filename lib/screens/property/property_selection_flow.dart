import 'package:flutter/material.dart';

import '../../widgets/app_spacing.dart';
import '../../repositories/property_repository.dart';
import '../../theme/app_palette.dart';
import '../../widgets/error_state.dart';
import '../../widgets/skeleton_box.dart';
import 'property_browse_panels.dart';
import 'property_view_models.dart';

class PropertyUnitTenantSelection {
  const PropertyUnitTenantSelection({
    required this.propertyId,
    required this.unitId,
    required this.propertyName,
    required this.unitNumber,
    this.tenantId,
    this.tenantName,
  });

  final String propertyId;
  final String unitId;
  final String? tenantId;
  final String propertyName;
  final String unitNumber;
  final String? tenantName;
}

class PropertySelectionFlow {
  const PropertySelectionFlow._();

  static Future<PropertyUnitTenantSelection?> pick(
    BuildContext context, {
    bool requireTenant = true,
    PropertyRepository? repository,
  }) => Navigator.of(context).push<PropertyUnitTenantSelection>(
    MaterialPageRoute<PropertyUnitTenantSelection>(
      fullscreenDialog: true,
      builder: (_) => _PropertySelectionScreen(
        requireTenant: requireTenant,
        repository: repository ?? InMemoryPropertyRepository(),
      ),
    ),
  );
}

class _PropertySelectionScreen extends StatefulWidget {
  const _PropertySelectionScreen({
    required this.requireTenant,
    required this.repository,
  });

  final bool requireTenant;
  final PropertyRepository repository;

  @override
  State<_PropertySelectionScreen> createState() =>
      _PropertySelectionScreenState();
}

class _PropertySelectionScreenState extends State<_PropertySelectionScreen> {
  late Future<List<PropertyBrowseData>> _directory = loadPropertyDirectory(
    widget.repository,
  );

  void _retry() =>
      setState(() => _directory = loadPropertyDirectory(widget.repository));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.canvas,
    appBar: AppBar(title: const Text('Select a property')),
    body: SafeArea(
      child: FutureBuilder<List<PropertyBrowseData>>(
        future: _directory,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              message: 'Property directory could not be loaded.',
              onRetry: _retry,
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SkeletonList(itemCount: 3),
            );
          }
          return _PropertySelectionBody(
            directory: snapshot.data!,
            requireTenant: widget.requireTenant,
          );
        },
      ),
    ),
  );
}

class _PropertySelectionBody extends StatefulWidget {
  const _PropertySelectionBody({
    required this.directory,
    required this.requireTenant,
  });

  final List<PropertyBrowseData> directory;
  final bool requireTenant;

  @override
  State<_PropertySelectionBody> createState() => _PropertySelectionBodyState();
}

class _PropertySelectionBodyState extends State<_PropertySelectionBody> {
  PropertyBrowseData? _property;
  UnitBrowseData? _unit;
  TenantBrowseData? _tenant;
  int _step = 0;

  bool get _wide => MediaQuery.sizeOf(context).width >= 900;
  bool get _canConfirm =>
      _property != null &&
      _unit != null &&
      (!widget.requireTenant || _tenant != null);

  void _selectProperty(PropertyBrowseData property) => setState(() {
    _property = property;
    _unit = null;
    _tenant = null;
    _step = 1;
  });

  void _selectUnit(UnitBrowseData unit) {
    if (widget.requireTenant && (!unit.isOccupied || unit.tenants.isEmpty)) {
      return;
    }
    setState(() {
      _unit = unit;
      _tenant = null;
      _step = 2;
    });
  }

  void _confirm() {
    if (!_canConfirm) {
      return;
    }
    Navigator.of(context).pop(
      PropertyUnitTenantSelection(
        propertyId: _property!.property.id,
        unitId: _unit!.unit.id,
        tenantId: _tenant?.tenant.id,
        propertyName: _property!.property.name,
        unitNumber: _unit!.unit.unitNumber,
        tenantName: _tenant?.tenant.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final directory = widget.directory;
    return Column(
      children: [
        _Breadcrumbs(
          property: _property,
          unit: _unit,
          tenant: _tenant,
          step: _step,
          wide: _wide,
          onStep: (step) => setState(() => _step = step),
        ),
        const Divider(height: 1),
        Expanded(
          child: _wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: PropertyListPanel(
                          properties: directory,
                          selectedId: _property?.property.id,
                          onSelected: _selectProperty,
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: _property == null
                            ? const _ChooseLevel(
                                label: 'Choose a property to see its units.',
                              )
                            : UnitListPanel(
                                units: _property!.units,
                                requireTenant: widget.requireTenant,
                                selectedId: _unit?.unit.id,
                                onSelected: _selectUnit,
                              ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: _unit == null
                            ? const _ChooseLevel(
                                label: 'Choose a unit to see its tenants.',
                              )
                            : TenantListPanel(
                                tenants: _unit!.tenants,
                                selectedId: _tenant?.tenant.id,
                                onSelected: (tenant) =>
                                    setState(() => _tenant = tenant),
                              ),
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: switch (_step) {
                    0 => PropertyListPanel(
                      properties: directory,
                      selectedId: _property?.property.id,
                      onSelected: _selectProperty,
                    ),
                    1 =>
                      _property == null
                          ? const _ChooseLevel(
                              label: 'Choose a property first.',
                            )
                          : UnitListPanel(
                              units: _property!.units,
                              requireTenant: widget.requireTenant,
                              selectedId: _unit?.unit.id,
                              onSelected: _selectUnit,
                            ),
                    _ =>
                      _unit == null
                          ? const _ChooseLevel(label: 'Choose a unit first.')
                          : TenantListPanel(
                              tenants: _unit!.tenants,
                              selectedId: _tenant?.tenant.id,
                              onSelected: (tenant) =>
                                  setState(() => _tenant = tenant),
                            ),
                  },
                ),
        ),
        _SelectionBottomBar(
          property: _property,
          unit: _unit,
          tenant: _tenant,
          canConfirm: _canConfirm,
          onConfirm: _confirm,
        ),
      ],
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({
    required this.property,
    required this.unit,
    required this.tenant,
    required this.step,
    required this.wide,
    required this.onStep,
  });

  final PropertyBrowseData? property;
  final UnitBrowseData? unit;
  final TenantBrowseData? tenant;
  final int step;
  final bool wide;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      children: [
        _Crumb(
          label: property?.property.name ?? 'Property',
          active: step == 0,
          enabled: property != null,
          onTap: () => onStep(0),
        ),
        const Icon(Icons.chevron_right, size: 18),
        _Crumb(
          label: unit?.unit.unitNumber ?? 'Unit',
          active: step == 1,
          enabled: property != null,
          onTap: () => onStep(1),
        ),
        if (tenant != null || !wide) ...[
          const Icon(Icons.chevron_right, size: 18),
          _Crumb(
            label: tenant?.tenant.name ?? 'Tenant',
            active: step == 2,
            enabled: unit != null,
            onTap: () => onStep(2),
          ),
        ],
      ],
    ),
  );
}

class _Crumb extends StatelessWidget {
  const _Crumb({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? context.palette.accent : context.palette.muted;
    return TextButton(
      onPressed: enabled ? onTap : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _SelectionBottomBar extends StatelessWidget {
  const _SelectionBottomBar({
    required this.property,
    required this.unit,
    required this.tenant,
    required this.canConfirm,
    required this.onConfirm,
  });

  final PropertyBrowseData? property;
  final UnitBrowseData? unit;
  final TenantBrowseData? tenant;
  final bool canConfirm;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final summary = Text(
      [
            property?.property.name,
            unit?.unit.unitNumber,
            tenant?.tenant.name,
          ].whereType<String>().join('  ›  ').isEmpty
          ? 'Choose a property, unit, and tenant'
          : [
              property?.property.name,
              unit?.unit.unitNumber,
              tenant?.tenant.name,
            ].whereType<String>().join('  ›  '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: context.palette.ink),
    );
    return Material(
      color: context.palette.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 520
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton(
                        onPressed: canConfirm ? onConfirm : null,
                        child: const Text('Confirm selection'),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: summary),
                      const SizedBox(width: AppSpacing.md),
                      FilledButton(
                        onPressed: canConfirm ? onConfirm : null,
                        child: const Text('Confirm selection'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ChooseLevel extends StatelessWidget {
  const _ChooseLevel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(color: context.palette.muted),
    ),
  );
}

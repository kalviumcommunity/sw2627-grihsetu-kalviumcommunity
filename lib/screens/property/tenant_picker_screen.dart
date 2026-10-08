import 'package:flutter/material.dart';

import '../../widgets/app_spacing.dart';
import '../../core/models/property.dart';
import '../../repositories/property_repository.dart';
import '../../theme/app_palette.dart';
import '../../widgets/error_state.dart';
import '../../widgets/skeleton_box.dart';
import 'property_browse_panels.dart';
import 'property_view_models.dart';

class TenantPickerScreen extends StatefulWidget {
  const TenantPickerScreen({
    super.key,
    required this.property,
    required this.unit,
    this.repository,
  });

  final Property property;
  final Unit unit;
  final PropertyRepository? repository;

  @override
  State<TenantPickerScreen> createState() => _TenantPickerScreenState();
}

class _TenantPickerScreenState extends State<TenantPickerScreen> {
  late final PropertyRepository _repository =
      widget.repository ?? InMemoryPropertyRepository();
  late Future<List<PropertyBrowseData>> _directory = loadPropertyDirectory(
    _repository,
  );
  String? _selectedTenantId;

  void _retry() =>
      setState(() => _directory = loadPropertyDirectory(_repository));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.canvas,
    appBar: AppBar(title: Text(widget.unit.unitNumber)),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FutureBuilder<List<PropertyBrowseData>>(
          future: _directory,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                message: 'Tenants could not be loaded.',
                onRetry: _retry,
              );
            }
            if (!snapshot.hasData) {
              return const SkeletonList(itemCount: 2);
            }
            final property = firstWhereOrNull(
              snapshot.data!,
              (item) => item.property.id == widget.property.id,
            );
            final unit = property == null
                ? null
                : firstWhereOrNull(
                    property.units,
                    (item) => item.unit.id == widget.unit.id,
                  );
            if (unit == null) {
              return const Center(
                child: Text('This unit is no longer available.'),
              );
            }
            return TenantListPanel(
              tenants: unit.tenants,
              selectedId: _selectedTenantId,
              onSelected: (tenant) =>
                  setState(() => _selectedTenantId = tenant.tenant.id),
            );
          },
        ),
      ),
    ),
  );
}

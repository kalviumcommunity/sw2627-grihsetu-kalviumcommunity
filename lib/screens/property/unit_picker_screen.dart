import 'package:flutter/material.dart';

import '../../widgets/app_spacing.dart';
import '../../core/models/property.dart';
import '../../repositories/property_repository.dart';
import '../../theme/app_palette.dart';
import '../../widgets/error_state.dart';
import '../../widgets/skeleton_box.dart';
import 'property_browse_panels.dart';
import 'property_view_models.dart';
import 'tenant_picker_screen.dart';

class UnitPickerScreen extends StatefulWidget {
  const UnitPickerScreen({super.key, required this.property, this.repository});

  final Property property;
  final PropertyRepository? repository;

  @override
  State<UnitPickerScreen> createState() => _UnitPickerScreenState();
}

class _UnitPickerScreenState extends State<UnitPickerScreen> {
  late final PropertyRepository _repository =
      widget.repository ?? InMemoryPropertyRepository();
  late Future<List<PropertyBrowseData>> _directory = loadPropertyDirectory(
    _repository,
  );
  String? _selectedUnitId;

  void _retry() =>
      setState(() => _directory = loadPropertyDirectory(_repository));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.canvas,
    appBar: AppBar(title: Text(widget.property.name)),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FutureBuilder<List<PropertyBrowseData>>(
          future: _directory,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                message: 'Units could not be loaded.',
                onRetry: _retry,
              );
            }
            if (!snapshot.hasData) {
              return const SkeletonList(itemCount: 3);
            }
            final entry = firstWhereOrNull(
              snapshot.data!,
              (item) => item.property.id == widget.property.id,
            );
            if (entry == null) {
              return const Center(
                child: Text('This property is no longer available.'),
              );
            }
            return UnitListPanel(
              units: entry.units,
              selectedId: _selectedUnitId,
              onSelected: (item) {
                setState(() => _selectedUnitId = item.unit.id);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TenantPickerScreen(
                      unit: item.unit,
                      property: widget.property,
                      repository: _repository,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}

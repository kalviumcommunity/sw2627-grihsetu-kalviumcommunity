import 'package:flutter/material.dart';

import '../../widgets/app_spacing.dart';
import '../../repositories/property_repository.dart';
import '../../theme/app_palette.dart';
import '../../widgets/error_state.dart';
import '../../widgets/skeleton_box.dart';
import 'property_browse_panels.dart';
import 'property_view_models.dart';
import 'unit_picker_screen.dart';

class PropertyBrowserScreen extends StatefulWidget {
  const PropertyBrowserScreen({
    super.key,
    this.repository,
    this.showAppBar = true,
  });

  final PropertyRepository? repository;
  final bool showAppBar;

  @override
  State<PropertyBrowserScreen> createState() => _PropertyBrowserScreenState();
}

class _PropertyBrowserScreenState extends State<PropertyBrowserScreen> {
  late final PropertyRepository _repository =
      widget.repository ?? InMemoryPropertyRepository();
  late Future<List<PropertyBrowseData>> _directory = loadPropertyDirectory(
    _repository,
  );

  void _retry() =>
      setState(() => _directory = loadPropertyDirectory(_repository));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.canvas,
    appBar: widget.showAppBar ? AppBar(title: const Text('Properties')) : null,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FutureBuilder<List<PropertyBrowseData>>(
          future: _directory,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                message: 'Properties could not be loaded.',
                onRetry: _retry,
              );
            }
            if (!snapshot.hasData) return const SkeletonList(itemCount: 4);
            return PropertyListPanel(
              properties: snapshot.data!,
              onSelected: (item) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => UnitPickerScreen(
                    property: item.property,
                    repository: _repository,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

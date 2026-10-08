import 'package:flutter/material.dart';

import '../../core/enums/user_role.dart';
import '../../core/models/user.dart';
import '../../services/reference_data_seed_service.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';

/// Minimal developer/operations screen to seed deterministic reference data
/// into Cloud Firestore.
///
/// Restricted to authorized operations staff ([UserRole.isOperationsStaff]).
class ReferenceDataSeedScreen extends StatefulWidget {
  const ReferenceDataSeedScreen({
    super.key,
    required this.profile,
    this.seedService,
  });

  final AppUser profile;
  final ReferenceDataSeedService? seedService;

  @override
  State<ReferenceDataSeedScreen> createState() =>
      _ReferenceDataSeedScreenState();
}

class _ReferenceDataSeedScreenState extends State<ReferenceDataSeedScreen> {
  late final ReferenceDataSeedService _seedService =
      widget.seedService ?? ReferenceDataSeedService();

  bool _isLoading = false;
  String? _loadingTask;
  String? _errorMessage;
  String? _successMessage;
  ReferenceDataSeedResult? _lastResult;

  bool get _isAuthorized =>
      widget.profile.isAuthorized && widget.profile.role.isOperationsStaff;

  Future<void> _runSeedOperation({
    required String taskDescription,
    required Future<dynamic> Function() operation,
  }) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loadingTask = taskDescription;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await operation();
      if (!mounted) return;

      if (result is ReferenceDataSeedResult) {
        setState(() {
          _lastResult = result;
          _successMessage =
              'Seeding completed. ${result.totalCreated} created, '
              '${result.totalSkipped} already existed.';
        });
      } else if (result is EntitySeedSummary) {
        setState(() {
          _successMessage =
              '${result.entityName.toUpperCase()}: ${result.createdCount} created, '
              '${result.skippedCount} already existed.';
          // Merge or update the single entity in lastResult
          _updateSummary(result);
        });
      }
    } on ReferenceDataSeedFailure catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      const safeMsg =
          'An unexpected error occurred while seeding reference data.';
      setState(() => _errorMessage = safeMsg);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(safeMsg)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingTask = null;
        });
      }
    }
  }

  void _updateSummary(EntitySeedSummary summary) {
    final current =
        _lastResult ??
        const ReferenceDataSeedResult(
          properties: EntitySeedSummary(entityName: 'properties'),
          units: EntitySeedSummary(entityName: 'units'),
          tenants: EntitySeedSummary(entityName: 'tenants'),
        );

    setState(() {
      _lastResult = ReferenceDataSeedResult(
        properties: summary.entityName == 'properties'
            ? summary
            : current.properties,
        units: summary.entityName == 'units' ? summary : current.units,
        tenants: summary.entityName == 'tenants' ? summary : current.tenants,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reference Data Seeder'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isAuthorized
            ? _buildAuthorizedContent(palette)
            : _buildUnauthorizedContent(palette),
      ),
    );
  }

  Widget _buildUnauthorizedContent(AppPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 56, color: palette.muted),
              const SizedBox(height: 16),
              Text(
                'Access Restricted',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600, color: palette.ink),
              ),
              const SizedBox(height: 12),
              Text(
                'Only authorized internal operational staff (Property Operations '
                'or Complaint Operations) can seed demo and reference data.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorizedContent(AppPalette palette) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBanner(palette),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Seed Actions'),
          const SizedBox(height: 12),
          _buildActionButtons(),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            _buildErrorBanner(palette, _errorMessage!),
            const SizedBox(height: 24),
          ],
          if (_successMessage != null) ...[
            _buildSuccessBanner(palette, _successMessage!),
            const SizedBox(height: 24),
          ],
          if (_lastResult != null) ...[
            const SectionHeader(title: 'Execution Results'),
            const SizedBox(height: 12),
            _buildResultsOverview(palette, _lastResult!),
            const SizedBox(height: 16),
            _buildDetailedEntityReports(palette, _lastResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBanner(AppPalette palette) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: palette.accent, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deterministic Demo Reference Data',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Writes sample properties, units, and tenants to Cloud Firestore '
                  'using fixed fixture IDs. Existing records are safely skipped and '
                  'will never be overwritten. Timestamps use Firestore server timestamps.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _isLoading
              ? null
              : () => _runSeedOperation(
                  taskDescription: 'Seeding all reference data...',
                  operation: () =>
                      _seedService.seedAll(executor: widget.profile),
                ),
          icon: const Icon(Icons.dataset_outlined),
          label: Text(
            _isLoading && _loadingTask != null
                ? _loadingTask!
                : 'Seed All Reference Data',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _runSeedOperation(
                      taskDescription: 'Seeding properties...',
                      operation: () =>
                          _seedService.seedProperties(executor: widget.profile),
                    ),
              icon: const Icon(Icons.apartment_outlined),
              label: const Text('Seed Properties'),
            ),
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _runSeedOperation(
                      taskDescription: 'Seeding units...',
                      operation: () =>
                          _seedService.seedUnits(executor: widget.profile),
                    ),
              icon: const Icon(Icons.meeting_room_outlined),
              label: const Text('Seed Units'),
            ),
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _runSeedOperation(
                      taskDescription: 'Seeding tenants...',
                      operation: () =>
                          _seedService.seedTenants(executor: widget.profile),
                    ),
              icon: const Icon(Icons.people_outline),
              label: const Text('Seed Tenants'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner(AppPalette palette, String message) {
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.error_outline, color: palette.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: palette.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(AppPalette palette, String message) {
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: palette.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: palette.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsOverview(
    AppPalette palette,
    ReferenceDataSeedResult result,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final children = [
          StatTile(
            label: 'Total Created',
            value: '${result.totalCreated}',
            delta: result.totalCreated > 0 ? 'New documents added' : null,
          ),
          StatTile(
            label: 'Already Existed',
            value: '${result.totalSkipped}',
            delta: result.totalSkipped > 0
                ? 'Preserved without overwrite'
                : null,
          ),
          StatTile(
            label: 'Failures',
            value: '${result.totalFailed}',
            delta: result.totalFailed == 0 ? 'No write errors' : null,
          ),
        ];

        if (wide) {
          return Row(
            children: [
              for (final tile in children)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: tile,
                  ),
                ),
            ],
          );
        }

        return Column(
          children: [
            for (final tile in children) ...[tile, const SizedBox(height: 8)],
          ],
        );
      },
    );
  }

  Widget _buildDetailedEntityReports(
    AppPalette palette,
    ReferenceDataSeedResult result,
  ) {
    return Column(
      children: [
        _buildEntityCard(palette, result.properties, 'Properties'),
        const SizedBox(height: 12),
        _buildEntityCard(palette, result.units, 'Units'),
        const SizedBox(height: 12),
        _buildEntityCard(palette, result.tenants, 'Tenants'),
      ],
    );
  }

  Widget _buildEntityCard(
    AppPalette palette,
    EntitySeedSummary summary,
    String title,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600, color: palette.ink),
              ),
              Text(
                '${summary.createdCount} created · ${summary.skippedCount} skipped',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.muted),
              ),
            ],
          ),
          if (summary.createdIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final id in summary.createdIds)
                  Chip(
                    avatar: Icon(Icons.add, size: 14, color: palette.success),
                    label: Text(id, style: const TextStyle(fontSize: 12)),
                    backgroundColor: palette.raised,
                    side: BorderSide(
                      color: palette.success.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ],
          if (summary.skippedIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final id in summary.skippedIds)
                  Chip(
                    avatar: Icon(Icons.check, size: 14, color: palette.muted),
                    label: Text(
                      '$id (existed)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: palette.raised,
                    side: BorderSide(color: palette.border),
                  ),
              ],
            ),
          ],
          if (summary.failedIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final id in summary.failedIds)
                  Chip(
                    avatar: Icon(Icons.close, size: 14, color: palette.warning),
                    label: Text(
                      '$id (failed)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: palette.raised,
                    side: BorderSide(color: palette.warning),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

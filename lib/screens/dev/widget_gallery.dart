import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../widgets/app_card.dart';
import '../../widgets/audit_timeline.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/stat_tile.dart';

class WidgetGalleryScreen extends StatelessWidget {
  const WidgetGalleryScreen({super.key});

  static final DateTime _now = DateTime(2026, 10, 7, 14, 30);
  static final List<AuditEvent> _events = [
    AuditEvent(
      title: 'Complaint received',
      actor: 'Asha Rao',
      role: 'Tenant',
      timestamp: _now.subtract(const Duration(days: 2)),
      note: 'Water is leaking beneath the kitchen sink. The cabinet floor is damp, and the leak gets worse when the tap runs.',
      tone: AuditTone.accent,
    ),
    AuditEvent(
      title: 'Technician assigned',
      actor: 'Neel Shah',
      role: 'Coordinator',
      timestamp: _now.subtract(const Duration(days: 1, hours: 20)),
      tone: AuditTone.neutral,
    ),
    AuditEvent(
      title: 'Visit scheduled',
      actor: 'Maya Das',
      role: 'Technician',
      timestamp: _now.subtract(const Duration(days: 1, hours: 4)),
      note: 'Visit planned for the next available service window.',
      tone: AuditTone.warning,
    ),
    AuditEvent(
      title: 'Repair completed',
      actor: 'Maya Das',
      role: 'Technician',
      timestamp: _now.subtract(const Duration(hours: 3)),
      note: 'Replaced the worn connector and checked for leaks.',
      tone: AuditTone.success,
    ),
    AuditEvent(
      title: 'Tenant confirmed',
      actor: 'Asha Rao',
      role: 'Tenant',
      timestamp: _now,
      tone: AuditTone.success,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 3
        : width >= 700
        ? 2
        : 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Widget gallery')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'GrihSetu design system',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: palette.ink),
              ),
              const SizedBox(height: 8),
              Text(
                'Reusable building blocks, shown in light and dark themes.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 28),
              SectionHeader(
                title: 'Overview',
                trailing: TextButton(
                  onPressed: () {},
                  child: const Text('View all'),
                ),
              ),
              const SizedBox(height: 16),
              _ResponsiveGrid(
                columns: columns,
                children: const [
                  StatTile(
                    label: 'Open complaints',
                    value: '12',
                    delta: '3 resolved today',
                  ),
                  StatTile(
                    label: 'Average response',
                    value: '2.4h',
                    delta: '12% faster this week',
                  ),
                  AppCard(
                    onTap: null,
                    child: Text(
                      'A bordered card with a soft surface and a clear hover state.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const SectionHeader(title: 'Empty and error states'),
              const SizedBox(height: 16),
              _ResponsiveGrid(
                columns: columns > 2 ? 2 : columns,
                children: [
                  const AppCard(
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'All caught up',
                      message: 'New updates will appear here.',
                      actionLabel: 'Refresh',
                      onAction: _noop,
                    ),
                  ),
                  const AppCard(
                    child: ErrorState(
                      message: 'Your dashboard could not be refreshed.',
                      onRetry: _noop,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const SectionHeader(title: 'Loading placeholders'),
              const SizedBox(height: 16),
              _ResponsiveGrid(
                columns: columns,
                children: const [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 132),
                        SizedBox(height: 16),
                        SkeletonBox(width: double.infinity, height: 24),
                        SizedBox(height: 10),
                        SkeletonBox(width: 190),
                      ],
                    ),
                  ),
                  AppCard(child: SkeletonList(itemCount: 2)),
                ],
              ),
              const SizedBox(height: 28),
              const SectionHeader(title: 'Audit timeline · one event'),
              const SizedBox(height: 16),
              AppCard(child: AuditTimeline(events: [_events.last])),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Audit timeline · five events'),
              const SizedBox(height: 16),
              AppCard(child: AuditTimeline(events: _events)),
            ],
          ),
        ),
      ),
    );
  }
}

void _noop() {}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = columns.clamp(1, children.length);
      final itemWidth = (constraints.maxWidth - (count - 1) * 16) / count;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children)
            SizedBox(width: itemWidth, child: child),
        ],
      );
    },
  );
}

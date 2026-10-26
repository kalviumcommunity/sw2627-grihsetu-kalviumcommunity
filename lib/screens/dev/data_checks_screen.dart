import 'package:flutter/material.dart';

import '../../core/models/complaint.dart';
import '../../repositories/complaint_store.dart';
import '../../theme/app_palette.dart';
import '../../utils/consistency_rules.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_spacing.dart';
import '../complaints/complaint_detail_screen.dart';

/// Developer verification screen listing all data consistency violations.
///
/// Shows "All consistent" when zero invariant violations are detected across
/// the complaint store and audit logs.
class DataChecksScreen extends StatelessWidget {
  const DataChecksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final store = ComplaintStore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data checks'),
        actions: [
          IconButton(
            tooltip: 'Refresh checks',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Trigger reactive evaluation by re-notifying store
              (context as Element).markNeedsBuild();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: store.watchAll(),
        initialData: store.snapshot,
        builder: (context, snapshot) {
          final complaints = snapshot.data ?? store.snapshot;
          final events = store.allEvents;
          final violations = ConsistencyRules.validateAll(
            complaints,
            eventsByComplaintId: events,
          );

          if (violations.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: AppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: palette.success,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'All consistent',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: palette.ink,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '0 consistency violations across all ${complaints.length} complaints and audit trails.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: violations.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: palette.warning),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Found ${violations.length} consistency violations:',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: palette.ink,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                );
              }

              final v = violations[index - 1];
              return AppCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ComplaintDetailScreen(complaintId: v.complaintId),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accentSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            v.rule,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Complaint: ${v.complaintId}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: palette.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: palette.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      v.detail,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: palette.ink),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

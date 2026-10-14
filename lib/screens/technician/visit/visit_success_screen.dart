import 'package:flutter/material.dart';

import '../../../theme/app_palette.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_spacing.dart';

/// Screen displayed after a visit is successfully resolved or follow-up requested.
class VisitSuccessScreen extends StatelessWidget {
  const VisitSuccessScreen({
    super.key,
    required this.complaintId,
    required this.isResolved,
    required this.summaryTitle,
    required this.summaryDetails,
    required this.onSiteDuration,
    this.partsCount = 0,
  });

  final String complaintId;
  final bool isResolved;
  final String summaryTitle;
  final String summaryDetails;
  final Duration onSiteDuration;
  final int partsCount;

  static Future<void> open(
    BuildContext context, {
    required String complaintId,
    required bool isResolved,
    required String summaryTitle,
    required String summaryDetails,
    required Duration onSiteDuration,
    int partsCount = 0,
  }) {
    return Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VisitSuccessScreen(
          complaintId: complaintId,
          isResolved: isResolved,
          summaryTitle: summaryTitle,
          summaryDetails: summaryDetails,
          onSiteDuration: onSiteDuration,
          partsCount: partsCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final minutes = onSiteDuration.inMinutes;
    final hours = onSiteDuration.inHours;
    final durationFormatted = hours > 0
        ? '$hours hr ${minutes % 60} min'
        : '$minutes min';

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isResolved
                        ? palette.success.withValues(alpha: 0.15)
                        : palette.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isResolved ? Icons.check_circle : Icons.event_repeat,
                    size: 48,
                    color: isResolved ? palette.success : palette.accent,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                isResolved ? 'Visit Completed' : 'Follow-up Requested',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Complaint #$complaintId audit log has been updated.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.muted, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summaryTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      summaryDetails,
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Divider(color: palette.border, height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Time on site:',
                          style: TextStyle(color: palette.muted, fontSize: 13),
                        ),
                        Text(
                          durationFormatted,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: palette.ink,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (isResolved && partsCount > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Parts recorded:',
                            style: TextStyle(color: palette.muted, fontSize: 13),
                          ),
                          Text(
                            '$partsCount parts used',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: palette.ink,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 56, // 56px primary button
                child: FilledButton(
                  key: const Key('back_to_today_jobs_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    // Navigate back to the queue or root
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    "Back to today's jobs",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

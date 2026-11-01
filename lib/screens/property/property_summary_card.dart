import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../utils/property_metrics.dart';
import '../../utils/rent_rules.dart';
import '../../widgets/app_spacing.dart';

/// Compact operational summary card for a property.
///
/// Displays core health indicators, open complaints, SLA %, average response,
/// repeat visits, overdue rent, a health bar, and a CustomPainter sparkline.
class PropertySummaryCard extends StatelessWidget {
  const PropertySummaryCard({
    super.key,
    required this.summary,
    this.onTap,
    this.showSparkline = true,
  });

  final PropertySummary summary;
  final VoidCallback? onTap;
  final bool showSparkline;

  String _formatDuration(Duration? d) {
    if (d == null) return '--';
    final hours = d.inMinutes / 60.0;
    if (hours < 1.0) {
      return '${d.inMinutes}m';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    final health = summary.healthScore;
    final healthColor = health >= 0.8
        ? palette.success
        : (health >= 0.5 ? palette.warning : palette.danger);

    final slaDisplay = summary.slaPercent != null
        ? '${summary.slaPercent!.round()}%'
        : '--';

    return Semantics(
      label:
          'Property summary for ${summary.propertyName}. '
          '${summary.openComplaints} open complaints, '
          'SLA $slaDisplay, '
          '${summary.overdueRentCount} overdue rent records. Tap to view detailed summary.',
      button: true,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: Name & Health indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        summary.propertyName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: palette.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: healthColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: healthColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: healthColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            health >= 0.8
                                ? 'Healthy'
                                : (health >= 0.5 ? 'Attention' : 'Urgent'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: healthColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Health Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: health,
                    minHeight: 4,
                    backgroundColor: palette.raised,
                    valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Key metrics row
                Row(
                  children: [
                    _MetricItem(
                      label: 'Open',
                      value: '${summary.openComplaints}',
                      valueColor: summary.openComplaints > 0
                          ? palette.warning
                          : palette.ink,
                    ),
                    _MetricItem(
                      label: 'SLA',
                      value: slaDisplay,
                      valueColor:
                          summary.slaPercent != null &&
                              summary.slaPercent! >= 90.0
                          ? palette.success
                          : palette.ink,
                    ),
                    _MetricItem(
                      label: 'Avg Resp',
                      value: _formatDuration(summary.avgFirstResponse),
                    ),
                    _MetricItem(
                      label: 'Repeats',
                      value: '${summary.repeatVisits}',
                      valueColor: summary.repeatVisits > 0
                          ? palette.danger
                          : palette.ink,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Rent status & Sparkline row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        summary.overdueRentCount > 0
                            ? 'Overdue: ${summary.overdueRentCount} (${formatIndianCurrency(summary.overdueRentAmount)})'
                            : 'Rent: 100% on track',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: summary.overdueRentCount > 0
                              ? palette.danger
                              : palette.muted,
                          fontWeight: summary.overdueRentCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showSparkline && summary.trendBuckets.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      RepaintBoundary(
                        child: SizedBox(
                          width: 56,
                          height: 20,
                          child: CustomPaint(
                            painter: SparklinePainter(
                              points: summary.trendBuckets,
                              lineColor: palette.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.muted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? palette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter rendering a compact sparkline trend chart without external packages.
class SparklinePainter extends CustomPainter {
  const SparklinePainter({
    required this.points,
    required this.lineColor,
    this.strokeWidth = 2.0,
  });

  final List<int> points;
  final Color lineColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final minVal = points.reduce((a, b) => a < b ? a : b);
    final maxVal = points.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).toDouble();

    final stepX = points.length > 1 ? size.width / (points.length - 1) : 0.0;
    final path = Path();

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final normalizedY = range == 0 ? 0.5 : (points[i] - minVal) / range;
      // Invert Y coordinate so higher values render near the top
      final y =
          size.height -
          (normalizedY * (size.height - strokeWidth * 2)) -
          strokeWidth;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../widgets/app_spacing.dart';

/// Interactive dual-series trend line chart comparing created vs resolved issues.
class TrendLineChart extends StatefulWidget {
  const TrendLineChart({
    required this.createdPoints,
    required this.resolvedPoints,
    required this.labels,
    this.height = 180.0,
    this.createdLabel = 'Created',
    this.resolvedLabel = 'Resolved',
    this.createdColor,
    this.resolvedColor,
    super.key,
  });

  final List<int> createdPoints;
  final List<int> resolvedPoints;
  final List<String> labels;
  final double height;
  final String createdLabel;
  final String resolvedLabel;
  final Color? createdColor;
  final Color? resolvedColor;

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
    } else {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(Offset localPosition, double chartWidth, double chartLeft) {
    final count = math.max(
      widget.createdPoints.length,
      widget.resolvedPoints.length,
    );
    if (count == 0) return;
    if (count == 1) {
      setState(() => _hoveredIndex = 0);
      return;
    }
    final relativeX = localPosition.dx - chartLeft;
    final step = chartWidth / (count - 1);
    final index = (relativeX / step).round().clamp(0, count - 1);
    if (_hoveredIndex != index) {
      setState(() => _hoveredIndex = index);
    }
  }

  void _onExit() {
    if (_hoveredIndex != null) {
      setState(() => _hoveredIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final createdC = widget.createdColor ?? palette.accent;
    final resolvedC = widget.resolvedColor ?? palette.success;

    final totalCreated = widget.createdPoints.fold<int>(0, (s, e) => s + e);
    final totalResolved = widget.resolvedPoints.fold<int>(0, (s, e) => s + e);

    final semanticText =
        'Trend chart: $totalCreated created and $totalResolved resolved over '
        '${widget.labels.length} intervals.';

    return Semantics(
      label: semanticText,
      child: MouseRegion(
        onExit: (_) => _onExit(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            const leftPadding = 32.0;
            const rightPadding = 12.0;
            const bottomAxisHeight = 28.0;
            const legendHeight = 28.0;

            final chartWidth = math.max(
              40.0,
              availableWidth - leftPadding - rightPadding,
            );
            final chartHeight = math.max(
              40.0,
              widget.height - bottomAxisHeight - legendHeight,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Legend Row
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    _LegendBadge(color: createdC, label: widget.createdLabel),
                    _LegendBadge(color: resolvedC, label: widget.resolvedLabel),
                  ],
                ),
                const SizedBox(height: 6),

                // 2. Interactive Chart Canvas + Tooltip Stack
                GestureDetector(
                  onTapDown: (d) =>
                      _onHover(d.localPosition, chartWidth, leftPadding),
                  onPanUpdate: (d) =>
                      _onHover(d.localPosition, chartWidth, leftPadding),
                  onPanEnd: (_) => _onExit(),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size(
                                availableWidth,
                                chartHeight + bottomAxisHeight,
                              ),
                              painter: _TrendChartPainter(
                                created: widget.createdPoints,
                                resolved: widget.resolvedPoints,
                                labels: widget.labels,
                                progress: _animation.value,
                                createdColor: createdC,
                                resolvedColor: resolvedC,
                                gridColor: palette.shimmer,
                                textStyle:
                                    Theme.of(context).textTheme.labelSmall
                                        ?.copyWith(
                                          color: palette.muted,
                                          fontSize: 10,
                                        ) ??
                                    TextStyle(
                                      color: palette.muted,
                                      fontSize: 10,
                                    ),
                                leftPadding: leftPadding,
                                chartHeight: chartHeight,
                                bottomAxisHeight: bottomAxisHeight,
                                hoveredIndex: _hoveredIndex,
                              ),
                            );
                          },
                        ),
                      ),

                      // Tooltip
                      if (_hoveredIndex != null &&
                          _hoveredIndex! < widget.labels.length)
                        Positioned(
                          top: 0,
                          left: _calcTooltipLeft(chartWidth, leftPadding),
                          child: _ChartTooltip(
                            title: widget.labels[_hoveredIndex!],
                            createdCount:
                                _hoveredIndex! < widget.createdPoints.length
                                ? widget.createdPoints[_hoveredIndex!]
                                : 0,
                            resolvedCount:
                                _hoveredIndex! < widget.resolvedPoints.length
                                ? widget.resolvedPoints[_hoveredIndex!]
                                : 0,
                            createdColor: createdC,
                            resolvedColor: resolvedC,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _calcTooltipLeft(double chartWidth, double leftPadding) {
    final count = math.max(
      widget.createdPoints.length,
      widget.resolvedPoints.length,
    );
    if (count <= 1) return leftPadding + (chartWidth / 2) - 45;
    final step = chartWidth / (count - 1);
    final x = leftPadding + (_hoveredIndex! * step) - 45;
    return x.clamp(leftPadding, leftPadding + chartWidth - 90);
  }
}

class _LegendBadge extends StatelessWidget {
  const _LegendBadge({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.palette.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ChartTooltip extends StatelessWidget {
  const _ChartTooltip({
    required this.title,
    required this.createdCount,
    required this.resolvedCount,
    required this.createdColor,
    required this.resolvedColor,
  });

  final String title;
  final int createdCount;
  final int resolvedCount;
  final Color createdColor;
  final Color resolvedColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: palette.ink.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: palette.shimmer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: palette.ink),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, color: createdColor),
              const SizedBox(width: 4),
              Text(
                'Created: $createdCount',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.muted, fontSize: 10),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, color: resolvedColor),
              const SizedBox(width: 4),
              Text(
                'Resolved: $resolvedCount',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.muted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.created,
    required this.resolved,
    required this.labels,
    required this.progress,
    required this.createdColor,
    required this.resolvedColor,
    required this.gridColor,
    required this.textStyle,
    required this.leftPadding,
    required this.chartHeight,
    required this.bottomAxisHeight,
    required this.hoveredIndex,
  });

  final List<int> created;
  final List<int> resolved;
  final List<String> labels;
  final double progress;
  final Color createdColor;
  final Color resolvedColor;
  final Color gridColor;
  final TextStyle textStyle;
  final double leftPadding;
  final double chartHeight;
  final double bottomAxisHeight;
  final int? hoveredIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final chartWidth = size.width - leftPadding - 12.0;

    int maxVal = 1;
    for (final v in [...created, ...resolved]) {
      if (v > maxVal) maxVal = v;
    }
    // Round maxVal up to even step
    maxVal = ((maxVal + 2) ~/ 2) * 2;

    // 1. Draw horizontal grid lines and Y-axis labels
    const gridLines = 3;
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= gridLines; i++) {
      final y = chartHeight * (1.0 - (i / gridLines));
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      final valLabel = (maxVal * (i / gridLines)).round().toString();
      final textSpan = TextSpan(text: valLabel, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          leftPadding - textPainter.width - 6,
          y - (textPainter.height / 2),
        ),
      );
    }

    final pointCount = math.max(created.length, resolved.length);
    if (pointCount == 0) return;

    final stepX = pointCount > 1
        ? chartWidth / (pointCount - 1)
        : chartWidth / 2;

    // 2. Draw X-axis labels (render every 1 or 2 labels to avoid overlap at 1.3 textScale)
    final labelStride = pointCount > 4 ? 2 : 1;
    for (int i = 0; i < labels.length; i++) {
      if (i % labelStride != 0 && i != labels.length - 1) continue;
      final x = leftPadding + (i * stepX);
      final textSpan = TextSpan(text: labels[i], style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout(maxWidth: stepX * labelStride);

      final labelX = (x - (tp.width / 2)).clamp(
        leftPadding,
        size.width - tp.width,
      );
      tp.paint(canvas, Offset(labelX, chartHeight + 8));
    }

    // 3. Draw Series with animation clip
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(leftPadding, 0, chartWidth * progress, chartHeight),
    );

    _drawSeries(canvas, created, createdColor, stepX, maxVal);
    _drawSeries(canvas, resolved, resolvedColor, stepX, maxVal);

    canvas.restore();

    // 4. Hover vertical guide
    if (hoveredIndex != null && hoveredIndex! < pointCount) {
      final hx = leftPadding + (hoveredIndex! * stepX);
      final guidePaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(hx, 0), Offset(hx, chartHeight), guidePaint);
    }
  }

  void _drawSeries(
    Canvas canvas,
    List<int> points,
    Color color,
    double stepX,
    int maxVal,
  ) {
    if (points.isEmpty) return;

    final path = Path();
    final pointOffsets = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final x = leftPadding + (i * stepX);
      final normY = points[i] / maxVal;
      final y = chartHeight - (normY * chartHeight);
      pointOffsets.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final dotRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final pt in pointOffsets) {
      canvas.drawCircle(pt, 3.5, dotPaint);
      canvas.drawCircle(pt, 3.5, dotRingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.created != created ||
        oldDelegate.resolved != resolved;
  }
}

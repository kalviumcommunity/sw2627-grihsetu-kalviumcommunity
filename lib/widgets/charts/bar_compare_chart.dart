import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../widgets/app_spacing.dart';

/// Item data model for side-by-side bar comparison.
class BarCompareItem {
  const BarCompareItem({
    required this.label,
    required this.value1,
    required this.value2,
    this.value1Label = 'Series 1',
    this.value2Label = 'Series 2',
    this.value1Display,
    this.value2Display,
  });

  final String label;
  final double value1;
  final double value2;
  final String value1Label;
  final String value2Label;
  final String? value1Display;
  final String? value2Display;
}

/// Accessible side-by-side grouped bar comparison chart.
class BarCompareChart extends StatefulWidget {
  const BarCompareChart({
    required this.items,
    this.height = 180.0,
    this.series1Color,
    this.series2Color,
    this.series1Name = 'Series 1',
    this.series2Name = 'Series 2',
    super.key,
  });

  final List<BarCompareItem> items;
  final double height;
  final Color? series1Color;
  final Color? series2Color;
  final String series1Name;
  final String series2Name;

  @override
  State<BarCompareChart> createState() => _BarCompareChartState();
}

class _BarCompareChartState extends State<BarCompareChart>
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
    if (widget.items.isEmpty) return;
    final relX = localPosition.dx - chartLeft;
    final groupWidth = chartWidth / widget.items.length;
    final index = (relX / groupWidth).floor().clamp(0, widget.items.length - 1);
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
    final color1 = widget.series1Color ?? palette.accent;
    final color2 = widget.series2Color ?? palette.warning;

    final semanticText = widget.items.isEmpty
        ? 'No comparison data available'
        : 'Bar comparison across ${widget.items.length} properties: '
              '${widget.items.map((i) => '${i.label}: ${i.value1} vs ${i.value2}').join('; ')}';

    return Semantics(
      label: semanticText,
      child: MouseRegion(
        onExit: (_) => _onExit(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            const leftPadding = 32.0;
            const rightPadding = 12.0;
            const bottomAxisHeight = 32.0;
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
                // 1. Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _BarLegendBadge(color: color1, label: widget.series1Name),
                    const SizedBox(width: AppSpacing.md),
                    _BarLegendBadge(color: color2, label: widget.series2Name),
                  ],
                ),
                const SizedBox(height: 6),

                // 2. Chart Area
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
                              painter: _BarComparePainter(
                                items: widget.items,
                                progress: _animation.value,
                                color1: color1,
                                color2: color2,
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
                          _hoveredIndex! < widget.items.length)
                        Positioned(
                          top: 0,
                          left: _calcTooltipLeft(chartWidth, leftPadding),
                          child: _BarTooltip(
                            item: widget.items[_hoveredIndex!],
                            color1: color1,
                            color2: color2,
                            name1: widget.series1Name,
                            name2: widget.series2Name,
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
    if (widget.items.isEmpty) return leftPadding;
    final groupWidth = chartWidth / widget.items.length;
    final x =
        leftPadding + (_hoveredIndex! * groupWidth) + (groupWidth / 2) - 45;
    return x.clamp(leftPadding, leftPadding + chartWidth - 90);
  }
}

class _BarLegendBadge extends StatelessWidget {
  const _BarLegendBadge({required this.color, required this.label});

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
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
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

class _BarTooltip extends StatelessWidget {
  const _BarTooltip({
    required this.item,
    required this.color1,
    required this.color2,
    required this.name1,
    required this.name2,
  });

  final BarCompareItem item;
  final Color color1;
  final Color color2;
  final String name1;
  final String name2;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final display1 = item.value1Display ?? item.value1.toStringAsFixed(1);
    final display2 = item.value2Display ?? item.value2.toStringAsFixed(1);

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
            item.label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: palette.ink),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, color: color1),
              const SizedBox(width: 4),
              Text(
                '$name1: $display1',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.muted, fontSize: 10),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, color: color2),
              const SizedBox(width: 4),
              Text(
                '$name2: $display2',
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

class _BarComparePainter extends CustomPainter {
  _BarComparePainter({
    required this.items,
    required this.progress,
    required this.color1,
    required this.color2,
    required this.gridColor,
    required this.textStyle,
    required this.leftPadding,
    required this.chartHeight,
    required this.bottomAxisHeight,
    required this.hoveredIndex,
  });

  final List<BarCompareItem> items;
  final double progress;
  final Color color1;
  final Color color2;
  final Color gridColor;
  final TextStyle textStyle;
  final double leftPadding;
  final double chartHeight;
  final double bottomAxisHeight;
  final int? hoveredIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final chartWidth = size.width - leftPadding - 12.0;

    double maxVal = 1.0;
    for (final it in items) {
      if (it.value1 > maxVal) maxVal = it.value1;
      if (it.value2 > maxVal) maxVal = it.value2;
    }
    // Round maxVal up
    maxVal = (maxVal * 1.15).ceilToDouble();

    // 1. Grid lines and Y axis
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
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 6, y - (tp.height / 2)));
    }

    if (items.isEmpty) return;

    final groupWidth = chartWidth / items.length;
    final barWidth = math.min(18.0, (groupWidth - 12.0) / 2);

    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      final groupCenter = leftPadding + (i * groupWidth) + (groupWidth / 2);

      // Hover background
      if (hoveredIndex == i) {
        final hoverPaint = Paint()
          ..color = gridColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(
            leftPadding + (i * groupWidth),
            0,
            groupWidth,
            chartHeight,
          ),
          hoverPaint,
        );
      }

      // Bar 1
      final h1 = (it.value1 / maxVal) * chartHeight * progress;
      final x1 = groupCenter - barWidth - 1.5;
      final y1 = chartHeight - h1;
      final rrect1 = RRect.fromRectAndCorners(
        Rect.fromLTWH(x1, y1, barWidth, h1),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      final paint1 = Paint()..color = color1;
      canvas.drawRRect(rrect1, paint1);

      // Bar 2
      final h2 = (it.value2 / maxVal) * chartHeight * progress;
      final x2 = groupCenter + 1.5;
      final y2 = chartHeight - h2;
      final rrect2 = RRect.fromRectAndCorners(
        Rect.fromLTWH(x2, y2, barWidth, h2),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      final paint2 = Paint()..color = color2;
      canvas.drawRRect(rrect2, paint2);

      // X-Axis Label
      final tp = TextPainter(
        text: TextSpan(text: it.label, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '..',
      )..layout(maxWidth: groupWidth - 4);

      final labelX = (groupCenter - (tp.width / 2)).clamp(
        leftPadding,
        size.width - tp.width,
      );
      tp.paint(canvas, Offset(labelX, chartHeight + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _BarComparePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.items != items;
  }
}

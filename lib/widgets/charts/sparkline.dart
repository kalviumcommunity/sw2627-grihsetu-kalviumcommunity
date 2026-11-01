import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

/// Accessible Sparkline chart drawn entirely with [CustomPainter].
class Sparkline extends StatefulWidget {
  const Sparkline({
    required this.data,
    this.height = 40.0,
    this.width,
    this.color,
    this.fillColor,
    this.strokeWidth = 2.0,
    this.semanticLabel,
    super.key,
  });

  final List<num> data;
  final double height;
  final double? width;
  final Color? color;
  final Color? fillColor;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  State<Sparkline> createState() => _SparklineState();
}

class _SparklineState extends State<Sparkline>
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

  void _onHover(Offset localPosition, double width) {
    if (widget.data.isEmpty) return;
    if (widget.data.length == 1) {
      setState(() => _hoveredIndex = 0);
      return;
    }
    final step = width / (widget.data.length - 1);
    final index = (localPosition.dx / step).round().clamp(
      0,
      widget.data.length - 1,
    );
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
    final strokeColor = widget.color ?? palette.accent;
    final areaColor = widget.fillColor ?? strokeColor.withValues(alpha: 0.12);

    final semanticText =
        widget.semanticLabel ??
        (widget.data.isEmpty
            ? 'Empty trend data'
            : 'Trend with values: ${widget.data.join(', ')}');

    return Semantics(
      label: semanticText,
      child: MouseRegion(
        onExit: (_) => _onExit(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = widget.width ?? constraints.maxWidth;
            final effectiveW = w.isFinite ? w : 120.0;

            return GestureDetector(
              onTapDown: (details) =>
                  _onHover(details.localPosition, effectiveW),
              onPanUpdate: (details) =>
                  _onHover(details.localPosition, effectiveW),
              onPanEnd: (_) => _onExit(),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: Size(effectiveW, widget.height),
                        painter: _SparklinePainter(
                          data: widget.data.map((n) => n.toDouble()).toList(),
                          progress: _animation.value,
                          strokeColor: strokeColor,
                          fillColor: areaColor,
                          strokeWidth: widget.strokeWidth,
                          hoveredIndex: _hoveredIndex,
                        ),
                      ),
                      if (_hoveredIndex != null &&
                          _hoveredIndex! < widget.data.length)
                        Positioned(
                          top: -24,
                          left: _calcTooltipLeft(effectiveW),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: palette.raised,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: palette.shimmer),
                            ),
                            child: Text(
                              '${widget.data[_hoveredIndex!]}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: palette.ink,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  double _calcTooltipLeft(double width) {
    if (widget.data.length <= 1) return (width / 2) - 14;
    final step = width / (widget.data.length - 1);
    final x = (_hoveredIndex! * step) - 14;
    return x.clamp(0.0, math.max(0.0, width - 30));
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.data,
    required this.progress,
    required this.strokeColor,
    required this.fillColor,
    required this.strokeWidth,
    required this.hoveredIndex,
  });

  final List<double> data;
  final double progress;
  final Color strokeColor;
  final Color fillColor;
  final double strokeWidth;
  final int? hoveredIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      final basePaint = Paint()
        ..color = strokeColor.withValues(alpha: 0.3)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        basePaint,
      );
      return;
    }

    if (data.length == 1) {
      final dotPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        strokeWidth * 2,
        dotPaint,
      );
      return;
    }

    double minVal = data.reduce(math.min);
    double maxVal = data.reduce(math.max);
    if (minVal == maxVal) {
      minVal -= 1;
      maxVal += 1;
    }
    final range = maxVal - minVal;

    final points = <Offset>[];
    final stepX = size.width / (data.length - 1);
    const paddingY = 4.0;
    final usableHeight = size.height - (paddingY * 2);

    for (int i = 0; i < data.length; i++) {
      final normalizedY = (data[i] - minVal) / range;
      final y = size.height - paddingY - (normalizedY * usableHeight);
      points.add(Offset(i * stepX, y));
    }

    // Clip according to animation progress
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    // Area path
    final areaPath = Path()..moveTo(points.first.dx, size.height);
    for (final pt in points) {
      areaPath.lineTo(pt.dx, pt.dy);
    }
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.close();

    final areaPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, areaPaint);

    // Line path
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    canvas.restore();

    // Hover indicator
    if (hoveredIndex != null && hoveredIndex! < points.length) {
      final pt = points[hoveredIndex!];
      final highlightPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.fill;
      final outerRingPaint = Paint()
        ..color = strokeColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(pt, 5.0, highlightPaint);
      canvas.drawCircle(pt, 8.0, outerRingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.data != data;
  }
}

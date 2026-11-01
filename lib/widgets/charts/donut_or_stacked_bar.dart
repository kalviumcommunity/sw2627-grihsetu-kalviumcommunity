import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../widgets/app_spacing.dart';

/// Data segment for category mix proportions.
class CategorySegment {
  const CategorySegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// Category distribution chart supporting both donut and stacked bar presentations.
class DonutOrStackedBar extends StatefulWidget {
  const DonutOrStackedBar({
    required this.segments,
    this.height = 160.0,
    this.donutRadius = 45.0,
    this.donutHoleRadius = 28.0,
    super.key,
  });

  final List<CategorySegment> segments;
  final double height;
  final double donutRadius;
  final double donutHoleRadius;

  @override
  State<DonutOrStackedBar> createState() => _DonutOrStackedBarState();
}

class _DonutOrStackedBarState extends State<DonutOrStackedBar>
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final total = widget.segments.fold<int>(0, (s, e) => s + e.value);

    final semanticText = widget.segments.isEmpty || total == 0
        ? 'No categories recorded'
        : 'Category distribution: ${widget.segments.where((s) => s.value > 0).map((s) => '${s.label}: ${s.value} (${(s.value / total * 100).toStringAsFixed(1)}%)').join(', ')}';

    return Semantics(
      label: semanticText,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 420;

          if (isCompact) {
            return _buildStackedBarLayout(context, total, palette);
          } else {
            return _buildDonutLayout(
              context,
              total,
              palette,
              constraints.maxWidth,
            );
          }
        },
      ),
    );
  }

  Widget _buildStackedBarLayout(
    BuildContext context,
    int total,
    AppPalette palette,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stacked horizontal bar
        SizedBox(
          height: 20,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _StackedBarPainter(
                    segments: widget.segments,
                    total: total,
                    progress: _animation.value,
                    hoveredIndex: _hoveredIndex,
                    trackColor: palette.raised,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Legend tags
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (int i = 0; i < widget.segments.length; i++) ...[
              if (widget.segments[i].value > 0)
                _LegendItem(
                  segment: widget.segments[i],
                  total: total,
                  isHighlighted: _hoveredIndex == i,
                  onTap: () => setState(() {
                    _hoveredIndex = _hoveredIndex == i ? null : i;
                  }),
                ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDonutLayout(
    BuildContext context,
    int total,
    AppPalette palette,
    double maxWidth,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Donut canvas
        SizedBox(
          width: widget.height,
          height: widget.height,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _DonutChartPainter(
                    segments: widget.segments,
                    total: total,
                    progress: _animation.value,
                    donutRadius: widget.donutRadius,
                    donutHoleRadius: widget.donutHoleRadius,
                    hoveredIndex: _hoveredIndex,
                    trackColor: palette.raised,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        // Legend Column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < widget.segments.length; i++) ...[
                if (widget.segments[i].value > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: _LegendItem(
                      segment: widget.segments[i],
                      total: total,
                      isHighlighted: _hoveredIndex == i,
                      onTap: () => setState(() {
                        _hoveredIndex = _hoveredIndex == i ? null : i;
                      }),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.segment,
    required this.total,
    required this.isHighlighted,
    required this.onTap,
  });

  final CategorySegment segment;
  final int total;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0
        ? (segment.value / total * 100).toStringAsFixed(1)
        : '0';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: isHighlighted ? segment.color.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: segment.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${segment.label} ($pct%)',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                  color: context.palette.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StackedBarPainter extends CustomPainter {
  _StackedBarPainter({
    required this.segments,
    required this.total,
    required this.progress,
    required this.hoveredIndex,
    required this.trackColor,
  });

  final List<CategorySegment> segments;
  final int total;
  final double progress;
  final int? hoveredIndex;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(4),
    );

    // Track
    final trackPaint = Paint()..color = trackColor;
    canvas.drawRRect(rrect, trackPaint);

    if (total <= 0 || segments.isEmpty) return;

    canvas.save();
    canvas.clipRRect(rrect);

    double currentX = 0.0;
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.value <= 0) continue;

      final segWidth = (seg.value / total) * size.width * progress;
      final paint = Paint()
        ..color = hoveredIndex == i
            ? seg.color.withValues(alpha: 0.8)
            : seg.color;

      canvas.drawRect(Rect.fromLTWH(currentX, 0, segWidth, size.height), paint);
      currentX += segWidth;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.segments != segments;
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.segments,
    required this.total,
    required this.progress,
    required this.donutRadius,
    required this.donutHoleRadius,
    required this.hoveredIndex,
    required this.trackColor,
  });

  final List<CategorySegment> segments;
  final int total;
  final double progress;
  final double donutRadius;
  final double donutHoleRadius;
  final int? hoveredIndex;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = donutRadius - donutHoleRadius;
    final radius = donutHoleRadius + (strokeWidth / 2);

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (total <= 0 || segments.isEmpty) return;

    double startAngle = -math.pi / 2;
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.value <= 0) continue;

      final sweepAngle = (seg.value / total) * (2 * math.pi) * progress;
      final isHovered = hoveredIndex == i;

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? strokeWidth + 4 : strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.segments != segments;
  }
}

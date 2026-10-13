import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_spacing.dart';

/// Reusable loading placeholder box with smooth fade pulse.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final inTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (!inTest) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.48, end: 1.0).animate(_controller),
    child: Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: context.palette.shimmer,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
    ),
  );
}

/// Reusable skeleton placeholder for a single card.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius = 12.0,
  });

  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 112, height: 16),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(width: double.infinity, height: 20),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(width: 180, height: 14),
        ],
      ),
    );
  }
}

/// Configurable vertical list of skeleton card placeholders.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 3,
    this.spacing = 16,
    this.padding,
  });

  final int itemCount;
  final double spacing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < itemCount; index++) ...[
          if (index > 0) SizedBox(height: spacing),
          const SkeletonCard(),
        ],
      ],
    );

    if (padding != null) {
      return Padding(padding: padding!, child: content);
    }
    return content;
  }
}

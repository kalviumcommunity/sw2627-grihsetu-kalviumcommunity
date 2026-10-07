import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

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

class _SkeletonBoxState extends State<SkeletonBox> {
  Timer? _timer;
  bool _dimmed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (mounted) setState(() => _dimmed = !_dimmed);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _dimmed ? 0.48 : 1,
    duration: const Duration(milliseconds: 700),
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

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 3, this.spacing = 16});

  final int itemCount;
  final double spacing;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < itemCount; index++) ...[
        if (index > 0) SizedBox(height: spacing),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.palette.surface,
            border: Border.all(color: context.palette.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 112),
              SizedBox(height: 12),
              SkeletonBox(width: double.infinity, height: 20),
              SizedBox(height: 8),
              SkeletonBox(width: 180),
            ],
          ),
        ),
      ],
    ],
  );
}

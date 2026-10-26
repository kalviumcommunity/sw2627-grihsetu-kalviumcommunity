import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_spacing.dart';

/// Responsive grid layout helper for GrihSetu dashboards.
///
/// Follows standard responsive breakpoints:
/// - < 600 px: 1 column (mobile)
/// - 600 to 1100 px: 2 columns (tablet/narrow desktop)
/// - > 1100 px: 3 columns (wide desktop)
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this.children,
    this.spacing = AppSpacing.md,
    this.runSpacing = AppSpacing.md,
    this.mobileBreakpoint = 600,
    this.tabletBreakpoint = 1100,
    this.maxColumns = 3,
    super.key,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double mobileBreakpoint;
  final double tabletBreakpoint;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int columns = width < mobileBreakpoint
            ? 1
            : (width < tabletBreakpoint ? 2.clamp(1, maxColumns) : maxColumns);

        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: runSpacing),
                children[i],
              ],
            ],
          );
        }

        final double itemWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

/// Max-width centered container for responsive dashboards.
class ResponsiveDashboardContainer extends StatelessWidget {
  const ResponsiveDashboardContainer({
    required this.child,
    this.maxWidth = 1200.0,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Sized placeholder skeleton matching dashboard card geometry to prevent layout jumps.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({
    this.height = 120.0,
    this.width,
    this.borderRadius = 12.0,
    super.key,
  });

  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: palette.shimmer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

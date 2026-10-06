import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../theme/app_colors.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: t.displayLarge?.copyWith(fontSize: 28)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Coming soon',
                style: t.bodySmall?.copyWith(color: context.palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

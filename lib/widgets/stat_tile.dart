import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_card.dart';

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
  });

  final String label;
  final String value;
  final String? delta;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: palette.ink, fontWeight: FontWeight.w700),
          ),
          if (delta != null) ...[
            const SizedBox(height: 8),
            Text(
              delta!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.success),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_card.dart';
import 'app_spacing.dart';

/// Reusable statistic and Key Performance Indicator (KPI) card.
///
/// Wraps [AppCard] to display a primary [value], descriptive [label] (or [title]),
/// optional [icon], trend/delta indicator [delta], and optional [onTap] action.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    String? label,
    String? title,
    required this.value,
    this.delta,
    this.icon,
    this.onTap,
    this.semanticLabel,
  }) : label = label ?? title ?? '',
       assert(
         label != null || title != null,
         'Either label or title must be provided',
       );

  final String label;

  /// Alias for [label] to satisfy KPI card conventions.
  String get title => label;

  final String value;
  final String? delta;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    final resolvedSemanticLabel =
        semanticLabel ??
        (delta != null ? '$label, $value, $delta' : '$label, $value');

    return Semantics(
      label: resolvedSemanticLabel,
      button: onTap != null,
      enabled: onTap != null,
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(icon, size: 20, color: palette.accent),
                ],
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (delta != null) ...[
              const SizedBox(height: 8),
              Text(
                delta!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.success,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

enum StatusBadgeTone { neutral, accent, success, warning, danger }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusBadgeTone.neutral,
    this.icon,
  });

  final String label;
  final StatusBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (foreground, background) = switch (tone) {
      StatusBadgeTone.neutral => (palette.muted, palette.primarySoft),
      StatusBadgeTone.accent => (palette.primary, palette.primarySoft),
      StatusBadgeTone.success => (
        palette.success,
        palette.success.withValues(alpha: .12),
      ),
      StatusBadgeTone.warning => (palette.accent, palette.accentSoft),
      StatusBadgeTone.danger => (
        palette.danger,
        palette.danger.withValues(alpha: .12),
      ),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

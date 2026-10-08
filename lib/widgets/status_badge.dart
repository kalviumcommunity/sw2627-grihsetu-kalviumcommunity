import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

enum StatusBadgeTone { neutral, accent, success, warning, danger }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusBadgeTone.neutral,
  });

  final String label;
  final StatusBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (foreground, background) = switch (tone) {
      StatusBadgeTone.neutral => (palette.ink, palette.shimmer),
      StatusBadgeTone.accent => (palette.accent, palette.accentSoft),
      StatusBadgeTone.success => (palette.success, palette.surface),
      StatusBadgeTone.warning => (palette.warning, palette.surface),
      StatusBadgeTone.danger => (palette.danger, palette.surface),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: foreground.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

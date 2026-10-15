import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_spacing.dart';

/// A compact pill badge with a colored dot indicating repeat visits or recurring issues.
///
/// Uses warm cream/teal/amber/terracotta palette derived solely from [context.palette]:
/// - Amber ([AppPalette.warning]) for level 2 ("Visit 2", "Repeat x2").
/// - Terracotta ([AppPalette.accent]) for level 3 or more ("Repeat x3", "Visit 3").
class RepeatIndicator extends StatelessWidget {
  const RepeatIndicator({
    super.key,
    this.count = 2,
    this.label,
    this.tooltip,
    this.semanticLabel,
  });

  const RepeatIndicator.visit(
    int visitNumber, {
    super.key,
    this.tooltip,
    this.semanticLabel,
  }) : count = visitNumber,
       label = 'Visit $visitNumber';

  const RepeatIndicator.repeat(
    int repeatCount, {
    super.key,
    this.tooltip,
    this.semanticLabel,
  }) : count = repeatCount,
       label = 'Repeat x$repeatCount';

  const RepeatIndicator.recurring({
    super.key,
    this.count = 2,
    this.tooltip,
    this.semanticLabel,
  }) : label = 'Recurring issue';

  final int count;
  final String? label;
  final String? tooltip;
  final String? semanticLabel;

  bool get isTerracotta => count >= 3;

  String get _resolvedLabel {
    if (label != null && label!.trim().isNotEmpty) return label!.trim();
    if (count <= 2) return 'Visit $count';
    return 'Repeat x$count';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = isTerracotta ? palette.accent : palette.warning;
    final text = _resolvedLabel;
    final tooltipMessage = tooltip ?? text;
    final semanticsMessage = semanticLabel ?? tooltipMessage;

    return Semantics(
      label: semanticsMessage,
      container: true,
      child: Tooltip(
        message: tooltipMessage,
        child: Container(
          constraints: const BoxConstraints(minHeight: 28, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: color.withValues(alpha: 0.42)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: AppSpacing.xs + 1),
              Flexible(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

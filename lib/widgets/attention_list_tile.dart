import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_card.dart';
import 'app_spacing.dart';
import 'status_badge.dart';

/// A reusable, presentation-focused attention list item for operational dashboards and queues.
///
/// Accepts prepared display data rather than fetching its own records.
class AttentionListTile extends StatelessWidget {
  const AttentionListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leading,
    this.status,
    this.statusLabel,
    this.statusTone,
    this.isUrgent = false,
    this.trailingText,
    this.trailingIcon,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  /// Primary title or main label of the attention item.
  final String title;

  /// Supporting description, contextual details, or subtitle.
  final String? subtitle;

  /// Optional leading icon. Rendered in a themed circle if provided.
  final IconData? leadingIcon;

  /// Optional custom leading widget. Overrides [leadingIcon] if supplied.
  final Widget? leading;

  /// Optional custom status widget. Overrides [statusLabel] if supplied.
  final Widget? status;

  /// Optional status or urgency text label.
  final String? statusLabel;

  /// Tone for the generated [StatusBadge] when [statusLabel] is provided.
  final StatusBadgeTone? statusTone;

  /// Whether the item represents an urgent or overdue state.
  final bool isUrgent;

  /// Optional trailing text (e.g. date, time, or metric).
  final String? trailingText;

  /// Optional trailing icon (e.g. [Icons.chevron_right]).
  final IconData? trailingIcon;

  /// Optional custom trailing widget. Overrides [trailingText] and [trailingIcon] if supplied.
  final Widget? trailing;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Optional accessibility label for screen readers.
  final String? semanticLabel;

  /// Inner padding of the card.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    final resolvedLeading =
        leading ??
        (leadingIcon != null
            ? Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isUrgent
                      ? palette.danger.withValues(alpha: 0.12)
                      : palette.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  leadingIcon,
                  size: 20,
                  color: isUrgent ? palette.danger : palette.accent,
                ),
              )
            : null);

    final resolvedStatus =
        status ??
        (statusLabel != null && statusLabel!.trim().isNotEmpty
            ? StatusBadge(
                label: statusLabel!.trim(),
                tone:
                    statusTone ??
                    (isUrgent
                        ? StatusBadgeTone.danger
                        : StatusBadgeTone.warning),
              )
            : null);

    final resolvedTrailing =
        trailing ??
        (resolvedStatus != null || trailingText != null || trailingIcon != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?resolvedStatus,
                  if (trailingText != null &&
                      trailingText!.trim().isNotEmpty) ...[
                    if (resolvedStatus != null)
                      const SizedBox(height: AppSpacing.xs),
                    Text(
                      trailingText!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isUrgent ? palette.danger : palette.muted,
                        fontWeight: isUrgent
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                  if (trailingIcon != null) ...[
                    if (resolvedStatus != null || trailingText != null)
                      const SizedBox(height: AppSpacing.xs),
                    Icon(trailingIcon, size: 16, color: palette.muted),
                  ],
                ],
              )
            : null);

    final resolvedSemanticLabel =
        semanticLabel ??
        '$title${subtitle != null && subtitle!.isNotEmpty ? ', $subtitle' : ''}${statusLabel != null && statusLabel!.isNotEmpty ? ', $statusLabel' : ''}';

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: resolvedSemanticLabel,
      child: AppCard(
        onTap: onTap,
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (resolvedLeading != null) ...[
              resolvedLeading,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (resolvedTrailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              resolvedTrailing,
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_spacing.dart';

/// A reusable labeled switch widget with title, optional description, and help/error text.
///
/// Features:
/// - Required [title] string
/// - Optional [subtitle] supporting description
/// - Controlled [value] and [onChanged] callback
/// - Enabled/disabled interactive states
/// - Help and error text support
/// - Preserves accessibility semantics and standard 48px tap targets
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.helperText,
    this.errorText,
    this.contentPadding = EdgeInsets.zero,
    this.switchKey,
  });

  /// The primary title describing the toggle action.
  final String title;

  /// Optional secondary description explaining the effect of the switch.
  final String? subtitle;

  /// Whether this switch is checked.
  final bool value;

  /// Called when the user toggles the switch.
  final ValueChanged<bool>? onChanged;

  /// Whether the switch and its tile are interactive.
  final bool enabled;

  /// Optional helper text displayed beneath the switch tile.
  final String? helperText;

  /// Optional error text displayed beneath the switch tile.
  final String? errorText;

  /// Padding around the switch tile content. Defaults to [EdgeInsets.zero].
  final EdgeInsetsGeometry contentPadding;

  /// Optional key targeting the underlying [SwitchListTile].
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: enabled ? palette.ink : palette.muted,
    );

    final subtitleStyle = TextStyle(
      fontSize: 12,
      color: enabled ? palette.muted : palette.border,
    );

    final tile = SwitchListTile(
      key: switchKey,
      contentPadding: contentPadding,
      title: Text(title, style: titleStyle),
      subtitle: subtitle != null ? Text(subtitle!, style: subtitleStyle) : null,
      value: value,
      onChanged: enabled ? onChanged : null,
    );

    if (errorText == null && helperText == null) {
      return tile;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              errorText!,
              style: TextStyle(fontSize: 12, color: palette.danger),
            ),
          )
        else if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              helperText!,
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
          ),
      ],
    );
  }
}

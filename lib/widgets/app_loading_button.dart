import 'package:flutter/material.dart';

/// A reusable loading button that prevents duplicate taps and communicates submission progress.
///
/// Features:
/// - Required [label]
/// - Controlled [isLoading] state
/// - Displays a compact progress indicator matching icon size to prevent layout shifts
/// - Disables user interaction immediately when [isLoading] is true or [onPressed] is null
/// - Meets accessibility guidelines with at least 48px tap target
/// - Optional [loadingLabel] and [icon]
class AppLoadingButton extends StatelessWidget {
  const AppLoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.loadingLabel,
    this.icon,
    this.style,
    this.isFullWidth = false,
    this.height,
    this.progressIndicatorColor,
  });

  /// The primary label displayed on the button.
  final String label;

  /// The callback invoked when tapped. When null or when [isLoading] is true, interaction is disabled.
  final VoidCallback? onPressed;

  /// Whether the button is currently in a loading / submitting state.
  final bool isLoading;

  /// Optional label displayed while [isLoading] is true. Defaults to [label].
  final String? loadingLabel;

  /// Optional icon displayed when not loading.
  final Widget? icon;

  /// Optional custom button style.
  final ButtonStyle? style;

  /// Whether the button should stretch to full width.
  final bool isFullWidth;

  /// Optional custom height. Defaults to theme standard (min 48px).
  final double? height;

  /// Optional explicit color for the progress indicator.
  final Color? progressIndicatorColor;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = (isLoading || onPressed == null)
        ? null
        : onPressed;
    final displayLabel = isLoading ? (loadingLabel ?? label) : label;

    final resolvedIndicatorColor =
        progressIndicatorColor ??
        style?.foregroundColor?.resolve({WidgetState.disabled}) ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.black87
            : Colors.white);

    // Sized progress indicator matching standard icon dimensions to prevent layout shifts.
    final spinner = SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(resolvedIndicatorColor),
      ),
    );

    final Widget? effectiveIcon = isLoading ? spinner : icon;

    ButtonStyle effectiveStyle = style ?? const ButtonStyle();
    if (isFullWidth || height != null) {
      effectiveStyle = effectiveStyle.copyWith(
        minimumSize: WidgetStatePropertyAll(
          Size(isFullWidth ? double.infinity : 48, height ?? 48),
        ),
      );
    }

    final Widget button;
    if (effectiveIcon != null) {
      button = FilledButton.icon(
        onPressed: effectiveOnPressed,
        style: effectiveStyle,
        icon: effectiveIcon,
        label: Text(displayLabel),
      );
    } else {
      button = FilledButton(
        onPressed: effectiveOnPressed,
        style: effectiveStyle,
        child: Text(displayLabel),
      );
    }

    return isFullWidth
        ? SizedBox(width: double.infinity, height: height, child: button)
        : button;
  }
}

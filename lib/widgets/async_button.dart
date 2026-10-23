import 'dart:async';

import 'package:flutter/material.dart';

import '../services/errors/firebase_error_mapper.dart';
import '../theme/app_palette.dart';
import 'app_snack.dart';

/// Button that executes an asynchronous operation, preventing double-taps,
/// showing a progress indicator while in flight, and surfacing mapped errors.
class AsyncButton extends StatefulWidget {
  const AsyncButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.style,
    this.isOutlined = false,
    this.showErrorSnack = true,
    this.semanticLabel,
  });

  final FutureOr<void> Function()? onPressed;
  final Widget child;
  final Widget? icon;
  final ButtonStyle? style;
  final bool isOutlined;
  final bool showErrorSnack;
  final String? semanticLabel;

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading || widget.onPressed == null) return;

    setState(() => _isLoading = true);

    try {
      await widget.onPressed!();
    } catch (error, stackTrace) {
      if (mounted && widget.showErrorSnack) {
        final failure = FirebaseErrorMapper.map(error, stackTrace);
        AppSnack.error(context, failure);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final defaultStyle = (widget.style ?? const ButtonStyle()).copyWith(
      minimumSize: WidgetStateProperty.all(const Size(88, 48)),
    );

    final spinner = SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          widget.isOutlined ? palette.accent : palette.surface,
        ),
      ),
    );

    final content = _isLoading
        ? spinner
        : (widget.icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.icon!,
                    const SizedBox(width: 8),
                    widget.child,
                  ],
                )
              : widget.child);

    final button = widget.isOutlined
        ? OutlinedButton(
            onPressed: widget.onPressed == null || _isLoading
                ? null
                : _handlePress,
            style: defaultStyle,
            child: content,
          )
        : FilledButton(
            onPressed: widget.onPressed == null || _isLoading
                ? null
                : _handlePress,
            style: defaultStyle,
            child: content,
          );

    return Semantics(
      button: true,
      enabled: widget.onPressed != null && !_isLoading,
      label: widget.semanticLabel ?? (_isLoading ? 'Loading' : null),
      child: button,
    );
  }
}

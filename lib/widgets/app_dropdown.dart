import 'package:flutter/material.dart';

/// A reusable form-aware generic dropdown widget for enum- and string-backed fields.
///
/// Features:
/// - Generic typed values and dropdown items [T]
/// - Nullable values supported
/// - Built-in expansion layout preventing long labels from overflowing
/// - Integrates with [Form] and [FormFieldValidator]
/// - Supports visible label, hint text/widget, helper text, and error text
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    this.value,
    this.initialValue,
    required this.items,
    this.onChanged,
    this.label,
    this.hintText,
    this.hint,
    this.helperText,
    this.errorText,
    this.validator,
    this.enabled = true,
    this.isExpanded = true,
    this.decoration,
    this.autovalidateMode,
    this.focusNode,
    this.onSaved,
    this.prefixIcon,
  });

  /// Currently selected value (controlled).
  final T? value;

  /// Initial value for the form field.
  final T? initialValue;

  /// The list of items the user can select.
  final List<DropdownMenuItem<T>> items;

  /// Called when the user selects an item. When null or disabled, the dropdown is inactive.
  final ValueChanged<T?>? onChanged;

  /// Visible label for the dropdown field.
  final String? label;

  /// Optional hint text when no item is selected.
  final String? hintText;

  /// Optional custom hint widget. Takes precedence over [hintText].
  final Widget? hint;

  /// Optional helper text displayed below the dropdown.
  final String? helperText;

  /// Explicit validation error text.
  final String? errorText;

  /// An optional form validator.
  final FormFieldValidator<T>? validator;

  /// Whether the dropdown is enabled.
  final bool enabled;

  /// Whether the dropdown should expand to fill the available width. Defaults to true.
  final bool isExpanded;

  /// Optional base input decoration to merge with.
  final InputDecoration? decoration;

  /// Auto-validation mode.
  final AutovalidateMode? autovalidateMode;

  /// Focus node for keyboard navigation.
  final FocusNode? focusNode;

  /// Called when the form is saved.
  final FormFieldSetter<T>? onSaved;

  /// Optional prefix icon.
  final Widget? prefixIcon;

  /// Convenient helper to create a [DropdownMenuItem] with ellipsis overflow protection.
  static DropdownMenuItem<T> item<T>({
    required T value,
    required String label,
    Key? key,
  }) {
    return DropdownMenuItem<T>(
      key: key,
      value: value,
      child: Text(label, overflow: TextOverflow.ellipsis),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseDecoration = decoration ?? const InputDecoration();
    final effectiveDecoration = baseDecoration.copyWith(
      labelText: label ?? baseDecoration.labelText,
      helperText: helperText ?? baseDecoration.helperText,
      errorText: errorText ?? baseDecoration.errorText,
      prefixIcon: prefixIcon ?? baseDecoration.prefixIcon,
      enabled: enabled,
    );

    final effectiveHint = hint ?? (hintText != null ? Text(hintText!) : null);

    return DropdownButtonFormField<T>(
      initialValue: value ?? initialValue,
      items: items,
      onChanged: enabled ? onChanged : null,
      decoration: effectiveDecoration,
      hint: effectiveHint,
      validator: validator != null
          ? (val) => validator!(val) ?? errorText
          : (errorText != null ? (_) => errorText : null),
      isExpanded: isExpanded,
      autovalidateMode: autovalidateMode,
      focusNode: focusNode,
      onSaved: onSaved,
    );
  }
}

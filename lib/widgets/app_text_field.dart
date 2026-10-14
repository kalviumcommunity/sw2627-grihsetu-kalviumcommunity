import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable form-aware labeled text field that integrates with [Form] validation.
///
/// Supports label, hint, helper text, explicit error text, [FormFieldValidator],
/// single/multiline, input actions, prefix/suffix icons, and accessibility semantics.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.controller,
    this.initialValue,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.buildCounter,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.focusNode,
    this.autovalidateMode,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.inputFormatters,
    this.decoration,
    this.textCapitalization = TextCapitalization.none,
  });

  /// The label displayed in the input decoration and used for accessibility.
  final String? label;

  /// Optional placeholder text displayed when the input is empty.
  final String? hintText;

  /// Optional helper text displayed below the field.
  final String? helperText;

  /// Explicit validation error text. When non-null, overrides or supplements validator error.
  final String? errorText;

  /// Controls the text being edited.
  final TextEditingController? controller;

  /// An optional initial value if [controller] is not provided.
  final String? initialValue;

  /// An optional form validator.
  final FormFieldValidator<String>? validator;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// An optional method that is called with the final value when the form is saved.
  final FormFieldSetter<String>? onSaved;

  /// Called when the user indicates that they are done editing.
  final ValueChanged<String>? onFieldSubmitted;

  /// The type of keyboard to display.
  final TextInputType? keyboardType;

  /// The action button to display on the software keyboard.
  final TextInputAction? textInputAction;

  /// The minimum number of lines for multiline input.
  final int? minLines;

  /// The maximum number of lines for multiline input. Defaults to 1.
  final int? maxLines;

  /// The maximum number of characters allowed.
  final int? maxLength;

  /// Callback that generates the custom character counter widget.
  final InputCounterWidgetBuilder? buildCounter;

  /// Whether the field is enabled for user interaction.
  final bool enabled;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Whether to obscure the text (for passwords).
  final bool obscureText;

  /// Defines the keyboard focus for this widget.
  final FocusNode? focusNode;

  /// Used to configure auto-validation behavior.
  final AutovalidateMode? autovalidateMode;

  /// An optional icon that appears before the editable part of the text field.
  final Widget? prefixIcon;

  /// An optional icon that appears after the editable part of the text field.
  final Widget? suffixIcon;

  /// Called when the text field has been tapped.
  final VoidCallback? onTap;

  /// Optional input formatters to apply.
  final List<TextInputFormatter>? inputFormatters;

  /// Optional base input decoration to merge with.
  final InputDecoration? decoration;

  /// Configures how the platform keyboard will select an uppercase or lowercase keyboard.
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final baseDecoration = decoration ?? const InputDecoration();
    final effectiveDecoration = baseDecoration.copyWith(
      labelText: label ?? baseDecoration.labelText,
      hintText: hintText ?? baseDecoration.hintText,
      helperText: helperText ?? baseDecoration.helperText,
      errorText: errorText ?? baseDecoration.errorText,
      prefixIcon: prefixIcon ?? baseDecoration.prefixIcon,
      suffixIcon: suffixIcon ?? baseDecoration.suffixIcon,
      enabled: enabled,
    );

    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      decoration: effectiveDecoration,
      validator: validator != null
          ? (value) => validator!(value) ?? errorText
          : (errorText != null ? (_) => errorText : null),
      onChanged: onChanged,
      onSaved: onSaved,
      onFieldSubmitted: onFieldSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      buildCounter: buildCounter,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      autovalidateMode: autovalidateMode,
      onTap: onTap,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
    );
  }
}

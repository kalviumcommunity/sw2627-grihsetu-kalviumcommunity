import 'package:flutter/material.dart';

import '../../../../services/media_picker.dart';
import '../../../../theme/app_palette.dart';
import '../../../../widgets/app_spacing.dart';
import 'action_sheet_launcher.dart';

class ReopenResult {
  const ReopenResult({
    required this.reason,
    required this.note,
    this.photos = const <String>[],
  });

  final String reason;
  final String note;
  final List<String> photos;
}

class ReopenSheet extends StatefulWidget {
  const ReopenSheet({
    super.key,
    required this.reopenCount,
    this.mediaPicker = const MockMediaPicker(),
    this.onSubmit,
  });

  final int reopenCount;
  final MediaPicker mediaPicker;
  final Future<void> Function(ReopenResult result)? onSubmit;

  static Future<ReopenResult?> show(
    BuildContext context, {
    required int reopenCount,
    MediaPicker mediaPicker = const MockMediaPicker(),
    Future<void> Function(ReopenResult result)? onSubmit,
  }) {
    return showActionSheet<ReopenResult>(
      context: context,
      builder: (ctx) => ReopenSheet(
        reopenCount: reopenCount,
        mediaPicker: mediaPicker,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<ReopenSheet> createState() => _ReopenSheetState();
}

class _ReopenSheetState extends State<ReopenSheet> {
  static const List<String> reasons = [
    'Problem came back',
    'Not fully fixed',
    'New related problem',
    'Other',
  ];

  String? _selectedReason;
  final TextEditingController _noteController = TextEditingController();
  final List<String> _photos = [];

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _formValidationError;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 3) return;
    try {
      final picked = await widget.mediaPicker.pick();
      if (picked != null && mounted) {
        setState(() {
          _photos.add(picked.name);
          _formValidationError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _formValidationError = 'Could not pick media: $e';
        });
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  String? _validate() {
    if (_selectedReason == null || _selectedReason!.isEmpty) {
      return 'Please select a reason for reopening.';
    }

    final note = _noteController.text.trim();
    if (note.length < 15) {
      return 'Note must be at least 15 characters describing the issue.';
    }

    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final err = _validate();
    if (err != null) {
      setState(() {
        _formValidationError = err;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _formValidationError = null;
    });

    final payload = ReopenResult(
      reason: _selectedReason!,
      note: _noteController.text.trim(),
      photos: List.unmodifiable(_photos),
    );

    try {
      if (widget.onSubmit != null) {
        await widget.onSubmit!(payload);
      }
      if (mounted) {
        Navigator.of(context).pop(payload);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reopen complaint',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'Fraunces',
                        fontWeight: FontWeight.bold,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close sheet',
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Warning banner if complaint was already reopened
              if (widget.reopenCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: palette.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.warning),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_outlined, color: palette.warning),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Reopened ${widget.reopenCount} time${widget.reopenCount == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.ink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Error banner with retry keeping entries
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: palette.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.danger),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: palette.danger),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.danger,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              if (_formValidationError != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: palette.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.warning),
                  ),
                  child: Text(
                    _formValidationError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Reason dropdown
              Text(
                'Reason for reopening *',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                key: const Key('reopen_reason_dropdown'),
                isExpanded: true,
                initialValue: _selectedReason,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                hint: const Text('Select reason'),
                items: reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (val) {
                        setState(() {
                          _selectedReason = val;
                          _formValidationError = null;
                        });
                      },
              ),
              const SizedBox(height: AppSpacing.md),

              // Required note (at least 15 chars)
              Text(
                'Explanation (min 15 characters) *',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                key: const Key('reopen_note_field'),
                controller: _noteController,
                enabled: !_isSubmitting,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe why the problem remains unresolved...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (_) {
                  if (_formValidationError != null) {
                    setState(() {
                      _formValidationError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Photos via MediaPicker (max 3)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Photos (${_photos.length}/3)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_photos.length < 3)
                    TextButton.icon(
                      key: const Key('reopen_add_photo_button'),
                      onPressed: _isSubmitting ? null : _pickPhoto,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                      label: const Text('Add photo'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_photos.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (var i = 0; i < _photos.length; i++)
                      Chip(
                        label: Text('Photo #${i + 1}'),
                        onDeleted: _isSubmitting ? null : () => _removePhoto(i),
                      ),
                  ],
                )
              else
                Text(
                  'No photos attached (optional).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),

              // Confirm button
              FilledButton.icon(
                key: const Key('confirm_reopen_button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: palette.danger,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.replay),
                label: Text(
                  _isSubmitting ? 'Reopening...' : 'Reopen complaint',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

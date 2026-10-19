import 'package:flutter/material.dart';

import '../../../../theme/app_palette.dart';
import '../../../../widgets/app_spacing.dart';
import 'action_sheet_launcher.dart';

class CloseResult {
  const CloseResult({
    required this.tenantConfirmed,
    required this.resolutionNotesPresent,
    required this.afterPhotosPresent,
    this.reason,
  });

  final bool tenantConfirmed;
  final bool resolutionNotesPresent;
  final bool afterPhotosPresent;
  final String? reason;
}

class CloseSheet extends StatefulWidget {
  const CloseSheet({
    super.key,
    this.initialTenantConfirmed = false,
    this.initialResolutionNotesPresent = false,
    this.initialAfterPhotosPresent = false,
    this.onSubmit,
  });

  final bool initialTenantConfirmed;
  final bool initialResolutionNotesPresent;
  final bool initialAfterPhotosPresent;
  final Future<void> Function(CloseResult result)? onSubmit;

  static Future<CloseResult?> show(
    BuildContext context, {
    bool initialTenantConfirmed = false,
    bool initialResolutionNotesPresent = false,
    bool initialAfterPhotosPresent = false,
    Future<void> Function(CloseResult result)? onSubmit,
  }) {
    return showActionSheet<CloseResult>(
      context: context,
      builder: (ctx) => CloseSheet(
        initialTenantConfirmed: initialTenantConfirmed,
        initialResolutionNotesPresent: initialResolutionNotesPresent,
        initialAfterPhotosPresent: initialAfterPhotosPresent,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<CloseSheet> createState() => _CloseSheetState();
}

class _CloseSheetState extends State<CloseSheet> {
  late bool _tenantConfirmed;
  late bool _resolutionNotesPresent;
  late bool _afterPhotosPresent;
  final TextEditingController _reasonController = TextEditingController();

  bool _isSubmitting = false;
  bool _isConfirmStep = false;
  String? _errorMessage;
  String? _formValidationError;

  @override
  void initState() {
    super.initState();
    _tenantConfirmed = widget.initialTenantConfirmed;
    _resolutionNotesPresent = widget.initialResolutionNotesPresent;
    _afterPhotosPresent = widget.initialAfterPhotosPresent;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String? _validate() {
    if (!_tenantConfirmed) {
      final reason = _reasonController.text.trim();
      if (reason.length < 15) {
        return 'When closing without tenant confirmation, a reason of at least 15 characters is required.';
      }
    }
    return null;
  }

  void _onProceedToConfirm() {
    final err = _validate();
    if (err != null) {
      setState(() {
        _formValidationError = err;
      });
      return;
    }

    setState(() {
      _formValidationError = null;
      _isConfirmStep = true;
    });
  }

  Future<void> _submitClose() async {
    if (_isSubmitting) return;

    final err = _validate();
    if (err != null) {
      setState(() {
        _formValidationError = err;
        _isConfirmStep = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _formValidationError = null;
    });

    final payload = CloseResult(
      tenantConfirmed: _tenantConfirmed,
      resolutionNotesPresent: _resolutionNotesPresent,
      afterPhotosPresent: _afterPhotosPresent,
      reason: _reasonController.text.trim().isNotEmpty
          ? _reasonController.text.trim()
          : null,
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
          _isConfirmStep = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    final actionLabel = _tenantConfirmed
        ? 'Close complaint'
        : 'Close without tenant confirmation';

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
                      _isConfirmStep ? 'Confirm closure' : 'Close complaint',
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
                        onPressed: _isSubmitting ? null : _submitClose,
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

              if (_isConfirmStep) ...[
                // Final confirmation step
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: palette.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.warning),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: palette.warning),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Closing is final',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: palette.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'This complaint will be permanently closed. Tenants or staff may only reopen it within the 7-day grace period.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() => _isConfirmStep = false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: palette.border),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        key: const Key('final_confirm_close_button'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: palette.accent,
                          foregroundColor: palette.surface,
                        ),
                        onPressed: _isSubmitting ? null : _submitClose,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Confirm close'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Pre-closure Checklist
                Text(
                  'Pre-closure checklist',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                CheckboxListTile(
                  key: const Key('tenant_confirmed_checkbox'),
                  value: _tenantConfirmed,
                  onChanged: _isSubmitting
                      ? null
                      : (val) {
                          setState(() {
                            _tenantConfirmed = val ?? false;
                            _formValidationError = null;
                          });
                        },
                  title: const Text('Tenant confirmed fixed'),
                  subtitle: Text(
                    _tenantConfirmed ? 'Yes' : 'No',
                    style: TextStyle(
                      color: _tenantConfirmed ? palette.success : palette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  key: const Key('resolution_notes_checkbox'),
                  value: _resolutionNotesPresent,
                  onChanged: _isSubmitting
                      ? null
                      : (val) {
                          setState(() {
                            _resolutionNotesPresent = val ?? false;
                          });
                        },
                  title: const Text('Resolution notes present'),
                  subtitle: Text(
                    _resolutionNotesPresent ? 'Verified' : 'Pending notes',
                    style: TextStyle(
                      color: _resolutionNotesPresent
                          ? palette.success
                          : palette.muted,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  key: const Key('after_photos_checkbox'),
                  value: _afterPhotosPresent,
                  onChanged: _isSubmitting
                      ? null
                      : (val) {
                          setState(() {
                            _afterPhotosPresent = val ?? false;
                          });
                        },
                  title: const Text('After photos present'),
                  subtitle: Text(
                    _afterPhotosPresent ? 'Verified' : 'Pending photos',
                    style: TextStyle(
                      color: _afterPhotosPresent
                          ? palette.success
                          : palette.muted,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.md),

                // If tenant not confirmed, required reason >= 15 chars
                if (!_tenantConfirmed) ...[
                  Text(
                    'Reason for closing without tenant confirmation (min 15 chars) *',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: palette.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    key: const Key('close_reason_field'),
                    controller: _reasonController,
                    enabled: !_isSubmitting,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Tenant unresponsive for 5 days after physical inspection...',
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
                ],

                // Action button: "Close complaint" or "Close without tenant confirmation"
                FilledButton.icon(
                  key: const Key('proceed_to_confirm_close_button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: _tenantConfirmed
                        ? palette.accent
                        : palette.warning,
                    foregroundColor: palette.surface,
                  ),
                  onPressed: _isSubmitting ? null : _onProceedToConfirm,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

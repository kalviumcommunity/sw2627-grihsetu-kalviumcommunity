import 'package:flutter/material.dart';

import '../../../../core/enums/complaint_status.dart';
import '../../../../services/errors/app_failure.dart';
import '../../../../services/errors/firebase_error_mapper.dart';
import '../../../../theme/app_palette.dart';
import '../../../../widgets/app_spacing.dart';
import '../../../../widgets/error_banner.dart';
import 'action_sheet_launcher.dart';

class PartEntry {
  PartEntry({String name = '', this.quantity = 1})
    : nameController = TextEditingController(text: name);

  final TextEditingController nameController;
  int quantity;

  void dispose() {
    nameController.dispose();
  }
}

class WaitingForPartsResult {
  const WaitingForPartsResult.putOnHold({
    required this.reason,
    required this.parts,
    required this.expectedDate,
    this.note,
  }) : isResume = false;

  const WaitingForPartsResult.resumeWork()
    : isResume = true,
      reason = null,
      parts = const [],
      expectedDate = null,
      note = null;

  final bool isResume;
  final String? reason;
  final List<Map<String, dynamic>> parts;
  final DateTime? expectedDate;
  final String? note;
}

class WaitingForPartsSheet extends StatefulWidget {
  const WaitingForPartsSheet({
    super.key,
    required this.currentStatus,
    this.onSubmit,
    this.referenceNow,
  });

  final ComplaintStatus currentStatus;
  final Future<void> Function(WaitingForPartsResult result)? onSubmit;
  final DateTime? referenceNow;

  static Future<WaitingForPartsResult?> show(
    BuildContext context, {
    required ComplaintStatus currentStatus,
    Future<void> Function(WaitingForPartsResult result)? onSubmit,
    DateTime? referenceNow,
  }) {
    return showActionSheet<WaitingForPartsResult>(
      context: context,
      builder: (ctx) => WaitingForPartsSheet(
        currentStatus: currentStatus,
        onSubmit: onSubmit,
        referenceNow: referenceNow,
      ),
    );
  }

  @override
  State<WaitingForPartsSheet> createState() => _WaitingForPartsSheetState();
}

class _WaitingForPartsSheetState extends State<WaitingForPartsSheet> {
  static const List<String> reasons = [
    'Part not in stock',
    'Ordered, awaiting delivery',
    'Needs specialist part',
    'Other',
  ];

  String? _selectedReason;
  final List<PartEntry> _parts = [PartEntry()];
  DateTime? _expectedDate;
  final TextEditingController _noteController = TextEditingController();

  bool _isSubmitting = false;
  AppFailure? _failure;
  String? _formValidationError;

  @override
  void initState() {
    super.initState();
    final now = widget.referenceNow ?? DateTime.now();
    _expectedDate = DateTime(now.year, now.month, now.day + 7);
  }

  @override
  void dispose() {
    for (final p in _parts) {
      p.dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  void _addPart() {
    setState(() {
      _parts.add(PartEntry());
      _formValidationError = null;
    });
  }

  void _removePart(int index) {
    if (_parts.length <= 1) return;
    setState(() {
      final removed = _parts.removeAt(index);
      removed.dispose();
      _formValidationError = null;
    });
  }

  Future<void> _pickDate() async {
    final now = widget.referenceNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = today.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDate ?? today.add(const Duration(days: 3)),
      firstDate: today,
      lastDate: maxDate,
    );

    if (picked != null) {
      setState(() {
        _expectedDate = picked;
        _formValidationError = null;
      });
    }
  }

  String? _validate() {
    if (_selectedReason == null || _selectedReason!.isEmpty) {
      return 'Please select a reason.';
    }

    final note = _noteController.text.trim();
    if (_selectedReason == 'Other' && note.length < 10) {
      return 'For "Other", note must be at least 10 characters.';
    }
    if (note.length > 300) {
      return 'Note must be at most 300 characters.';
    }

    if (_parts.isEmpty) {
      return 'At least 1 part is required.';
    }

    for (var i = 0; i < _parts.length; i++) {
      final name = _parts[i].nameController.text.trim();
      final qty = _parts[i].quantity;
      if (name.length < 2 || name.length > 60) {
        return 'Part #${i + 1} name must be 2 to 60 characters.';
      }
      if (qty < 1 || qty > 99) {
        return 'Part #${i + 1} quantity must be between 1 and 99.';
      }
    }

    if (_expectedDate == null) {
      return 'Expected delivery date is required.';
    }

    final now = widget.referenceNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = today.add(const Duration(days: 30));
    final checkDate = DateTime(
      _expectedDate!.year,
      _expectedDate!.month,
      _expectedDate!.day,
    );
    if (checkDate.isBefore(today) || checkDate.isAfter(maxDate)) {
      return 'Expected date must be between today and +30 days.';
    }

    return null;
  }

  Future<void> _submitPutOnHold() async {
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
      _failure = null;
      _formValidationError = null;
    });

    final payload = WaitingForPartsResult.putOnHold(
      reason: _selectedReason!,
      parts: _parts
          .map(
            (p) => {
              'name': p.nameController.text.trim(),
              'quantity': p.quantity,
            },
          )
          .toList(),
      expectedDate: _expectedDate!,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
    );

    try {
      if (widget.onSubmit != null) {
        await widget.onSubmit!(payload);
      }
      if (mounted) {
        Navigator.of(context).pop(payload);
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _failure = FirebaseErrorMapper.map(e, st);
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitResumeWork() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    const payload = WaitingForPartsResult.resumeWork();

    try {
      if (widget.onSubmit != null) {
        await widget.onSubmit!(payload);
      }
      if (mounted) {
        Navigator.of(context).pop(payload);
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _failure = FirebaseErrorMapper.map(e, st);
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final isWaiting = widget.currentStatus == ComplaintStatus.waitingForParts;

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
                      isWaiting ? 'Parts on hold' : 'Hold for parts',
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
              if (_failure != null) ...[
                ErrorBanner(
                  failure: _failure,
                  onDismiss: () => setState(() => _failure = null),
                  onRetry: _isSubmitting
                      ? null
                      : (isWaiting ? _submitResumeWork : _submitPutOnHold),
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

              // When already waiting for parts: allow resuming work
              if (isWaiting) ...[
                Text(
                  'Parts have arrived and work can now continue.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const Key('resume_work_button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: palette.accent,
                    foregroundColor: palette.surface,
                  ),
                  onPressed: _isSubmitting ? null : _submitResumeWork,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_outlined),
                  label: Text(_isSubmitting ? 'Resuming...' : 'Resume work'),
                ),
                const SizedBox(height: AppSpacing.md),
              ] else ...[
                // Reason dropdown
                Text(
                  'Reason for delay *',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  key: const Key('waiting_reason_dropdown'),
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
                  hint: const Text('Select a reason'),
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

                // Parts list
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Required parts (at least 1) *',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: palette.ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('add_part_button'),
                      onPressed: _isSubmitting ? null : _addPart,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add part'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                for (var i = 0; i < _parts.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          key: Key('part_name_field_$i'),
                          controller: _parts[i].nameController,
                          enabled: !_isSubmitting,
                          decoration: InputDecoration(
                            labelText: 'Part #${i + 1} name',
                            hintText: 'e.g. 15A MCB Switch',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<int>(
                          key: Key('part_qty_dropdown_$i'),
                          isExpanded: true,
                          initialValue: _parts[i].quantity,
                          decoration: InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: List.generate(
                            99,
                            (idx) => DropdownMenuItem(
                              value: idx + 1,
                              child: Text('${idx + 1}'),
                            ),
                          ),
                          onChanged: _isSubmitting
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() {
                                      _parts[i].quantity = val;
                                    });
                                  }
                                },
                        ),
                      ),
                      if (_parts.length > 1)
                        IconButton(
                          key: Key('remove_part_button_$i'),
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: palette.danger,
                          ),
                          tooltip: 'Remove part',
                          onPressed: _isSubmitting
                              ? null
                              : () => _removePart(i),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                const SizedBox(height: AppSpacing.sm),

                // Expected Date
                Text(
                  'Expected delivery date *',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                InkWell(
                  key: const Key('expected_date_picker_button'),
                  onTap: _isSubmitting ? null : _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: palette.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _expectedDate == null
                              ? 'Select date (today to +30 days)'
                              : '${_expectedDate!.day.toString().padLeft(2, '0')}/${_expectedDate!.month.toString().padLeft(2, '0')}/${_expectedDate!.year}',
                          style: TextStyle(
                            color: _expectedDate == null
                                ? palette.muted
                                : palette.ink,
                          ),
                        ),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: palette.accent,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Optional note (max 300)
                Text(
                  _selectedReason == 'Other'
                      ? 'Note (required for Other, min 10 chars) *'
                      : 'Additional note (optional, max 300)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  key: const Key('waiting_note_field'),
                  controller: _noteController,
                  enabled: !_isSubmitting,
                  maxLength: 300,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter vendor, PO number or details...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Submit Button
                FilledButton.icon(
                  key: const Key('confirm_waiting_button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: palette.warning,
                    foregroundColor: palette.surface,
                  ),
                  onPressed: _isSubmitting ? null : _submitPutOnHold,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.pause_circle_outline),
                  label: Text(
                    _isSubmitting
                        ? 'Submitting...'
                        : 'Confirm waiting for parts',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

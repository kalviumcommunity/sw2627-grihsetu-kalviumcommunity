import 'package:flutter/material.dart';

import '../../repositories/rent_repository.dart';
import '../../services/errors/app_failure.dart';
import '../../services/errors/firebase_error_mapper.dart';
import '../../theme/app_palette.dart';
import '../../utils/rent_rules.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/error_banner.dart';
import 'rent_models.dart';

/// Modal bottom sheet (phones) or 420px dialog (wide screens)
/// for marking a rent record as paid.
class MarkPaidSheet extends StatefulWidget {
  const MarkPaidSheet({
    super.key,
    required this.item,
    required this.repository,
    this.actor = 'Staff',
    this.now,
  });

  final RentItem item;
  final RentRepository repository;
  final String actor;
  final DateTime? now;

  static Future<RentItem?> show(
    BuildContext context, {
    required RentItem item,
    required RentRepository repository,
    String actor = 'Staff',
    DateTime? now,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) {
      return showDialog<RentItem>(
        context: context,
        builder: (dialogCtx) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: MarkPaidSheet(
              item: item,
              repository: repository,
              actor: actor,
              now: now,
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<RentItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
        ),
        child: MarkPaidSheet(
          item: item,
          repository: repository,
          actor: actor,
          now: now,
        ),
      ),
    );
  }

  @override
  State<MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends State<MarkPaidSheet> {
  PaymentMode _paymentMode = PaymentMode.upi;
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();
  late DateTime _paymentDate;

  bool _confirming = false;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.item.balance.round().toString(),
    );
    _paymentDate = widget.now ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  DateTime get _referenceNow => widget.now ?? DateTime.now();

  Future<void> _pickDate() async {
    final today = _referenceNow;
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: today.subtract(const Duration(days: 60)),
      lastDate: today,
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _failure = null);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      setState(
        () => _failure = const ValidationFailure(
          userMessage: 'Payment amount must be greater than ₹0',
        ),
      );
      return;
    }
    if (amount > widget.item.balance) {
      setState(
        () => _failure = ValidationFailure(
          userMessage:
              'Amount cannot exceed balance of ${formatIndianCurrency(widget.item.balance)}',
        ),
      );
      return;
    }

    if (!_confirming) {
      setState(() => _confirming = true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payment = PaymentRecord(
        id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
        rentRecordId: widget.item.id,
        amount: amount,
        date: _paymentDate,
        mode: _paymentMode,
        actor: widget.actor,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
      );

      await widget.repository.markPaid(payment);

      // Also record follow-up reflecting payment
      final followUp = RentFollowUp(
        id: 'flw_${DateTime.now().millisecondsSinceEpoch}',
        rentRecordId: widget.item.id,
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.paid,
        actor: widget.actor,
        timestamp: _referenceNow,
        note:
            'Payment of ${formatIndianCurrency(amount)} received via ${_paymentMode.label}.',
      );
      final finalItem = await widget.repository.addFollowUp(followUp);

      if (mounted) {
        Navigator.of(context).pop(finalItem);
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _failure = FirebaseErrorMapper.map(e, st);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _confirming ? 'Confirm payment' : 'Mark as paid',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: Icon(Icons.close, color: palette.muted),
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              '${widget.item.tenantName} • Unit ${widget.item.unitNumber} (${widget.item.month})',
              style: TextStyle(fontSize: 13, color: palette.muted),
            ),
            const SizedBox(height: AppSpacing.md),

            if (_failure != null) ...[
              ErrorBanner(
                failure: _failure,
                onDismiss: () => setState(() => _failure = null),
                onRetry: _failure?.retryable == true ? _submit : null,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            if (_confirming) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment summary',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Amount: ${formatIndianCurrency(double.tryParse(_amountController.text) ?? 0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mode: ${_paymentMode.label}',
                      style: TextStyle(fontSize: 14, color: palette.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${_paymentDate.day}/${_paymentDate.month}/${_paymentDate.year}',
                      style: TextStyle(fontSize: 14, color: palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: BorderSide(color: palette.border),
                      ),
                      onPressed: () => setState(() => _confirming = false),
                      child: const Text('Back to edit'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      key: const Key('mark_paid_confirm_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accent,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Confirm settlement'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Payment Mode
              DropdownButtonFormField<PaymentMode>(
                key: const Key('mark_paid_mode_dropdown'),
                initialValue: _paymentMode,
                decoration: InputDecoration(
                  labelText: 'Payment mode *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: PaymentMode.values.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m.label));
                }).toList(),
                onChanged: (m) =>
                    m != null ? setState(() => _paymentMode = m) : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Amount
              TextField(
                key: const Key('mark_paid_amount_field'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (₹) *',
                  helperText:
                      'Balance: ${formatIndianCurrency(widget.item.balance)}',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Date
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Payment date: ${_paymentDate.day}/${_paymentDate.month}/${_paymentDate.year}',
                      style: TextStyle(fontSize: 13, color: palette.ink),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('mark_paid_pick_date_button'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(100, 40),
                    ),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Change'),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Note
              TextField(
                key: const Key('mark_paid_note_field'),
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Transaction note / reference (optional)',
                  hintText: 'e.g. UPI ref #123456',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              FilledButton(
                key: const Key('mark_paid_proceed_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.surface,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _submit,
                child: const Text('Review & confirm'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

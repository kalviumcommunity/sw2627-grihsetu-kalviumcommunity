import 'package:flutter/material.dart';

import '../../repositories/rent_repository.dart';
import '../../theme/app_palette.dart';
import '../../utils/rent_rules.dart';
import '../../widgets/app_spacing.dart';
import 'rent_models.dart';

/// Modal bottom sheet (phones) or 420px dialog (tablets/desktops)
/// for recording a rent follow-up activity.
class AddFollowUpSheet extends StatefulWidget {
  const AddFollowUpSheet({
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

  /// Shows the follow-up sheet adaptively: bottom sheet on phones, dialog on wide screens.
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
            child: AddFollowUpSheet(
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
        child: AddFollowUpSheet(
          item: item,
          repository: repository,
          actor: actor,
          now: now,
        ),
      ),
    );
  }

  @override
  State<AddFollowUpSheet> createState() => _AddFollowUpSheetState();
}

class _AddFollowUpSheetState extends State<AddFollowUpSheet> {
  FollowUpMethod _method = FollowUpMethod.call;
  FollowUpOutcome _outcome = FollowUpOutcome.spokeToTenant;

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _promisedAmountController =
      TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  DateTime? _promisedDate;
  DateTime? _nextFollowUpDate;

  // Paid flow state
  PaymentMode _paymentMode = PaymentMode.upi;
  DateTime _paymentDate = DateTime.now();
  bool _confirmingPayment = false;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final today = _referenceNow;
    _promisedDate = today.add(const Duration(days: 3));
    _promisedAmountController.text = widget.item.balance.round().toString();
    _paidAmountController.text = widget.item.balance.round().toString();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _promisedAmountController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  DateTime get _referenceNow => widget.now ?? DateTime.now();

  Future<void> _pickPromisedDate() async {
    final today = _referenceNow;
    final picked = await showDatePicker(
      context: context,
      initialDate: _promisedDate ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _promisedDate = picked);
    }
  }

  Future<void> _pickNextFollowUpDate() async {
    final today = _referenceNow;
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextFollowUpDate ?? today.add(const Duration(days: 2)),
      firstDate: today.add(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _nextFollowUpDate = picked);
    }
  }

  Future<void> _pickPaymentDate() async {
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
    setState(() {
      _errorMessage = null;
    });

    final double? promisedAmount = _outcome == FollowUpOutcome.promisedToPay
        ? double.tryParse(_promisedAmountController.text.trim())
        : null;

    final validation = validateFollowUp(
      method: _method,
      outcome: _outcome,
      promisedDate: _promisedDate,
      promisedAmount: promisedAmount,
      note: _noteController.text,
      nextFollowUpDate: _nextFollowUpDate,
      currentBalance: widget.item.balance,
      now: _referenceNow,
    );

    if (!validation.isValid) {
      setState(() {
        _errorMessage = validation.firstError;
      });
      return;
    }

    // If outcome is Paid and hasn't gone through confirmation step, show confirm step
    if (_outcome == FollowUpOutcome.paid && !_confirmingPayment) {
      final paidAmount =
          double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
      if (paidAmount <= 0) {
        setState(
          () => _errorMessage = 'Payment amount must be greater than ₹0',
        );
        return;
      }
      if (paidAmount > widget.item.balance) {
        setState(() => _errorMessage = 'Payment amount cannot exceed balance');
        return;
      }
      setState(() => _confirmingPayment = true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final followUpId = 'flw_${DateTime.now().millisecondsSinceEpoch}';
      final followUp = RentFollowUp(
        id: followUpId,
        rentRecordId: widget.item.id,
        method: _method,
        outcome: _outcome,
        actor: widget.actor,
        timestamp: _referenceNow,
        note: _noteController.text.trim(),
        promisedDate: _outcome == FollowUpOutcome.promisedToPay
            ? _promisedDate
            : null,
        promisedAmount: promisedAmount,
        nextFollowUpDate: _nextFollowUpDate,
      );

      RentItem updatedItem;
      if (_outcome == FollowUpOutcome.paid) {
        final paidAmount =
            double.tryParse(_paidAmountController.text.trim()) ??
            widget.item.balance;
        final payment = PaymentRecord(
          id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
          rentRecordId: widget.item.id,
          amount: paidAmount,
          date: _paymentDate,
          mode: _paymentMode,
          actor: widget.actor,
          note: _noteController.text.trim().isNotEmpty
              ? _noteController.text.trim()
              : 'Paid via ${_paymentMode.label}',
        );
        await widget.repository.markPaid(payment);
        updatedItem = await widget.repository.addFollowUp(followUp);
      } else {
        updatedItem = await widget.repository.addFollowUp(followUp);
      }

      if (mounted) {
        Navigator.of(context).pop(updatedItem);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to record follow-up: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final brokenCount = brokenPromises(widget.item.followUps, _referenceNow);

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
            // Handle bar / header
            Row(
              children: [
                Expanded(
                  child: Text(
                    _confirmingPayment ? 'Confirm payment' : 'Add follow-up',
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              '${widget.item.tenantName} • Unit ${widget.item.unitNumber} (${widget.item.month})',
              style: TextStyle(fontSize: 13, color: palette.muted),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Broken promise warning banner
            if (brokenCount >= 2 && !_confirmingPayment) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: palette.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: palette.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Broken promise history ($brokenCount)',
                        style: TextStyle(
                          color: palette.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: palette.danger, fontSize: 13),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            if (_confirmingPayment) ...[
              // Confirmation step for paid outcome
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
                      'Amount: ${formatIndianCurrency(double.tryParse(_paidAmountController.text) ?? 0)}',
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
                      onPressed: () =>
                          setState(() => _confirmingPayment = false),
                      child: const Text('Back to edit'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      key: const Key('confirm_payment_submit_button'),
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
                          : const Text('Confirm & record'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Standard Follow-up form
              // 1. Method
              Text(
                'Follow-up method *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<FollowUpMethod>(
                key: const Key('follow_up_method_segmented'),
                segments: const [
                  ButtonSegment(
                    value: FollowUpMethod.call,
                    label: Text('Call'),
                  ),
                  ButtonSegment(
                    value: FollowUpMethod.message,
                    label: Text('Message'),
                  ),
                  ButtonSegment(
                    value: FollowUpMethod.visit,
                    label: Text('Visit'),
                  ),
                  ButtonSegment(
                    value: FollowUpMethod.email,
                    label: Text('Email'),
                  ),
                ],
                selected: {_method},
                onSelectionChanged: (set) =>
                    setState(() => _method = set.first),
              ),
              const SizedBox(height: AppSpacing.md),

              // 2. Outcome
              Text(
                'Outcome *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<FollowUpOutcome>(
                key: const Key('follow_up_outcome_dropdown'),
                initialValue: _outcome,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: FollowUpOutcome.values.map((o) {
                  return DropdownMenuItem(value: o, child: Text(o.label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _outcome = val);
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. Conditional: Promised to pay fields
              if (_outcome == FollowUpOutcome.promisedToPay) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.accentSoft.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Promised payment details',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Promised Date
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _promisedDate != null
                                  ? 'Promised date: ${_promisedDate!.day}/${_promisedDate!.month}/${_promisedDate!.year}'
                                  : 'Select promised date',
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.ink,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            key: const Key('pick_promised_date_button'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(100, 40),
                            ),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Change'),
                            onPressed: _pickPromisedDate,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Promised Amount
                      TextField(
                        key: const Key('promised_amount_field'),
                        controller: _promisedAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Promised amount (₹) *',
                          hintText: 'e.g. ${widget.item.balance.round()}',
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
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // 4. Conditional: Paid fields
              if (_outcome == FollowUpOutcome.paid) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.accentSoft.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment receipt details',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Payment Mode
                      DropdownButtonFormField<PaymentMode>(
                        key: const Key('payment_mode_dropdown'),
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
                          return DropdownMenuItem(
                            value: m,
                            child: Text(m.label),
                          );
                        }).toList(),
                        onChanged: (m) =>
                            m != null ? setState(() => _paymentMode = m) : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Payment Amount
                      TextField(
                        key: const Key('paid_amount_field'),
                        controller: _paidAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount paid (₹) *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Payment Date
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Payment date: ${_paymentDate.day}/${_paymentDate.month}/${_paymentDate.year}',
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.ink,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            key: const Key('pick_payment_date_button'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(100, 40),
                            ),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Change'),
                            onPressed: _pickPaymentDate,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // 5. Note
              TextField(
                key: const Key('follow_up_note_field'),
                controller: _noteController,
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(
                  labelText: _outcome == FollowUpOutcome.noAnswer
                      ? 'Note (optional)'
                      : 'Note (10-300 characters) *',
                  hintText: 'Summary of the interaction with tenant...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // 6. Next follow-up date (optional)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _nextFollowUpDate != null
                          ? 'Next follow-up: ${_nextFollowUpDate!.day}/${_nextFollowUpDate!.month}/${_nextFollowUpDate!.year}'
                          : 'Next follow-up date: None',
                      style: TextStyle(fontSize: 13, color: palette.muted),
                    ),
                  ),
                  if (_nextFollowUpDate != null)
                    IconButton(
                      tooltip: 'Clear date',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _nextFollowUpDate = null),
                    ),
                  OutlinedButton.icon(
                    key: const Key('pick_next_follow_up_date_button'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(100, 44),
                    ),
                    icon: const Icon(Icons.calendar_month, size: 16),
                    label: Text(
                      _nextFollowUpDate == null ? 'Set date' : 'Change',
                    ),
                    onPressed: _pickNextFollowUpDate,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Submit button
              FilledButton(
                key: const Key('submit_follow_up_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.surface,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                    : Text(
                        _outcome == FollowUpOutcome.paid
                            ? 'Proceed to payment'
                            : 'Save follow-up',
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

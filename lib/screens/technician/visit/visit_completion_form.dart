import 'package:flutter/material.dart';

import '../../../repositories/complaint_repository.dart';
import '../../../services/media_picker.dart';
import '../../../theme/app_palette.dart';
import '../../../utils/visit_validators.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_spacing.dart';
import 'visit_models.dart';
import 'visit_success_screen.dart';

/// Form for completing or requesting follow-up for a visit.
class VisitCompletionForm extends StatefulWidget {
  const VisitCompletionForm({
    super.key,
    required this.complaintId,
    required this.repository,
    this.mediaPicker,
    required this.technicianId,
    this.technicianName = 'Aman Verma',
    this.initialAfterPhotos = const [],
    this.onSiteDuration = Duration.zero,
  });

  final String complaintId;
  final ComplaintRepository repository;
  final MediaPicker? mediaPicker;
  final String technicianId;
  final String technicianName;
  final List<String> initialAfterPhotos;
  final Duration onSiteDuration;

  static Future<bool?> open(
    BuildContext context, {
    required String complaintId,
    required ComplaintRepository repository,
    MediaPicker? mediaPicker,
    required String technicianId,
    String technicianName = 'Aman Verma',
    List<String> initialAfterPhotos = const [],
    Duration onSiteDuration = Duration.zero,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) {
      return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 850),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: VisitCompletionForm(
                complaintId: complaintId,
                repository: repository,
                mediaPicker: mediaPicker,
                technicianId: technicianId,
                technicianName: technicianName,
                initialAfterPhotos: initialAfterPhotos,
                onSiteDuration: onSiteDuration,
              ),
            ),
          ),
        ),
      );
    }

    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VisitCompletionForm(
          complaintId: complaintId,
          repository: repository,
          mediaPicker: mediaPicker,
          technicianId: technicianId,
          technicianName: technicianName,
          initialAfterPhotos: initialAfterPhotos,
          onSiteDuration: onSiteDuration,
        ),
      ),
    );
  }

  @override
  State<VisitCompletionForm> createState() => _VisitCompletionFormState();
}

class _VisitCompletionFormState extends State<VisitCompletionForm> {
  late final MediaPicker _mediaPicker;
  final _scrollController = ScrollController();

  // Keys for scrolling to errors
  final _foundKey = GlobalKey();
  final _repairedKey = GlobalKey();
  final _partsKey = GlobalKey();
  final _tenantNotesKey = GlobalKey();
  final _afterPhotosKey = GlobalKey();
  final _reasonKey = GlobalKey();
  final _detailsKey = GlobalKey();

  // Form State
  String _outcome = 'resolved'; // 'resolved' or 'needsAnotherVisit'

  // Resolved fields
  final _foundController = TextEditingController();
  final _repairedController = TextEditingController();
  final _tenantNotesController = TextEditingController();
  final _additionalWorkNotesController = TextEditingController();
  bool _noPartsUsed = false;
  bool _additionalWorkRecommended = false;
  final List<VisitPartInput> _parts = [];
  final List<String> _afterPhotos = [];

  // Temporary controllers for adding a part
  final _partNameController = TextEditingController();
  final _partQtyController = TextEditingController(text: '1');
  final _partCostController = TextEditingController();

  // Needs another visit fields
  FollowUpReason? _followUpReason;
  final _otherReasonController = TextEditingController();
  final _detailsController = TextEditingController();
  DateTime? _suggestedDate;
  String? _suggestedSlot;
  final List<String> _partsToBring = [];
  final _partToBringController = TextEditingController();

  // Validation & Submission
  final Map<String, String?> _errors = {};
  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _mediaPicker = widget.mediaPicker ?? const MockMediaPicker();
    _afterPhotos.addAll(widget.initialAfterPhotos);
    _restoreDraft();
  }

  void _restoreDraft() {
    final draft = VisitFormDraftStore.get(widget.complaintId);
    if (draft != null) {
      _outcome = draft.outcome;
      _foundController.text = draft.whatWasFound;
      _repairedController.text = draft.whatWasRepaired;
      _parts.clear();
      _parts.addAll(draft.parts);
      _noPartsUsed = draft.noPartsUsed;
      _additionalWorkRecommended = draft.additionalWorkRecommended;
      _additionalWorkNotesController.text = draft.additionalWorkNotes;
      _tenantNotesController.text = draft.tenantResolutionNotes;
      if (draft.afterPhotos.isNotEmpty) {
        _afterPhotos.clear();
        _afterPhotos.addAll(draft.afterPhotos);
      }
      _followUpReason = draft.reason;
      _otherReasonController.text = draft.otherReasonDetails;
      _detailsController.text = draft.details;
      _suggestedDate = draft.suggestedDate;
      _suggestedSlot = draft.suggestedSlot;
      _partsToBring.clear();
      _partsToBring.addAll(draft.partsToBring);
    }
  }

  void _saveDraft() {
    final draft = VisitFormDraft(
      outcome: _outcome,
      whatWasFound: _foundController.text,
      whatWasRepaired: _repairedController.text,
      parts: List.from(_parts),
      noPartsUsed: _noPartsUsed,
      additionalWorkRecommended: _additionalWorkRecommended,
      additionalWorkNotes: _additionalWorkNotesController.text,
      tenantResolutionNotes: _tenantNotesController.text,
      afterPhotos: List.from(_afterPhotos),
      reason: _followUpReason,
      otherReasonDetails: _otherReasonController.text,
      details: _detailsController.text,
      suggestedDate: _suggestedDate,
      suggestedSlot: _suggestedSlot,
      partsToBring: List.from(_partsToBring),
    );
    VisitFormDraftStore.save(widget.complaintId, draft);
  }

  @override
  void dispose() {
    _saveDraft();
    _foundController.dispose();
    _repairedController.dispose();
    _tenantNotesController.dispose();
    _additionalWorkNotesController.dispose();
    _partNameController.dispose();
    _partQtyController.dispose();
    _partCostController.dispose();
    _otherReasonController.dispose();
    _detailsController.dispose();
    _partToBringController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isFormDirty() {
    return _foundController.text.isNotEmpty ||
        _repairedController.text.isNotEmpty ||
        _tenantNotesController.text.isNotEmpty ||
        _parts.isNotEmpty ||
        _noPartsUsed ||
        _additionalWorkNotesController.text.isNotEmpty ||
        _afterPhotos.isNotEmpty ||
        _followUpReason != null ||
        _detailsController.text.isNotEmpty ||
        _partsToBring.isNotEmpty;
  }

  Future<bool> _handlePopScope() async {
    if (!_isFormDirty()) return true;
    _saveDraft();

    final palette = context.palette;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          'Leave visit form?',
          style: TextStyle(fontFamily: 'Fraunces', color: palette.ink),
        ),
        content: Text(
          'Your progress has been saved as a draft. You can return to finish it anytime.',
          style: TextStyle(color: palette.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.accent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  bool _validateForm() {
    final errors = <String, String?>{};
    GlobalKey? firstErrorKey;

    if (_outcome == 'resolved') {
      final foundErr = VisitValidators.validateFound(_foundController.text);
      if (foundErr != null) {
        errors['found'] = foundErr;
        firstErrorKey ??= _foundKey;
      }

      final repairedErr = VisitValidators.validateRepaired(
        _repairedController.text,
      );
      if (repairedErr != null) {
        errors['repaired'] = repairedErr;
        firstErrorKey ??= _repairedKey;
      }

      final partsErr = VisitValidators.validatePartsGroup(
        parts: _parts,
        noPartsUsed: _noPartsUsed,
      );
      if (partsErr != null) {
        errors['parts'] = partsErr;
        firstErrorKey ??= _partsKey;
      }

      final notesErr = VisitValidators.validateTenantResolutionNotes(
        _tenantNotesController.text,
      );
      if (notesErr != null) {
        errors['tenantNotes'] = notesErr;
        firstErrorKey ??= _tenantNotesKey;
      }

      final afterPhotosErr = VisitValidators.validateAfterPhotosCount(
        _afterPhotos.length,
      );
      if (afterPhotosErr != null) {
        errors['afterPhotos'] = afterPhotosErr;
        firstErrorKey ??= _afterPhotosKey;
      }
    } else {
      final reasonErr = VisitValidators.validateFollowUpReason(
        _followUpReason,
        otherNote: _otherReasonController.text,
      );
      if (reasonErr != null) {
        errors['reason'] = reasonErr;
        firstErrorKey ??= _reasonKey;
      }

      final detailsErr = VisitValidators.validateFollowUpDetails(
        _detailsController.text,
      );
      if (detailsErr != null) {
        errors['details'] = detailsErr;
        firstErrorKey ??= _detailsKey;
      }

      if (_suggestedDate != null) {
        final dateErr = VisitValidators.validateSuggestedDate(_suggestedDate);
        if (dateErr != null) {
          errors['date'] = dateErr;
        }
      }
    }

    setState(() {
      _errors.clear();
      _errors.addAll(errors);
    });

    if (firstErrorKey != null && firstErrorKey.currentContext != null) {
      Scrollable.ensureVisible(
        firstErrorKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return false;
    }

    return errors.isEmpty;
  }

  void _addPartRow() {
    final name = _partNameController.text.trim();
    final qty = int.tryParse(_partQtyController.text.trim()) ?? 0;
    final cost = double.tryParse(_partCostController.text.trim());

    final nameErr = VisitValidators.validatePartName(name);
    final qtyErr = VisitValidators.validatePartQuantity(qty);
    final costErr = VisitValidators.validatePartCost(cost);

    if (nameErr != null || qtyErr != null || costErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(nameErr ?? qtyErr ?? costErr ?? 'Invalid part')),
      );
      return;
    }

    setState(() {
      _parts.add(VisitPartInput(name: name, quantity: qty, cost: cost));
      _noPartsUsed = false;
      _partNameController.clear();
      _partQtyController.text = '1';
      _partCostController.clear();
      _errors.remove('parts');
    });
    _saveDraft();
  }

  Future<void> _addAfterPhoto() async {
    final countErr = VisitValidators.validateAttachmentsCount(
      _afterPhotos.length + 1,
    );
    if (countErr != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(countErr)));
      return;
    }

    final picked = await _mediaPicker.pick();
    if (picked != null) {
      final name =
          'after_${picked.name}_${DateTime.now().millisecondsSinceEpoch}';
      await widget.repository.addVisitPhoto(
        widget.complaintId,
        photoUrl: name,
        group: 'after',
        actorId: widget.technicianId,
        role: 'technician',
      );
      setState(() {
        _afterPhotos.add(name);
        _errors.remove('afterPhotos');
      });
      _saveDraft();
    }
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    final palette = context.palette;
    final isResolved = _outcome == 'resolved';

    // Show confirmation dialog before submit
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          isResolved ? 'Confirm Visit Resolution' : 'Confirm Follow-up Request',
          style: TextStyle(fontFamily: 'Fraunces', color: palette.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isResolved
                  ? 'Are you sure you want to mark this visit as Resolved? The tenant will be notified to confirm the fix.'
                  : 'Are you sure you want to request another visit? This complaint will be flagged for operations staff.',
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: palette.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Outcome: ${isResolved ? "Resolved" : "Needs another visit"}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: palette.ink,
                    ),
                  ),
                  if (isResolved) ...[
                    Text(
                      'Parts: ${_noPartsUsed ? "None" : "${_parts.length} used"}',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                    Text(
                      'After photos: ${_afterPhotos.length}',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ] else ...[
                    Text(
                      'Reason: ${_followUpReason?.label ?? "Not set"}',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Review entries'),
          ),
          FilledButton(
            key: const Key('confirm_submit_button'),
            style: FilledButton.styleFrom(
              backgroundColor: isResolved ? palette.success : palette.accent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      if (isResolved) {
        final completion = VisitCompletionInput(
          whatWasFound: _foundController.text.trim(),
          whatWasRepaired: _repairedController.text.trim(),
          parts: List.from(_parts),
          noPartsUsed: _noPartsUsed,
          additionalWorkRecommended: _additionalWorkRecommended,
          additionalWorkNotes: _additionalWorkRecommended
              ? _additionalWorkNotesController.text.trim()
              : null,
          tenantResolutionNotes: _tenantNotesController.text.trim(),
          afterPhotos: List.from(_afterPhotos),
        );
        await widget.repository.completeVisit(
          widget.complaintId,
          completion,
          actorId: widget.technicianId,
          role: 'technician',
        );
      } else {
        final followUp = FollowUpRequestInput(
          reason: _followUpReason!,
          otherReasonDetails: _followUpReason == FollowUpReason.other
              ? _otherReasonController.text.trim()
              : null,
          details: _detailsController.text.trim(),
          suggestedDate: _suggestedDate,
          suggestedSlot: _suggestedSlot,
          partsToBring: List.from(_partsToBring),
        );
        await widget.repository.requestFollowUpVisit(
          widget.complaintId,
          followUp,
          actorId: widget.technicianId,
          role: 'technician',
        );
      }

      // Clear autosave draft on success
      VisitFormDraftStore.clear(widget.complaintId);

      if (mounted) {
        await VisitSuccessScreen.open(
          context,
          complaintId: widget.complaintId,
          isResolved: isResolved,
          summaryTitle: isResolved
              ? 'Repaired: ${_repairedController.text.trim()}'
              : 'Follow-up Reason: ${_followUpReason?.label}',
          summaryDetails: isResolved
              ? 'Found: ${_foundController.text.trim()}'
              : 'Details: ${_detailsController.text.trim()}',
          onSiteDuration: widget.onSiteDuration,
          partsCount: _parts.length,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submissionError = 'Failed to submit visit: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handlePopScope();
        if (shouldPop && mounted) {
          if (!context.mounted) return;
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        backgroundColor: palette.canvas,
        appBar: AppBar(
          title: const Text(
            'Complete Visit',
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                final shouldPop = await _handlePopScope();
                if (shouldPop && mounted) {
                  if (!context.mounted) return;
                  Navigator.of(context).pop(false);
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Retry banner if submission failed
              if (_submissionError != null)
                Container(
                  width: double.infinity,
                  color: palette.danger.withValues(alpha: 0.15),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: palette.danger,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _submissionError!,
                          style: TextStyle(color: palette.danger, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: _submitForm,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Outcome selector
                      _buildOutcomeSelector(context),
                      const SizedBox(height: AppSpacing.md),

                      // Outcome specific forms
                      if (_outcome == 'resolved') ...[
                        _buildResolvedSection(context),
                      ] else ...[
                        _buildNeedsAnotherVisitSection(context),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),

              // Sticky Submit Button
              _buildBottomSubmitBar(context),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // OUTCOME SELECTOR
  // -------------------------------------------------------------
  Widget _buildOutcomeSelector(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visit Outcome',
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Select whether the complaint was resolved or requires another visit.',
            style: TextStyle(color: palette.muted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const Key('outcome_resolved_button'),
                  onTap: () {
                    setState(() {
                      _outcome = 'resolved';
                      _errors.clear();
                    });
                    _saveDraft();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _outcome == 'resolved'
                          ? palette.success.withValues(alpha: 0.12)
                          : palette.canvas,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _outcome == 'resolved'
                            ? palette.success
                            : palette.border,
                        width: _outcome == 'resolved' ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Resolved',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _outcome == 'resolved'
                              ? palette.success
                              : palette.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: InkWell(
                  key: const Key('outcome_needs_another_visit_button'),
                  onTap: () {
                    setState(() {
                      _outcome = 'needsAnotherVisit';
                      _errors.clear();
                    });
                    _saveDraft();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _outcome == 'needsAnotherVisit'
                          ? palette.accent.withValues(alpha: 0.12)
                          : palette.canvas,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _outcome == 'needsAnotherVisit'
                            ? palette.accent
                            : palette.border,
                        width: _outcome == 'needsAnotherVisit' ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Needs another visit',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _outcome == 'needsAnotherVisit'
                              ? palette.accent
                              : palette.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // RESOLVED SECTION
  // -------------------------------------------------------------
  Widget _buildResolvedSection(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // What was found
        AppCard(
          key: _foundKey,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'What was found *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _foundController,
                    builder: (_, val, _) => Text(
                      '${val.text.length}/500',
                      style: TextStyle(
                        fontSize: 11,
                        color: val.text.length > 500
                            ? palette.danger
                            : palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                key: const Key('what_was_found_field'),
                controller: _foundController,
                maxLines: 3,
                maxLength: 500,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                onChanged: (_) {
                  _saveDraft();
                  if (_errors.containsKey('found')) {
                    setState(() => _errors.remove('found'));
                  }
                },
                decoration: InputDecoration(
                  hintText:
                      'Describe root cause identified during inspection...',
                  errorText: _errors['found'],
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // What was repaired
        AppCard(
          key: _repairedKey,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'What was repaired *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _repairedController,
                    builder: (_, val, _) => Text(
                      '${val.text.length}/500',
                      style: TextStyle(
                        fontSize: 11,
                        color: val.text.length > 500
                            ? palette.danger
                            : palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                key: const Key('what_was_repaired_field'),
                controller: _repairedController,
                maxLines: 3,
                maxLength: 500,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                onChanged: (_) {
                  _saveDraft();
                  if (_errors.containsKey('repaired')) {
                    setState(() => _errors.remove('repaired'));
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Detail actions taken to resolve the problem...',
                  errorText: _errors['repaired'],
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Parts used (repeatable rows + No parts used checkbox)
        AppCard(
          key: _partsKey,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Parts Used *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              CheckboxListTile(
                key: const Key('no_parts_used_checkbox'),
                contentPadding: EdgeInsets.zero,
                title: const Text('No parts used for this repair'),
                value: _noPartsUsed,
                onChanged: (val) {
                  setState(() {
                    _noPartsUsed = val ?? false;
                    if (_noPartsUsed) _parts.clear();
                    _errors.remove('parts');
                  });
                  _saveDraft();
                },
              ),
              if (_errors['parts'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    _errors['parts']!,
                    style: TextStyle(color: palette.danger, fontSize: 12),
                  ),
                ),
              if (!_noPartsUsed) ...[
                const SizedBox(height: AppSpacing.xs),
                for (var i = 0; i < _parts.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: palette.canvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_parts[i].name} (x${_parts[i].quantity})${_parts[i].cost != null ? " · ₹${_parts[i].cost}" : ""}',
                            style: TextStyle(fontSize: 13, color: palette.ink),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: palette.danger,
                          ),
                          onPressed: () {
                            setState(() => _parts.removeAt(i));
                            _saveDraft();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        key: const Key('part_name_input'),
                        controller: _partNameController,
                        decoration: const InputDecoration(
                          hintText: 'Part name',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        key: const Key('part_qty_input'),
                        controller: _partQtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Qty (1-99)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton.filled(
                      key: const Key('add_part_button'),
                      style: IconButton.styleFrom(
                        backgroundColor: palette.accent,
                      ),
                      onPressed: _addPartRow,
                      icon: const Icon(Icons.add, size: 20),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Additional work recommended (optional switch + note)
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                key: const Key('additional_work_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Additional work recommended'),
                subtitle: const Text(
                  'Flags a follow-up recommendation for operations staff',
                  style: TextStyle(fontSize: 12),
                ),
                value: _additionalWorkRecommended,
                onChanged: (val) {
                  setState(() => _additionalWorkRecommended = val);
                  _saveDraft();
                },
              ),
              if (_additionalWorkRecommended) ...[
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  key: const Key('additional_work_notes_field'),
                  controller: _additionalWorkNotesController,
                  maxLines: 2,
                  onChanged: (_) => _saveDraft(),
                  decoration: const InputDecoration(
                    hintText: 'Notes for staff regarding preventative or future work...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Tenant resolution notes
        AppCard(
          key: _tenantNotesKey,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Resolution notes for tenant *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _tenantNotesController,
                    builder: (_, val, _) => Text(
                      '${val.text.length}/500',
                      style: TextStyle(
                        fontSize: 11,
                        color: val.text.length > 500
                            ? palette.danger
                            : palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Note: The tenant will receive these notes and be prompted to confirm or reopen.',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                key: const Key('tenant_resolution_notes_field'),
                controller: _tenantNotesController,
                maxLines: 3,
                maxLength: 500,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                onChanged: (_) {
                  _saveDraft();
                  if (_errors.containsKey('tenantNotes')) {
                    setState(() => _errors.remove('tenantNotes'));
                  }
                },
                decoration: InputDecoration(
                  hintText:
                      'Explain how the issue was fixed so tenant can verify...',
                  errorText: _errors['tenantNotes'],
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // After photos (min 1 required for Resolved)
        AppCard(
          key: _afterPhotosKey,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(
                    'After Photos (${_afterPhotos.length}/6) *',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: palette.ink,
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('add_after_photo_form_button'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: palette.accent,
                    ),
                    onPressed: _addAfterPhoto,
                    icon: const Icon(Icons.add_a_photo, size: 16),
                    label: const Text('Add photo'),
                  ),
                ],
              ),
              if (_errors['afterPhotos'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    _errors['afterPhotos']!,
                    style: TextStyle(color: palette.danger, fontSize: 12),
                  ),
                ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final photo in _afterPhotos)
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 60,
                          decoration: BoxDecoration(
                            color: palette.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: palette.border),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.image,
                              size: 20,
                              color: palette.accent,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () {
                              setState(() => _afterPhotos.remove(photo));
                              _saveDraft();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: palette.danger,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_afterPhotos.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: palette.canvas,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        'At least 1 "After" photo is required to document completion.',
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // NEEDS ANOTHER VISIT SECTION
  // -------------------------------------------------------------
  Widget _buildNeedsAnotherVisitSection(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reason selector
        AppCard(
          key: _reasonKey,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reason for follow-up visit *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<FollowUpReason>(
                key: const Key('follow_up_reason_dropdown'),
                isExpanded: true,
                initialValue: _followUpReason,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  errorText: _followUpReason == FollowUpReason.other
                      ? null
                      : _errors['reason'],
                ),
                hint: const Text('Select a reason...'),
                items: FollowUpReason.values.map((reason) {
                  return DropdownMenuItem(
                    value: reason,
                    child: Text(reason.label, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _followUpReason = val;
                    _errors.remove('reason');
                  });
                  _saveDraft();
                },
              ),
              if (_followUpReason == FollowUpReason.other) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('other_reason_details_field'),
                  controller: _otherReasonController,
                  maxLength: 500,
                  onChanged: (_) {
                    _saveDraft();
                    if (_errors.containsKey('reason')) {
                      setState(() => _errors.remove('reason'));
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Specify other reason * (min 10 characters)',
                    errorText: _errors['reason'],
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Details note
        AppCard(
          key: _detailsKey,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Details note *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _detailsController,
                    builder: (_, val, _) => Text(
                      '${val.text.length}/500',
                      style: TextStyle(
                        fontSize: 11,
                        color: val.text.length > 500
                            ? palette.danger
                            : palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                key: const Key('follow_up_details_field'),
                controller: _detailsController,
                maxLines: 3,
                maxLength: 500,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                onChanged: (_) {
                  _saveDraft();
                  if (_errors.containsKey('details')) {
                    setState(() => _errors.remove('details'));
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Explain why another visit is needed and what was accomplished so far...',
                  errorText: _errors['details'],
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Suggested next visit date and slot
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggested Next Visit (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('pick_suggested_date_button'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _suggestedDate ?? now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 14)),
                        );
                        if (picked != null) {
                          setState(() => _suggestedDate = picked);
                          _saveDraft();
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _suggestedDate != null
                            ? '${_suggestedDate!.day}/${_suggestedDate!.month}/${_suggestedDate!.year}'
                            : 'Select date (up to +14d)',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const Key('suggested_slot_dropdown'),
                      isExpanded: true,
                      initialValue: _suggestedSlot,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: 'Slot',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Morning (9am - 12pm)',
                          child: Text(
                            'Morning',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Afternoon (12pm - 4pm)',
                          child: Text(
                            'Afternoon',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Evening (4pm - 7pm)',
                          child: Text(
                            'Evening',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _suggestedSlot = val);
                        _saveDraft();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Parts to bring
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Parts to Bring (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (var i = 0; i < _partsToBring.length; i++) ...[
                Row(
                  children: [
                    Icon(Icons.build, size: 14, color: palette.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _partsToBring[i],
                        style: TextStyle(fontSize: 13, color: palette.ink),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: palette.danger),
                      onPressed: () {
                        setState(() => _partsToBring.removeAt(i));
                        _saveDraft();
                      },
                    ),
                  ],
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('part_to_bring_input'),
                      controller: _partToBringController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 1/2" brass valve',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filled(
                    key: const Key('add_part_to_bring_button'),
                    style: IconButton.styleFrom(
                      backgroundColor: palette.accent,
                    ),
                    onPressed: () {
                      final item = _partToBringController.text.trim();
                      if (item.isNotEmpty) {
                        setState(() {
                          _partsToBring.add(item);
                          _partToBringController.clear();
                        });
                        _saveDraft();
                      }
                    },
                    icon: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // BOTTOM SUBMIT BAR
  // -------------------------------------------------------------
  Widget _buildBottomSubmitBar(BuildContext context) {
    final palette = context.palette;
    final isResolved = _outcome == 'resolved';

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56, // Large 56px primary button
          child: FilledButton.icon(
            key: const Key('submit_visit_button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: isResolved ? palette.success : palette.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // The Submit button is NEVER silently disabled
            onPressed: _isSubmitting ? null : _submitForm,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(isResolved ? Icons.check : Icons.send, size: 20),
            label: Text(
              _isSubmitting
                  ? 'Submitting...'
                  : (isResolved
                        ? 'Submit & Mark Resolved'
                        : 'Request Follow-up Visit'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

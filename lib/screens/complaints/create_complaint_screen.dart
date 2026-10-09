import 'package:flutter/material.dart';

import '../../core/enums/complaint_category.dart';
import '../../core/enums/complaint_priority.dart';
import '../../core/enums/complaint_status.dart';
import '../../core/enums/user_role.dart';
import '../../core/fixtures/sample_fixtures.dart';
import '../../repositories/complaint_repository.dart';
import '../../screens/property/property_selection_flow.dart';
import '../../services/media_picker.dart';
import '../../theme/app_palette.dart';
import '../../utils/complaint_validators.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/status_badge.dart';
import 'complaint_draft.dart';

class CreateComplaintScreen extends StatefulWidget {
  const CreateComplaintScreen({
    super.key,
    this.role = UserRole.tenant,
    this.repository,
    this.mediaPicker = const MockMediaPicker(),
  });

  final UserRole role;
  final ComplaintRepository? repository;
  final MediaPicker mediaPicker;

  @override
  State<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  late final ComplaintRepository _repository =
      widget.repository ?? InMemoryComplaintRepository();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _descriptionFocus = FocusNode();
  ComplaintDraft _draft = const ComplaintDraft();
  int _step = 0;
  Map<String, String> _errors = {};
  Complaint? _duplicate;
  bool _loading = false;
  String? _submitError;
  Complaint? _created;

  bool get _isTenant => widget.role == UserRole.tenant;
  bool get _hasChanges =>
      _draft.title.isNotEmpty ||
      _draft.description.isNotEmpty ||
      _draft.propertyId != null ||
      _draft.category != null ||
      _draft.attachments.isNotEmpty ||
      _draft.preferredVisitDate != null ||
      _phone.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isTenant) {
      final tenant = SampleFixtures.sampleTenants.first;
      final unit = SampleFixtures.sampleUnits.first;
      final property = SampleFixtures.sampleProperties.first;
      _draft = _draft.copyWith(
        propertyId: property.id,
        propertyName: property.name,
        unitId: unit.id,
        unitNumber: unit.unitNumber,
        tenantId: tenant.id,
        tenantName: tenant.name,
        contactPhone: tenant.phone.replaceAll(RegExp(r'\D'), '').substring(2),
      );
      _phone.text = _draft.contactPhone;
    }
    _title.addListener(_syncFields);
    _description.addListener(_syncFields);
    _phone.addListener(_syncFields);
  }

  void _syncFields() => setState(() {
    _draft = _draft.copyWith(
      title: _title.text,
      description: _description.text,
      contactPhone: _phone.text,
    );
  });

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _phone.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (!_hasChanges || _created != null) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave complaint draft?'),
        content: const Text('Your entered details will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _pickLocation() async {
    final selection = await PropertySelectionFlow.pick(
      context,
      requireTenant: !_isTenant,
    );
    if (!mounted || selection == null) return;
    setState(() {
      _draft = _draft.copyWith(
        propertyId: selection.propertyId,
        propertyName: selection.propertyName,
        unitId: selection.unitId,
        unitNumber: selection.unitNumber,
        tenantId: selection.tenantId,
        tenantName: selection.tenantName,
      );
      _errors = {};
    });
  }

  Future<void> _continue() async {
    final validation = switch (_step) {
      0 => ComplaintValidators.validate(_draft, requireTenant: !_isTenant),
      1 => ComplaintValidation({
          if (ComplaintValidators.category(_draft) case final error?) 'category': error,
          if (ComplaintValidators.title(_draft.title) case final error?) 'title': error,
          if (ComplaintValidators.description(_draft.description, priority: _draft.priority)
              case final error?)
            'description': error,
        }),
      2 => ComplaintValidation({
          if (ComplaintValidators.attachments(_draft.attachments) case final error?)
            'attachments': error,
        }),
      3 => ComplaintValidation({
          if (ComplaintValidators.visit(_draft) case final error?) 'visit': error,
          if (ComplaintValidators.phone(_draft.contactPhone) case final error?)
            'phone': error,
        }),
      _ => const ComplaintValidation({}),
    };
    if (!validation.isValid) {
      setState(() => _errors = validation.errors);
      if (_errors.containsKey('description')) _descriptionFocus.requestFocus();
      return;
    }
    if (_step == 1 && _draft.unitId != null && _draft.category != null) {
      _duplicate = await _repository.findOpenDuplicate(
        unitId: _draft.unitId!,
        category: _draft.category!,
      );
    }
    if (!mounted) return;
    setState(() {
      _errors = {};
      _step = (_step + 1).clamp(0, 4);
    });
  }

  void _back() => setState(() {
    if (_step > 0) _step--;
  });

  Future<void> _addAttachment() async {
    if (_draft.attachments.length >= 5) {
      setState(() => _errors = {'attachments': 'You can add up to 5 attachments'});
      return;
    }
    final item = await widget.mediaPicker.pick();
    if (!mounted || item == null) return;
    setState(() {
      _draft = _draft.copyWith(attachments: [..._draft.attachments, item]);
      _errors = {};
    });
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 14)),
      initialDate: _draft.preferredVisitDate ?? now,
    );
    if (date == null || !mounted) return;
    setState(() => _draft = _draft.copyWith(preferredVisitDate: date));
  }

  Future<void> _submit() async {
    if (_loading) return;
    final validation = ComplaintValidators.validate(_draft, requireTenant: !_isTenant);
    if (!validation.isValid) {
      setState(() {
        _errors = validation.errors;
        _step = validation.errors.containsKey('location') ? 0 : 1;
      });
      return;
    }
    setState(() {
      _loading = true;
      _submitError = null;
    });
    try {
      final complaint = await _repository.create(_draft);
      if (mounted) setState(() => _created = complaint);
    } catch (_) {
      if (mounted) setState(() => _submitError = 'We could not submit your complaint.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_created != null) return _SuccessScreen(complaint: _created!, onAnother: _reset);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) async {
        if (await _confirmLeave() && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: context.palette.canvas,
        appBar: AppBar(title: const Text('Raise complaint')),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (constraints.maxWidth >= 900) _SideStepper(step: _step),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          if (constraints.maxWidth < 900) _TopProgress(step: _step),
                          Expanded(child: _stepBody()),
                          _Actions(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody() => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (_step) {
        0 => _whereStep(),
        1 => _whatStep(),
        2 => _evidenceStep(),
        3 => _visitStep(),
        _ => _reviewStep(),
      },
    ),
  );

  Widget _whereStep() => _StepSection(
    title: 'Where is the issue?',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Select the property, unit, and resident connected to this complaint.'),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          selected: _draft.propertyId != null,
          onTap: _isTenant ? null : _pickLocation,
          child: Text(
            _draft.propertyId == null
                ? 'Choose property and unit'
                : '${_draft.propertyName}  ›  ${_draft.unitNumber}\n${_draft.tenantName ?? 'Tenant not selected'}',
          ),
        ),
        if (_isTenant) const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('Your signed-in home is prefilled. // TODO: load from auth.'),
        ),
        if (_errors['location'] != null) _ErrorText(_errors['location']!),
      ],
    ),
  );

  Widget _whatStep() => _StepSection(
    title: 'What needs attention?',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in const [
              ComplaintCategory.plumbing,
              ComplaintCategory.electrical,
              ComplaintCategory.structural,
              ComplaintCategory.appliance,
              ComplaintCategory.other,
            ])
              FilterChip(
                label: Text(category == ComplaintCategory.structural ? 'Civil' : category.displayLabel),
                selected: _draft.category == category,
                onSelected: (_) => setState(() => _draft = _draft.copyWith(category: category)),
              ),
          ],
        ),
        if (_errors['category'] != null) _ErrorText(_errors['category']!),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _title,
          textInputAction: TextInputAction.next,
          decoration: _decoration('Short title', _errors['title']),
          onSubmitted: (_) => _descriptionFocus.requestFocus(),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _description,
          focusNode: _descriptionFocus,
          maxLines: 5,
          maxLength: 1000,
          textInputAction: TextInputAction.done,
          decoration: _decoration('Describe the issue', _errors['description']),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Priority', style: Theme.of(context).textTheme.titleMedium),
        for (final priority in ComplaintPriority.values)
          RadioListTile<ComplaintPriority>(
            value: priority,
            groupValue: _draft.priority,
            onChanged: (value) => setState(() => _draft = _draft.copyWith(priority: value)),
            title: Text(priority.displayLabel),
            subtitle: Text(_priorityHint(priority)),
            contentPadding: EdgeInsets.zero,
          ),
      ],
    ),
  );

  Widget _evidenceStep() => _StepSection(
    title: 'Add evidence',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Photos or videos help the maintenance team arrive prepared.'),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _draft.attachments.length; i++)
              Chip(
                avatar: const Icon(Icons.image_outlined),
                label: Text(_draft.attachments[i].name),
                onDeleted: () => setState(() => _draft = _draft.copyWith(
                  attachments: [..._draft.attachments]..removeAt(i),
                )),
              ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: _addAttachment,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text('Add photo or video (${_draft.attachments.length}/5)'),
        ),
        if (_errors['attachments'] != null) _ErrorText(_errors['attachments']!),
      ],
    ),
  );

  Widget _visitStep() => _StepSection(
    title: 'Plan the visit',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _chooseDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(_draft.preferredVisitDate == null
              ? 'Choose a preferred date (optional)'
              : '${_draft.preferredVisitDate!.day}/${_draft.preferredVisitDate!.month}/${_draft.preferredVisitDate!.year}'),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          value: _draft.preferredVisitSlot,
          decoration: _decoration('Preferred time slot', _errors['visit']),
          items: const ['Morning', 'Afternoon', 'Evening', 'Any time']
              .map((slot) => DropdownMenuItem(value: slot, child: Text(slot))).toList(),
          onChanged: (value) => setState(() => _draft = _draft.copyWith(preferredVisitSlot: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          decoration: _decoration('Contact phone (optional)', _errors['phone']),
        ),
        if (_errors['visit'] != null) _ErrorText(_errors['visit']!),
      ],
    ),
  );

  Widget _reviewStep() => _StepSection(
    title: 'Review complaint',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_duplicate != null) _DuplicateWarning(complaint: _duplicate!),
        _SummaryCard(title: 'Where', value: '${_draft.propertyName}  ›  ${_draft.unitNumber}', onEdit: () => setState(() => _step = 0)),
        _SummaryCard(title: 'What', value: '${_draft.category?.displayLabel}: ${_draft.title}', onEdit: () => setState(() => _step = 1)),
        _SummaryCard(title: 'Evidence', value: '${_draft.attachments.length} attachment(s)', onEdit: () => setState(() => _step = 2)),
        _SummaryCard(title: 'Visit', value: _draft.preferredVisitDate == null ? 'No preferred date' : '${_draft.preferredVisitDate!.day}/${_draft.preferredVisitDate!.month}', onEdit: () => setState(() => _step = 3)),
        if (_submitError != null) ...[
          _ErrorText(_submitError!),
          TextButton.icon(onPressed: _submit, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ],
      ],
    ),
  );

  InputDecoration _decoration(String label, String? error) =>
      InputDecoration(labelText: label, errorText: error, border: const OutlineInputBorder());

  String _priorityHint(ComplaintPriority priority) => switch (priority) {
    ComplaintPriority.low => 'Cosmetic or non-urgent issue',
    ComplaintPriority.medium => 'Routine maintenance issue',
    ComplaintPriority.high => 'Needs attention soon',
    ComplaintPriority.urgent => 'Safety or active damage risk',
  };

  void _reset() {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => CreateComplaintScreen(
        role: widget.role,
        repository: _repository,
        mediaPicker: widget.mediaPicker,
      ),
    ));
  }

  class _Actions extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
      final state = context.findAncestorStateOfType<_CreateComplaintScreenState>()!;
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (state._step > 0) OutlinedButton(onPressed: state._back, child: const Text('Back')),
            const Spacer(),
            FilledButton(
              onPressed: state._loading
                  ? null
                  : state._step == 4 ? state._submit : state._continue,
              child: state._loading
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(state._step == 4 ? 'Submit complaint' : 'Continue'),
            ),
          ],
        ),
      );
    }
  }
}

class _StepSection extends StatelessWidget {
  const _StepSection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: 'Fraunces')),
      const SizedBox(height: AppSpacing.lg),
      child,
    ],
  );
}

class _TopProgress extends StatelessWidget {
  const _TopProgress({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Step ${step + 1} of 5'),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: (step + 1) / 5),
      ],
    ),
  );
}

class _SideStepper extends StatelessWidget {
  const _SideStepper({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 5; i++)
            ListTile(
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: i <= step ? context.palette.accent : context.palette.shimmer,
                child: Text('${i + 1}', style: TextStyle(color: i <= step ? context.palette.surface : context.palette.ink)),
              ),
              title: Text(['Where', 'What', 'Evidence', 'Visit', 'Review'][i]),
            ),
        ],
      ),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(message, style: TextStyle(color: context.palette.danger)),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value, required this.onEdit});
  final String title;
  final String value;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.labelLarge), Text(value)])),
        TextButton(onPressed: onEdit, child: const Text('Edit')),
      ],
    ),
  );
}

class _DuplicateWarning extends StatelessWidget {
  const _DuplicateWarning({required this.complaint});
  final Complaint complaint;
  @override
  Widget build(BuildContext context) => Card(
    color: context.palette.accentSoft,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        children: [
          Text('A similar complaint is already open (${complaint.id}). '),
          TextButton(onPressed: () {}, child: const Text('Open it')),
          const Text(' or continue anyway.'),
        ],
      ),
    ),
  );
}

class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen({required this.complaint, required this.onAnother});
  final Complaint complaint;
  final VoidCallback onAnother;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.canvas,
    appBar: AppBar(title: const Text('Complaint submitted')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: context.palette.success),
            const SizedBox(height: 16),
            Text('Complaint ${complaint.id}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const StatusBadge(label: 'Open', tone: StatusBadgeTone.accent),
            const SizedBox(height: 16),
            const Text('Next: our team will review the details and assign the right technician.\nExpected response: within 24 hours.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: () {}, child: const Text('Track complaint')),
            OutlinedButton(onPressed: onAnother, child: const Text('Raise another')),
          ],
        ),
      ),
    ),
  );
}

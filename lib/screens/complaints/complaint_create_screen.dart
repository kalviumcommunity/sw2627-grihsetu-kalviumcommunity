import 'package:flutter/material.dart';

import '../../core/enums/complaint_category.dart';
import '../../core/enums/complaint_priority.dart';
import '../../core/models/complaint.dart';
import '../../core/models/user.dart';
import '../../repositories/complaint_repository.dart';
import '../../repositories/property_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_spacing.dart';
import '../property/property_selection_flow.dart';

/// Minimal complaint creation surface for the GRIH-013 write workflow.
class ComplaintCreateScreen extends StatefulWidget {
  const ComplaintCreateScreen({
    super.key,
    this.profile,
    this.authService,
    this.complaintRepository,
    this.propertyRepository,
    this.showAppBar = true,
  });

  final AppUser? profile;
  final AuthService? authService;
  final ComplaintRepository? complaintRepository;
  final PropertyRepository? propertyRepository;
  final bool showAppBar;

  @override
  State<ComplaintCreateScreen> createState() => _ComplaintCreateScreenState();
}

class _ComplaintCreateScreenState extends State<ComplaintCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  ComplaintCategory _category = ComplaintCategory.other;
  ComplaintPriority _priority = ComplaintPriority.medium;
  PropertyUnitTenantSelection? _location;
  ComplaintRepository? _repository;
  bool _busy = false;
  String? _error;
  String _submissionId = '';

  ComplaintRepository get _complaintRepository =>
      _repository ??= widget.complaintRepository ??
      FirestoreComplaintRepository(identity: widget.authService);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _chooseLocation() async {
    if (_busy) return;
    final selection = await PropertySelectionFlow.pick(
      context,
      requireTenant: true,
      repository: widget.propertyRepository,
    );
    if (!mounted || selection == null) return;
    setState(() {
      _location = selection;
      _error = null;
    });
  }

  String _stableSubmissionId() {
    if (_submissionId.isEmpty) {
      _submissionId =
          'ui_${identityHashCode(this)}_${DateTime.now().microsecondsSinceEpoch}';
    }
    return _submissionId;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _location == null) {
      setState(() => _error = _location == null
          ? 'Choose a property, unit, and tenant.'
          : null);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _complaintRepository.createComplaint(
        CreateComplaintInput(
          title: _titleController.text,
          description: _descriptionController.text,
          category: _category,
          priority: _priority,
          propertyId: _location!.propertyId,
          unitId: _location!.unitId,
          tenantId: _location!.tenantId!,
          submissionId: _stableSubmissionId(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _submissionId = '';
        _titleController.clear();
        _descriptionController.clear();
        _location = null;
        _category = ComplaintCategory.other;
        _priority = ComplaintPriority.medium;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint submitted successfully.')),
      );
    } on ComplaintFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Unable to submit the complaint. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Register a complaint',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Capture the location and issue so the team can follow it through resolution.',
                style: TextStyle(color: context.palette.muted),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: _busy ? null : _chooseLocation,
                icon: const Icon(Icons.location_on_outlined),
                label: Text(
                  _location == null
                      ? 'Choose property, unit, and tenant'
                      : '${_location!.propertyName} · ${_location!.unitNumber} · ${_location!.tenantName}',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _titleController,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Complaint title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Complaint title is required.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                enabled: !_busy,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Complaint description is required.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<ComplaintCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in ComplaintCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.displayLabel),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<ComplaintPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  for (final priority in ComplaintPriority.values)
                    DropdownMenuItem(
                      value: priority,
                      child: Text(priority.displayLabel),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _priority = value!),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: TextStyle(color: context.palette.danger),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_busy ? 'Submitting…' : 'Submit complaint'),
              ),
            ],
          ),
        ),
      ),
    );

    return widget.showAppBar
        ? Scaffold(
            appBar: AppBar(title: const Text('New complaint')),
            body: SafeArea(child: content),
          )
        : SafeArea(child: content);
  }
}

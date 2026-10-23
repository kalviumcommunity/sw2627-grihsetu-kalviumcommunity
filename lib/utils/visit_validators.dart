import '../screens/complaints/complaint_draft.dart';
import 'validators.dart';

/// Sequential steps in a technician's on-site visit workflow.
enum VisitWorkflowStep {
  accepted('Accepted', 'Accept job'),
  travelling('Travelling', 'Start travel'),
  arrived('Arrived', "I've arrived"),
  inspection('Inspection', 'Start inspection'),
  repairing('Repairing', 'Start repair'),
  completed('Completed', 'Complete visit');

  const VisitWorkflowStep(this.label, this.actionLabel);

  final String label;
  final String actionLabel;

  /// Returns the next sequential step in the workflow, or null if completed.
  VisitWorkflowStep? get nextStep {
    final idx = index;
    if (idx + 1 < VisitWorkflowStep.values.length) {
      return VisitWorkflowStep.values[idx + 1];
    }
    return null;
  }

  /// Event name used in audit logging for this step.
  String get auditEventName => switch (this) {
    VisitWorkflowStep.accepted => 'JOB_ACCEPTED',
    VisitWorkflowStep.travelling => 'TECHNICIAN_TRAVELLING',
    VisitWorkflowStep.arrived => 'TECHNICIAN_ARRIVED',
    VisitWorkflowStep.inspection => 'INSPECTION_STARTED',
    VisitWorkflowStep.repairing => 'REPAIR_STARTED',
    VisitWorkflowStep.completed => 'VISIT_COMPLETED',
  };
}

/// Standard reasons for requesting a follow-up visit.
enum FollowUpReason {
  partNotAvailable('Part not available'),
  needsSpecialist('Needs specialist'),
  accessNotPossible('Access not possible'),
  moreTimeRequired('More time required'),
  other('Other');

  const FollowUpReason(this.label);
  final String label;

  static FollowUpReason? tryFromValue(String? value) {
    if (value == null) return null;
    for (final r in values) {
      if (r.name == value || r.label.toLowerCase() == value.toLowerCase()) {
        return r;
      }
    }
    return null;
  }
}

/// Lightweight part input representation for validation and UI.
class VisitPartInput {
  const VisitPartInput({required this.name, required this.quantity, this.cost});

  final String name;
  final int quantity;
  final double? cost;
}

/// Pure validation functions for technician visits and completion forms.
abstract final class VisitValidators {
  static const int maxPhotosPerGroup = 6;
  static const int maxPhotoSizeBytes = 10 * 1024 * 1024; // 10 MB

  // ==========================================
  // Step Order Rules
  // ==========================================

  /// Validates whether a transition from [current] to [target] is permitted.
  ///
  /// Steps must proceed strictly in order:
  /// Accepted -> Travelling -> Arrived -> Inspection -> Repairing -> Completed.
  /// Going backwards is not allowed.
  /// You cannot complete a visit before "Start repair" (step is repairing).
  static String? validateStepTransition(
    VisitWorkflowStep? current,
    VisitWorkflowStep target,
  ) {
    if (target == VisitWorkflowStep.completed) {
      if (current != VisitWorkflowStep.repairing) {
        return 'You cannot complete a visit before "Start repair".';
      }
      return null;
    }

    if (current == null) {
      if (target != VisitWorkflowStep.accepted) {
        return 'You must accept the job first.';
      }
      return null;
    }

    if (target.index <= current.index) {
      return 'Going backwards in visit workflow is not allowed.';
    }

    if (target.index != current.index + 1) {
      return 'You cannot start a step out of order.';
    }

    return null;
  }

  /// Returns true if [target] is the immediately allowed next step after [current].
  static bool canAdvanceTo(
    VisitWorkflowStep? current,
    VisitWorkflowStep target,
  ) {
    return validateStepTransition(current, target) == null;
  }

  // ==========================================
  // Parts Rules
  // ==========================================

  /// Part name must be 2-60 characters.
  static String? validatePartName(String value) => Validators.requiredText(
    value,
    field: 'Part name',
    minLength: 2,
    maxLength: 60,
    message: 'Part name is required.',
    minLengthError: 'Part name must be at least 2 characters.',
    maxLengthError: 'Part name must be 60 characters or fewer.',
  );

  /// Quantity must be between 1 and 99.
  static String? validatePartQuantity(int quantity) {
    if (quantity < 1 || quantity > 99) {
      return 'Quantity must be between 1 and 99.';
    }
    return null;
  }

  /// Optional cost must be between 0 and 100,000 when given.
  static String? validatePartCost(double? cost) => Validators.amountValue(
    cost,
    field: 'Cost',
    isRequired: false,
    min: 0,
    max: 100000,
    minError: 'Cost must be between 0 and 100,000.',
    maxError: 'Cost must be between 0 and 100,000.',
  );

  /// Parts used rule: repeatable row list; zero parts allowed via [noPartsUsed] checkbox.
  /// One of the two is required.
  static String? validatePartsGroup({
    required List<VisitPartInput> parts,
    required bool noPartsUsed,
  }) {
    if (!noPartsUsed && parts.isEmpty) {
      return 'Specify parts used or check "No parts used".';
    }
    if (noPartsUsed && parts.isNotEmpty) {
      return 'Cannot have parts listed when "No parts used" is checked.';
    }
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      final nameErr = validatePartName(part.name);
      if (nameErr != null) return 'Part #${i + 1}: $nameErr';
      final qtyErr = validatePartQuantity(part.quantity);
      if (qtyErr != null) return 'Part #${i + 1}: $qtyErr';
      final costErr = validatePartCost(part.cost);
      if (costErr != null) return 'Part #${i + 1}: $costErr';
    }
    return null;
  }

  // ==========================================
  // Evidence & Photo Rules
  // ==========================================

  /// At most 6 attachments per group, 10 MB each.
  static String? validateAttachments(List<ComplaintAttachmentStub> items) {
    if (items.length > maxPhotosPerGroup) {
      return 'You can add up to $maxPhotosPerGroup photos.';
    }
    for (final item in items) {
      if (item.sizeBytes > maxPhotoSizeBytes) {
        return 'Each photo must be 10 MB or smaller.';
      }
    }
    return null;
  }

  /// After photos rule for resolved visit: at least 1 required.
  static String? validateAfterPhotos(List<ComplaintAttachmentStub> photos) {
    if (photos.isEmpty) {
      return 'At least 1 "After" photo is required to mark job resolved.';
    }
    return validateAttachments(photos);
  }

  /// Validates photo attachment count up to 6 photos.
  static String? validateAttachmentsCount(int count) {
    if (count > maxPhotosPerGroup) {
      return 'You can add up to $maxPhotosPerGroup photos.';
    }
    return null;
  }

  /// Validates after photos count (at least 1 required, up to 6).
  static String? validateAfterPhotosCount(int count) {
    if (count < 1) {
      return 'At least 1 "After" photo is required to mark job resolved.';
    }
    if (count > maxPhotosPerGroup) {
      return 'You can add up to $maxPhotosPerGroup photos.';
    }
    return null;
  }

  // ==========================================
  // Resolved Outcome Rules
  // ==========================================

  /// What was found: required, 10-500 characters.
  static String? validateFound(String value) => Validators.requiredText(
    value,
    field: 'Description',
    minLength: 10,
    maxLength: 500,
    message: 'Please describe what was found.',
    minLengthError: 'Description must be at least 10 characters.',
    maxLengthError: 'Description must be 500 characters or fewer.',
  );

  /// What was repaired: required, 10-500 characters.
  static String? validateRepaired(String value) => Validators.requiredText(
    value,
    field: 'Description',
    minLength: 10,
    maxLength: 500,
    message: 'Please describe what was repaired.',
    minLengthError: 'Description must be at least 10 characters.',
    maxLengthError: 'Description must be 500 characters or fewer.',
  );

  /// Resolution notes for tenant: required, 20-500 characters.
  static String? validateTenantResolutionNotes(String value) =>
      Validators.requiredText(
        value,
        field: 'Tenant resolution notes',
        minLength: 20,
        maxLength: 500,
        message: 'Tenant resolution notes are required.',
        minLengthError: 'Tenant notes must be at least 20 characters.',
        maxLengthError: 'Tenant notes must be 500 characters or fewer.',
      );

  // ==========================================
  // Needs Another Visit Rules
  // ==========================================

  /// Reason selector is required. If "Other", note of >= 10 chars is required.
  static String? validateFollowUpReason(
    FollowUpReason? reason, {
    String? otherNote,
  }) {
    if (reason == null) {
      return 'Please select a reason for the follow-up visit.';
    }
    if (reason == FollowUpReason.other) {
      return Validators.requiredText(
        otherNote,
        minLength: 10,
        maxLength: 500,
        message: 'Please specify the reason (at least 10 characters).',
        minLengthError: 'Reason note must be at least 10 characters.',
        maxLengthError: 'Reason note must be 500 characters or fewer.',
      );
    }
    return null;
  }

  /// Details note for follow-up: required, 10-500 characters.
  static String? validateFollowUpDetails(String value) =>
      Validators.requiredText(
        value,
        field: 'Follow-up details',
        minLength: 10,
        maxLength: 500,
        message: 'Follow-up details are required.',
        minLengthError: 'Details must be at least 10 characters.',
        maxLengthError: 'Details must be 500 characters or fewer.',
      );

  /// Suggested next visit date: optional, today to +14 days.
  static String? validateSuggestedDate(DateTime? date, {DateTime? today}) =>
      Validators.date(
        date,
        field: 'Suggested date',
        isRequired: false,
        now: today,
        allowPast: false,
        allowToday: true,
        maxDaysAhead: 14,
        pastError: 'Suggested date cannot be in the past.',
        maxDateError: 'Suggested date must be within 14 days.',
      );
}

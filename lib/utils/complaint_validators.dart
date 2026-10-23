import '../core/enums/complaint_priority.dart';
import '../utils/validators.dart';
import '../screens/complaints/complaint_draft.dart';

class ComplaintValidation {
  const ComplaintValidation(this.errors);
  final Map<String, String> errors;
  bool get isValid => errors.isEmpty;
}

abstract final class ComplaintValidators {
  static String? location(ComplaintDraft draft, {bool requireTenant = true}) {
    if (draft.propertyId == null) return 'Choose a property';
    if (draft.unitId == null) return 'Choose a unit';
    if (requireTenant && draft.tenantId == null) return 'Choose a tenant';
    return null;
  }

  static String? category(ComplaintDraft draft) =>
      draft.category == null ? 'Choose a complaint category' : null;

  static String? title(String value) => Validators.requiredText(
    value,
    field: 'Title',
    minLength: 5,
    maxLength: 80,
    message: 'Title is required',
    minLengthError: 'Title must be at least 5 characters',
    maxLengthError: 'Title must be 80 characters or fewer',
  );

  static String? description(
    String value, {
    ComplaintPriority priority = ComplaintPriority.medium,
  }) {
    final minLength = priority == ComplaintPriority.urgent ? 40 : 20;
    final minError = priority == ComplaintPriority.urgent
        ? 'Urgent complaints need at least 40 characters'
        : 'Description must be at least 20 characters';
    return Validators.requiredText(
      value,
      field: 'Description',
      minLength: minLength,
      maxLength: 1000,
      message: 'Description is required',
      minLengthError: minError,
      maxLengthError: 'Description must be 1000 characters or fewer',
    );
  }

  /// Validates complaint reopen reason.
  static String? reopenReason(String? reason) => Validators.requiredText(
    reason,
    message: 'Please select a reason for reopening.',
  );

  /// Validates complaint reopen explanation note (minimum 15 characters).
  static String? reopenExplanation(String? note) => Validators.requiredText(
    note,
    minLength: 15,
    message: 'Note must be at least 15 characters describing the issue.',
    minLengthError: 'Note must be at least 15 characters describing the issue.',
    maxLength: 500,
    maxLengthError: 'Note must be 500 characters or fewer.',
  );

  /// Alias for [reopenExplanation].
  static String? reopenNote(String? note) => reopenExplanation(note);

  static String? attachments(List<ComplaintAttachmentStub> items) {
    if (items.length > 5) return 'You can add up to 5 attachments';
    if (items.any((item) => item.sizeBytes > 10 * 1024 * 1024)) {
      return 'Each attachment must be 10 MB or smaller';
    }
    return null;
  }

  static String? visit(ComplaintDraft draft, {DateTime? today}) {
    final date = draft.preferredVisitDate;
    if (date == null) return null;
    final dateError = Validators.date(
      date,
      field: 'Visit date',
      isRequired: false,
      now: today,
      allowPast: false,
      allowToday: true,
      maxDaysAhead: 14,
      pastError: 'Visit date cannot be in the past',
      maxDateError: 'Visit date must be within the next 14 days',
    );
    if (dateError != null) return dateError;
    if (draft.preferredVisitSlot == null) return 'Choose a preferred time slot';
    return null;
  }

  static String? phone(String value) =>
      value.trim().isEmpty ? null : Validators.phone(value);

  static ComplaintValidation validate(
    ComplaintDraft draft, {
    bool requireTenant = true,
    DateTime? today,
  }) => ComplaintValidation({
    if (location(draft, requireTenant: requireTenant) case final error?)
      'location': error,
    if (category(draft) case final error?) 'category': error,
    if (title(draft.title) case final error?) 'title': error,
    if (description(draft.description, priority: draft.priority)
        case final error?)
      'description': error,
    if (attachments(draft.attachments) case final error?) 'attachments': error,
    if (visit(draft, today: today) case final error?) 'visit': error,
    if (phone(draft.contactPhone) case final error?) 'phone': error,
  });
}

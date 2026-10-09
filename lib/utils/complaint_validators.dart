import '../core/enums/complaint_priority.dart';
import '../core/models/complaint.dart';
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

  static String? title(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Title is required';
    if (trimmed.length < 5) return 'Title must be at least 5 characters';
    if (trimmed.length > 80) return 'Title must be 80 characters or fewer';
    return null;
  }

  static String? description(
    String value, {
    ComplaintPriority priority = ComplaintPriority.medium,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Description is required';
    if (trimmed.length < 20)
      return 'Description must be at least 20 characters';
    if (trimmed.length > 1000)
      return 'Description must be 1000 characters or fewer';
    if (priority == ComplaintPriority.urgent && trimmed.length < 40) {
      return 'Urgent complaints need at least 40 characters';
    }
    return null;
  }

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
    final start = _dateOnly(today ?? DateTime.now());
    final selected = _dateOnly(date);
    if (selected.isBefore(start)) return 'Visit date cannot be in the past';
    if (selected.isAfter(start.add(const Duration(days: 14)))) {
      return 'Visit date must be within the next 14 days';
    }
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

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

import '../core/enums/complaint_category.dart';
import 'validators.dart';

/// Available scheduling time slots.
enum AssignmentSlot {
  morning('Morning', '09:00 AM - 01:00 PM'),
  afternoon('Afternoon', '01:00 PM - 05:00 PM'),
  evening('Evening', '05:00 PM - 08:00 PM');

  const AssignmentSlot(this.label, this.timeRange);

  final String label;
  final String timeRange;
}

/// Standard reasons for reassigning a complaint.
enum ReassignmentReason {
  technicianUnavailable('Technician unavailable'),
  wrongSpecialty('Wrong specialty'),
  workloadBalancing('Workload balancing'),
  repeatIssueNeedsDifferent('Repeat issue, needs a different technician'),
  other('Other');

  const ReassignmentReason(this.label);

  final String label;
}

/// Evaluation result for technician assignment form.
class AssignmentValidationResult {
  const AssignmentValidationResult({
    required this.isValid,
    this.technicianError,
    this.dateError,
    this.slotError,
    this.noteError,
    this.reasonError,
    this.warnings = const <String>[],
  });

  final bool isValid;
  final String? technicianError;
  final String? dateError;
  final String? slotError;
  final String? noteError;
  final String? reasonError;
  final List<String> warnings;

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => !isValid;
}

/// Pure validation functions for assignment & reassignment.
abstract final class AssignmentValidators {
  static const int maxNoteLength = 300;
  static const int maxScheduleDaysAhead = 14;
  static const int highLoadThreshold = 5;

  /// Validates note character limit (0..300 chars).
  static String? validateNote(String? note, {bool isRequired = false}) {
    final trimmed = note?.trim() ?? '';
    if (isRequired && trimmed.isEmpty) {
      return 'A note is required when "Other" is selected.';
    }
    if (trimmed.length > maxNoteLength) {
      return 'Note must be $maxNoteLength characters or fewer (${trimmed.length}/$maxNoteLength).';
    }
    return null;
  }

  /// Validates that visit date is not in past and not beyond 14 days ahead.
  static String? validateVisitDate(DateTime? date, {DateTime? now}) =>
      Validators.date(
        date,
        field: 'Visit date',
        isRequired: false,
        now: now,
        allowPast: false,
        allowToday: true,
        maxDaysAhead: maxScheduleDaysAhead,
        pastError: 'Visit date cannot be in the past.',
        maxDateError:
            'Visit date cannot be more than $maxScheduleDaysAhead days ahead.',
      );

  /// Validates that a slot is selected if a visit date is specified.
  static String? validateSlot(DateTime? date, AssignmentSlot? slot) {
    if (date != null && slot == null) {
      return 'Please select a time slot for the chosen visit date.';
    }
    return null;
  }

  /// Validates technician selection and identity in reassign mode.
  static String? validateTechnician({
    required String? selectedTechnicianId,
    String? currentTechnicianId,
    bool isReassign = false,
  }) {
    final requiredError = Validators.requiredText(
      selectedTechnicianId,
      message: 'Please select a technician.',
    );
    if (requiredError != null) return requiredError;
    if (isReassign &&
        currentTechnicianId != null &&
        selectedTechnicianId!.trim() == currentTechnicianId.trim()) {
      return 'Please select a different technician than the currently assigned one.';
    }
    return null;
  }

  /// Validates reassignment reason.
  static String? validateReassignmentReason({
    required bool isReassign,
    required ReassignmentReason? reason,
    String? note,
  }) {
    if (!isReassign) return null;
    if (reason == null) {
      return 'Please select a reason for reassignment.';
    }
    if (reason == ReassignmentReason.other) {
      final noteTrimmed = note?.trim() ?? '';
      if (noteTrimmed.isEmpty) {
        return 'Please explain the reason in the note.';
      }
    }
    return null;
  }

  /// Generates non-blocking warnings for assignment.
  static List<String> generateWarnings({
    required bool isOffDuty,
    required bool matchesCategory,
    required int todayJobCount,
    ComplaintCategory? complaintCategory,
  }) {
    final warnings = <String>[];
    if (isOffDuty) {
      warnings.add('Technician is currently off duty.');
    }
    if (!matchesCategory && complaintCategory != null) {
      warnings.add(
        'Specialty does not match ${complaintCategory.displayLabel}.',
      );
    }
    if (todayJobCount > highLoadThreshold) {
      warnings.add(
        'High workload: currently assigned $todayJobCount jobs today.',
      );
    }
    return warnings;
  }

  /// Comprehensive assignment validation check.
  static AssignmentValidationResult validateAll({
    required String? selectedTechnicianId,
    String? currentTechnicianId,
    bool isReassign = false,
    DateTime? visitDate,
    AssignmentSlot? slot,
    String? note,
    ReassignmentReason? reason,
    bool isOffDuty = false,
    bool matchesCategory = true,
    int todayJobCount = 0,
    ComplaintCategory? complaintCategory,
    DateTime? now,
  }) {
    final techError = validateTechnician(
      selectedTechnicianId: selectedTechnicianId,
      currentTechnicianId: currentTechnicianId,
      isReassign: isReassign,
    );
    final dateError = validateVisitDate(visitDate, now: now);
    final slotError = validateSlot(visitDate, slot);
    final noteError = validateNote(
      note,
      isRequired: isReassign && reason == ReassignmentReason.other,
    );
    final reasonError = validateReassignmentReason(
      isReassign: isReassign,
      reason: reason,
      note: note,
    );

    final isValid =
        techError == null &&
        dateError == null &&
        slotError == null &&
        noteError == null &&
        reasonError == null;

    final warnings = selectedTechnicianId != null
        ? generateWarnings(
            isOffDuty: isOffDuty,
            matchesCategory: matchesCategory,
            todayJobCount: todayJobCount,
            complaintCategory: complaintCategory,
          )
        : const <String>[];

    return AssignmentValidationResult(
      isValid: isValid,
      technicianError: techError,
      dateError: dateError,
      slotError: slotError,
      noteError: noteError,
      reasonError: reasonError,
      warnings: warnings,
    );
  }
}

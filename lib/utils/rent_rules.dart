import '../core/enums/rent_status.dart';
import '../core/models/rent_record.dart';
import 'app_clock.dart';
import '../screens/rent/rent_models.dart';
import 'validators.dart';

/// Formats a monetary amount into Indian digit grouping with the ₹ currency symbol.
/// Examples: 500 -> ₹500, 25000 -> ₹25,000, 125000 -> ₹1,25,000, 10000000 -> ₹1,00,00,000.
String formatIndianCurrency(num amount) {
  final isNegative = amount < 0;
  final absAmount = amount.abs().round();
  final str = absAmount.toString();
  if (str.length <= 3) {
    return '${isNegative ? '-' : ''}₹$str';
  }
  final last3 = str.substring(str.length - 3);
  final rest = str.substring(0, str.length - 3);
  final formattedRest = rest.replaceAllMapped(
    RegExp(r'\B(?=(\d{2})+(?!\d))'),
    (match) => ',',
  );
  return '${isNegative ? '-' : ''}₹$formattedRest,$last3';
}

/// Checks whether [now] is past the [dueDate].
bool isPastDueDate(DateTime dueDate, DateTime now) {
  if (dueDate.hour == 0 && dueDate.minute == 0 && dueDate.second == 0) {
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final currentDay = DateTime(now.year, now.month, now.day);
    return currentDay.isAfter(dueDay);
  }
  return now.isAfter(dueDate);
}

/// Calculates the remaining unpaid balance for a [RentRecord].
double balance(RentRecord record, [List<PaymentRecord> payments = const []]) {
  final totalPaid = payments.fold<double>(0.0, (sum, p) => sum + p.amount);
  final remaining = record.amountDue - totalPaid;
  return remaining < 0 ? 0.0 : remaining;
}

/// Computes the effective [RentStatus] considering settlement and the due-date boundary.
/// If unpaid and after the due date, it evaluates to [RentStatus.overdue].
RentStatus effectiveStatus(
  RentRecord record,
  DateTime now, [
  List<PaymentRecord> payments = const [],
]) {
  final remainingBalance = balance(record, payments);
  if (record.status == RentStatus.paid || remainingBalance <= 0) {
    return RentStatus.paid;
  }
  if (isPastDueDate(record.dueDate, now)) {
    return RentStatus.overdue;
  }
  if (record.status == RentStatus.overdue) {
    return RentStatus.due;
  }
  return record.status;
}

/// Computes how many days a rent payment is overdue relative to [now].
int daysOverdue(DateTime dueDate, DateTime now) {
  final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final currentDay = DateTime(now.year, now.month, now.day);
  final diff = currentDay.difference(dueDay).inDays;
  return diff > 0 ? diff : 0;
}

/// Counts how many broken promises exist in the [history].
/// A promise is broken if its promised payment date has passed without settlement.
int brokenPromises(List<RentFollowUp> history, [DateTime? now]) {
  final ref = now ?? AppClock.nowDateTime;
  final refDay = DateTime(ref.year, ref.month, ref.day);
  var count = 0;
  for (final followUp in history) {
    if (followUp.outcome == FollowUpOutcome.promisedToPay &&
        followUp.promisedDate != null) {
      final pDate = followUp.promisedDate!;
      final pDay = DateTime(pDate.year, pDate.month, pDate.day);
      final isPast = (pDate.hour == 0 && pDate.minute == 0)
          ? refDay.isAfter(pDay)
          : ref.isAfter(pDate);
      if (isPast) {
        count++;
      }
    }
  }
  return count;
}

/// Validation result container for follow-up submission.
class FollowUpValidationResult {
  const FollowUpValidationResult({
    required this.isValid,
    this.methodError,
    this.outcomeError,
    this.promisedDateError,
    this.promisedAmountError,
    this.noteError,
    this.tenantResponseError,
    this.nextFollowUpDateError,
  });

  final bool isValid;
  final String? methodError;
  final String? outcomeError;
  final String? promisedDateError;
  final String? promisedAmountError;
  final String? noteError;
  final String? tenantResponseError;
  final String? nextFollowUpDateError;

  String? get firstError =>
      methodError ??
      outcomeError ??
      promisedDateError ??
      promisedAmountError ??
      noteError ??
      tenantResponseError ??
      nextFollowUpDateError;
}

/// Validates follow-up form parameters according to GRIH-032 and GRIH-033 rules.
FollowUpValidationResult validateFollowUp({
  FollowUpMethod? method,
  FollowUpOutcome? outcome,
  DateTime? promisedDate,
  double? promisedAmount,
  String? note,
  String? tenantResponse,
  DateTime? nextFollowUpDate,
  required double currentBalance,
  DateTime? now,
}) {
  String? methodError;
  String? outcomeError;
  String? promisedDateError;
  String? promisedAmountError;
  String? noteError;
  String? tenantResponseError;
  String? nextFollowUpDateError;

  final refNow = now ?? AppClock.nowDateTime;

  if (method == null) {
    methodError = 'Follow-up method is required';
  }

  if (outcome == null) {
    outcomeError = 'Follow-up outcome is required';
  }

  // Promise fields validation
  if (outcome == FollowUpOutcome.promisedToPay) {
    promisedDateError = Validators.date(
      promisedDate,
      field: 'Promised date',
      isRequired: true,
      now: refNow,
      allowPast: false,
      allowToday: true,
      maxDaysAhead: 30,
      requiredError: 'Promised date is required',
      pastError: 'Promised date cannot be in the past',
      maxDateError: 'Promised date cannot be more than 30 days ahead',
    );

    promisedAmountError = Validators.amountValue(
      promisedAmount,
      field: 'Promised amount',
      isRequired: true,
      min: 1,
      max: currentBalance,
      requiredError: 'Promised amount is required',
      minError: 'Promised amount must be at least ₹1',
      maxError: 'Promised amount cannot exceed balance',
    );
  }

  // Note validation
  if (outcome == FollowUpOutcome.noAnswer) {
    noteError = Validators.optionalText(
      note,
      field: 'Note',
      maxLength: 300,
      whitespaceError: 'Note cannot contain only whitespace',
      maxLengthError: 'Note cannot exceed 300 characters',
    );
  } else {
    noteError = Validators.requiredText(
      note,
      field: 'Note',
      minLength: 10,
      maxLength: 300,
      message: 'Note is required (at least 10 characters)',
      minLengthError: 'Note must be at least 10 characters',
      maxLengthError: 'Note cannot exceed 300 characters',
    );
  }

  // Tenant response validation (if provided)
  if (tenantResponse != null) {
    tenantResponseError = Validators.optionalText(
      tenantResponse,
      field: 'Tenant response',
      maxLength: 300,
      whitespaceError: 'Tenant response cannot contain only whitespace',
      maxLengthError: 'Tenant response cannot exceed 300 characters',
    );
  }

  // Next follow-up date validation
  if (nextFollowUpDate != null) {
    nextFollowUpDateError = Validators.date(
      nextFollowUpDate,
      field: 'Next follow-up date',
      isRequired: false,
      now: refNow,
      allowPast: false,
      allowToday: false,
      pastError: 'Next follow-up date must be after today',
    );
  }

  final isValid =
      methodError == null &&
      outcomeError == null &&
      promisedDateError == null &&
      promisedAmountError == null &&
      noteError == null &&
      tenantResponseError == null &&
      nextFollowUpDateError == null;

  return FollowUpValidationResult(
    isValid: isValid,
    methodError: methodError,
    outcomeError: outcomeError,
    promisedDateError: promisedDateError,
    promisedAmountError: promisedAmountError,
    noteError: noteError,
    tenantResponseError: tenantResponseError,
    nextFollowUpDateError: nextFollowUpDateError,
  );
}

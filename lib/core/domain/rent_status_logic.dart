import '../enums/rent_status.dart';
import '../models/rent_follow_up.dart';
import '../models/rent_record.dart';

class RentStatusTransitionException implements Exception {
  const RentStatusTransitionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Pure rent workflow policy. Stored status is not replaced by a date-based
/// value when it is CONTACTED or PROMISED; overdue is a derived classification
/// for those cases when the office needs an overdue queue.
abstract final class RentStatusPolicy {
  static const Map<RentStatus, Set<RentStatus>> allowedTransitions = {
    RentStatus.due: {
      RentStatus.due,
      RentStatus.contacted,
      RentStatus.promised,
      RentStatus.overdue,
      RentStatus.paid,
    },
    RentStatus.contacted: {
      RentStatus.contacted,
      RentStatus.promised,
      RentStatus.paid,
    },
    RentStatus.promised: {
      RentStatus.promised,
      RentStatus.contacted,
      RentStatus.paid,
    },
    RentStatus.overdue: {
      RentStatus.overdue,
      RentStatus.contacted,
      RentStatus.promised,
      RentStatus.paid,
    },
    RentStatus.paid: {RentStatus.paid},
  };

  static bool canTransition(RentStatus from, RentStatus to) =>
      allowedTransitions[from]!.contains(to);

  static void validateTransition(RentStatus from, RentStatus to) {
    if (!canTransition(from, to)) {
      throw RentStatusTransitionException(
        'Rent status cannot change from ${from.value} to ${to.value}.',
      );
    }
  }

  static RentStatus statusForFollowUp({
    required RentStatus current,
    required RentFollowUpInput input,
  }) {
    final next = input.promisedPaymentDate == null
        ? RentStatus.contacted
        : RentStatus.promised;
    validateTransition(current, next);
    return next;
  }

  static RentStatus statusForDueDate(RentRecord record, {DateTime? asOf}) {
    if (record.status == RentStatus.paid ||
        record.status == RentStatus.contacted ||
        record.status == RentStatus.promised) {
      return record.status;
    }
    return isPastDue(record.dueDate, asOf ?? DateTime.now())
        ? RentStatus.overdue
        : record.status;
  }

  static bool isPastDue(DateTime dueDate, DateTime asOf) {
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    return today.isAfter(due);
  }

  static bool isFollowUpDueToday(DateTime? nextFollowUpAt, DateTime today) {
    if (nextFollowUpAt == null) return false;
    return nextFollowUpAt.year == today.year &&
        nextFollowUpAt.month == today.month &&
        nextFollowUpAt.day == today.day;
  }
}

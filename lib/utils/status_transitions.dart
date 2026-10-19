import '../app/user_role.dart';
import '../core/enums/complaint_status.dart';

/// Pure status transition rules and reasoning for GrihSetu complaints.
abstract final class StatusTransitions {
  static const int tenantReopenWindowDays = 7;

  /// Returns whether a closed complaint is beyond the allowable reopen window.
  static bool isReopenWindowExpired(
    DateTime? closedAt, {
    DateTime? referenceNow,
    int maxDays = tenantReopenWindowDays,
  }) {
    if (closedAt == null) return false;
    final now = referenceNow ?? DateTime.now();
    return now.difference(closedAt).inDays > maxDays;
  }
}

/// Returns the set of statuses [role] may transition this complaint to from [from].
Set<ComplaintStatus> allowedNext(
  ComplaintStatus from,
  UserRole role, {
  DateTime? closedAt,
  DateTime? referenceNow,
}) {
  if (from == ComplaintStatus.cancelled) {
    return const <ComplaintStatus>{};
  }

  switch (role) {
    case UserRole.owner:
      return const <ComplaintStatus>{};

    case UserRole.technician:
      return switch (from) {
        ComplaintStatus.inProgress => const {ComplaintStatus.waitingForParts},
        ComplaintStatus.waitingForParts => const {ComplaintStatus.inProgress},
        _ => const <ComplaintStatus>{},
      };

    case UserRole.tenant:
      return switch (from) {
        ComplaintStatus.resolved => const {ComplaintStatus.reopened},
        ComplaintStatus.closed =>
          StatusTransitions.isReopenWindowExpired(
            closedAt,
            referenceNow: referenceNow,
          )
              ? const <ComplaintStatus>{}
              : const {ComplaintStatus.reopened},
        _ => const <ComplaintStatus>{},
      };

    case UserRole.staff:
      return switch (from) {
        ComplaintStatus.open => const {ComplaintStatus.cancelled},
        ComplaintStatus.assigned => const {ComplaintStatus.cancelled},
        ComplaintStatus.resolved => const {
          ComplaintStatus.closed,
          ComplaintStatus.reopened,
        },
        ComplaintStatus.closed =>
          StatusTransitions.isReopenWindowExpired(
            closedAt,
            referenceNow: referenceNow,
          )
              ? const <ComplaintStatus>{}
              : const {ComplaintStatus.reopened},
        _ => const <ComplaintStatus>{},
      };
  }
}

/// Returns a user-friendly tooltip message explaining why a transition is disallowed,
/// or `null` if the transition is allowed.
String? whyNot(
  ComplaintStatus from,
  ComplaintStatus to,
  UserRole role, {
  DateTime? closedAt,
  DateTime? referenceNow,
}) {
  if (allowedNext(
    from,
    role,
    closedAt: closedAt,
    referenceNow: referenceNow,
  ).contains(to)) {
    return null;
  }

  if (from == ComplaintStatus.cancelled) {
    return 'Cancelled complaints cannot be changed.';
  }

  if (role == UserRole.owner) {
    return 'Owners have view-only access and cannot change complaint status.';
  }

  if (to == ComplaintStatus.reopened) {
    if (from != ComplaintStatus.resolved && from != ComplaintStatus.closed) {
      return 'Complaints can only be reopened from resolved or closed status.';
    }
    if (from == ComplaintStatus.closed &&
        StatusTransitions.isReopenWindowExpired(
          closedAt,
          referenceNow: referenceNow,
        )) {
      return 'Reopen window has expired (within 7 days of closing only).';
    }
    if (role == UserRole.technician) {
      return 'Technicians cannot reopen complaints.';
    }
  }

  if (to == ComplaintStatus.closed) {
    if (from != ComplaintStatus.resolved) {
      return 'Complaints can only be closed from resolved status.';
    }
    if (role != UserRole.staff) {
      return 'Only staff members can close complaints.';
    }
  }

  if (to == ComplaintStatus.waitingForParts) {
    if (from != ComplaintStatus.inProgress) {
      return 'Complaints can only be placed on hold for parts while work is in progress.';
    }
    if (role != UserRole.technician) {
      return 'Only technicians can place a complaint on hold for parts.';
    }
  }

  if (to == ComplaintStatus.inProgress) {
    if (from != ComplaintStatus.waitingForParts) {
      return 'Can only resume work from waiting for parts status.';
    }
    if (role != UserRole.technician) {
      return 'Only technicians can resume work.';
    }
  }

  if (to == ComplaintStatus.cancelled) {
    if (from != ComplaintStatus.open && from != ComplaintStatus.assigned) {
      return 'Complaints can only be cancelled while open or assigned.';
    }
    if (role != UserRole.staff) {
      return 'Only staff members can cancel complaints.';
    }
  }

  return 'Transition from ${from.displayLabel} to ${to.displayLabel} is not allowed for ${role.name}.';
}

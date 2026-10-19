import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/domain/complaint_transition_guard.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';

void main() {
  group('ComplaintTransitionGuard', () {
    test('accepts every documented lifecycle transition', () {
      final expected = <ComplaintStatus, Set<ComplaintStatus>>{
        ComplaintStatus.open: {
          ComplaintStatus.assigned,
          ComplaintStatus.cancelled,
        },
        ComplaintStatus.assigned: {
          ComplaintStatus.inProgress,
          ComplaintStatus.cancelled,
        },
        ComplaintStatus.inProgress: {
          ComplaintStatus.waitingForParts,
          ComplaintStatus.resolved,
        },
        ComplaintStatus.waitingForParts: {
          ComplaintStatus.inProgress,
          ComplaintStatus.cancelled,
        },
        ComplaintStatus.resolved: {
          ComplaintStatus.closed,
          ComplaintStatus.reopened,
        },
        ComplaintStatus.closed: {ComplaintStatus.reopened},
        ComplaintStatus.reopened: {
          ComplaintStatus.assigned,
          ComplaintStatus.inProgress,
          ComplaintStatus.cancelled,
        },
        ComplaintStatus.cancelled: {},
      };

      for (final from in ComplaintStatus.values) {
        for (final to in ComplaintStatus.values) {
          expect(
            ComplaintTransitionGuard.canTransition(from, to),
            expected[from]!.contains(to),
            reason: '${from.value} -> ${to.value}',
          );
        }
      }
    });

    test('rejects self transitions and direct closure', () {
      expect(
        () => ComplaintTransitionGuard.validateTransition(
          ComplaintStatus.resolved,
          ComplaintStatus.resolved,
        ),
        throwsA(isA<InvalidComplaintTransition>()),
      );
      expect(
        () => ComplaintTransitionGuard.validateTransition(
          ComplaintStatus.inProgress,
          ComplaintStatus.closed,
        ),
        throwsA(isA<InvalidComplaintTransition>()),
      );
      expect(
        () => ComplaintTransitionGuard.validateTransition(
          ComplaintStatus.cancelled,
          ComplaintStatus.reopened,
        ),
        throwsA(isA<InvalidComplaintTransition>()),
      );
    });
  });
}

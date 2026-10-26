import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/complaint_store.dart';
import '../utils/consistency_rules.dart';

/// Debug-only background monitor that validates data consistency invariants
/// after each [ComplaintStore] emission and prints violations to debugPrint.
///
/// Guaranteed never to crash in production release mode.
class ConsistencyMonitor {
  ConsistencyMonitor({ComplaintStore? store})
    : _store = store ?? ComplaintStore.instance;

  static ConsistencyMonitor? _instance;

  /// Global singleton instance.
  static ConsistencyMonitor get instance => _instance ??= ConsistencyMonitor();

  final ComplaintStore _store;
  StreamSubscription<dynamic>? _subscription;

  /// Begins listening to store emissions under [kDebugMode].
  void start() {
    if (!kDebugMode) return;
    _subscription?.cancel();
    _subscription = _store.watchAll().listen((_) {
      final violations = checkConsistency();
      if (violations.isNotEmpty) {
        final buffer = StringBuffer(
          '⚠️ [ConsistencyMonitor] Detected ${violations.length} consistency violations:\n',
        );
        for (final v in violations) {
          buffer.writeln(
            '  - [${v.rule}] (cmp: ${v.complaintId}): ${v.detail}',
          );
        }
        debugPrint(buffer.toString());
      }
    });
  }

  /// Synchronously evaluates current consistency rules against all complaints.
  List<Violation> checkConsistency() {
    final complaints = _store.snapshot;
    final events = _store.allEvents;
    return ConsistencyRules.validateAll(
      complaints,
      eventsByComplaintId: events,
    );
  }

  /// Stops listening to store emissions.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}

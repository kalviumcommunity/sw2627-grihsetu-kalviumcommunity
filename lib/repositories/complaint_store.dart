import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/fixtures/sample_fixtures.dart';
import '../core/models/complaint.dart';
import '../core/models/complaint_audit_event.dart';
import '../services/consistency_monitor.dart';
import '../services/errors/app_failure.dart';
import '../services/errors/firebase_error_mapper.dart';
import '../utils/app_clock.dart';
import '../utils/complaint_query.dart';
import '../utils/consistency_rules.dart';
import 'streams/replay_stream.dart';

/// Central canonical reactive in-memory store for complaints.
///
/// Provides single-source-of-truth semantics across complaint lists, search
/// views, detail controllers, technician assignment queues, and operations
/// dashboards.
///
/// Features:
/// - Replays the latest snapshot to late subscribers immediately.
/// - Exposes reactive streams for all complaints, single complaint, and filtered queries.
/// - Supports optimistic updates with automatic rollback when server writes fail.
/// - Transactional write helper validating consistency rules before emitting.
/// - Optimistic version checking detecting stale writes.
/// - Idempotency key tracking preventing duplicate submissions.
/// - Collision-free ID generation.
/// - Injectable [AppClock].
class ComplaintStore {
  ComplaintStore({
    List<Complaint>? initialComplaints,
    Map<String, List<ComplaintAuditEvent>>? initialEvents,
    AppClock? clock,
  }) : clock = clock ?? AppClock.current {
    final seed = initialComplaints ?? SampleFixtures.sampleComplaints;
    for (final complaint in seed) {
      _complaints[complaint.id] = complaint;
      _versions[complaint.id] = 1;
    }
    if (initialEvents != null) {
      for (final entry in initialEvents.entries) {
        _events[entry.key] = List.from(entry.value);
      }
    }
    _allStream = ReplayStream<List<Complaint>>(
      initialValue: _complaints.values.toList(growable: false),
    );
    if (kDebugMode) {
      ConsistencyMonitor.instance.start();
    }
  }

  static ComplaintStore? _instance;

  /// The active global singleton store instance.
  static ComplaintStore get instance => _instance ??= ComplaintStore();

  /// Sets or overrides the active singleton instance (useful for testing).
  static set instance(ComplaintStore store) {
    _instance = store;
  }

  /// Resets the active singleton instance, disposing the previous one.
  static void resetInstance([ComplaintStore? replacement]) {
    _instance?.dispose();
    _instance = replacement;
  }

  /// Injectable clock for all timestamps and ID generation.
  final AppClock clock;

  final Map<String, Complaint> _complaints = <String, Complaint>{};
  final Map<String, List<ComplaintAuditEvent>> _events =
      <String, List<ComplaintAuditEvent>>{};
  final Map<String, int> _versions = <String, int>{};
  final Set<String> _processedIdempotencyKeys = <String>{};
  final Map<String, Complaint> _idempotentResults = <String, Complaint>{};
  final Map<String, ReplayStream<List<ComplaintAuditEvent>>> _eventStreams = {};

  int _idCounter = 0;
  late final ReplayStream<List<Complaint>> _allStream;
  bool _isDisposed = false;

  /// Returns whether this store has been disposed.
  bool get isDisposed => _isDisposed;

  /// Returns an immutable snapshot list of all complaints currently in store.
  List<Complaint> get snapshot => _complaints.values.toList(growable: false);

  /// Returns an immutable snapshot of all events grouped by complaint ID.
  Map<String, List<ComplaintAuditEvent>> get allEvents => Map.unmodifiable(
    _events.map((k, v) => MapEntry(k, List.unmodifiable(v))),
  );

  /// Generates a collision-free ID using timestamp and monotonic sequence.
  String generateId({String prefix = 'cmp'}) {
    final timestamp = clock.now().millisecondsSinceEpoch;
    final seq = (++_idCounter).toRadixString(36);
    return '${prefix}_${timestamp}_$seq';
  }

  /// Returns the current version for [complaintId], defaulting to 1.
  int getVersion(String complaintId) => _versions[complaintId] ?? 1;

  /// Returns the current complaint matching [id], or null if not found.
  Complaint? getById(String id) => _complaints[id];

  /// Returns the audit events recorded for [complaintId].
  List<ComplaintAuditEvent> getEvents(String complaintId) =>
      List.unmodifiable(_events[complaintId] ?? const <ComplaintAuditEvent>[]);

  /// Sets or updates audit events for [complaintId].
  void setEvents(String complaintId, List<ComplaintAuditEvent> events) {
    _events[complaintId] = List.from(events);
    _eventStreams[complaintId]?.add(List.unmodifiable(_events[complaintId]!));
  }

  /// Watches all complaints as a real-time reactive stream.
  Stream<List<Complaint>> watchAll() => _allStream.stream;

  /// Watches a single complaint by its [id].
  Stream<Complaint?> watch(String id) {
    return _allStream.stream.map((list) {
      try {
        return list.firstWhere((c) => c.id == id);
      } catch (_) {
        return null;
      }
    }).distinct();
  }

  /// Watches complaints matching [filter], replaying immediately and updating
  /// when matching complaints change.
  Stream<List<Complaint>> watchFiltered(ComplaintFilter filter) {
    return _allStream.stream
        .map((list) => applyFilter(list, filter))
        .distinct(listEquals);
  }

  /// Watches audit events for a single complaint.
  Stream<List<ComplaintAuditEvent>> watchEvents(String complaintId) {
    var stream = _eventStreams[complaintId];
    if (stream == null) {
      stream = ReplayStream<List<ComplaintAuditEvent>>(
        initialValue: getEvents(complaintId),
      );
      _eventStreams[complaintId] = stream;
    }
    return stream.stream;
  }

  /// Adds or updates a single complaint in the store and broadcasts to subscribers.
  void addOrUpdate(Complaint complaint) {
    if (_isDisposed) return;
    _complaints[complaint.id] = complaint;
    _versions[complaint.id] = (_versions[complaint.id] ?? 0) + 1;
    _notify();
  }

  /// Adds or updates a batch of complaints in the store and broadcasts once.
  void addOrUpdateAll(Iterable<Complaint> complaints) {
    if (_isDisposed) return;
    for (final c in complaints) {
      _complaints[c.id] = c;
      _versions[c.id] = (_versions[c.id] ?? 0) + 1;
    }
    _notify();
  }

  /// Removes a complaint by [id] and broadcasts to subscribers.
  void remove(String id) {
    if (_isDisposed) return;
    if (_complaints.remove(id) != null) {
      _events.remove(id);
      _versions.remove(id);
      _notify();
    }
  }

  /// Replaces the entire store contents with [newComplaints].
  void replaceAll(Iterable<Complaint> newComplaints) {
    if (_isDisposed) return;
    _complaints.clear();
    for (final c in newComplaints) {
      _complaints[c.id] = c;
      _versions[c.id] = 1;
    }
    _notify();
  }

  /// Atomically applies a complaint modification and audit events.
  ///
  /// Invariants are validated via [ConsistencyRules.validateComplaint] BEFORE
  /// state is committed and emitted to stream subscribers.
  ///
  /// If [expectedVersion] is supplied and does not match the current version,
  /// throws an [AppFailure] conflict via [FirebaseErrorMapper].
  ///
  /// If [idempotencyKey] is supplied and was already processed, returns the
  /// previously stored complaint without duplicate side-effects.
  ///
  /// If validation fails, rolls back all changes in memory and throws a [ValidationFailure].
  Complaint transactionWrite({
    required String complaintId,
    required Complaint Function(Complaint? current) mutation,
    List<ComplaintAuditEvent> newEvents = const [],
    int? expectedVersion,
    String? idempotencyKey,
  }) {
    if (_isDisposed) {
      throw StateError('Cannot write to disposed ComplaintStore');
    }

    // Idempotency check: duplicate submit returns previously produced record
    if (idempotencyKey != null &&
        _processedIdempotencyKeys.contains(idempotencyKey)) {
      final existing =
          _idempotentResults[idempotencyKey] ?? _complaints[complaintId];
      if (existing != null) return existing;
    }

    // Optimistic concurrency version check
    final currentVersion = _versions[complaintId] ?? 1;
    if (expectedVersion != null && expectedVersion != currentVersion) {
      throw FirebaseErrorMapper.map(
        const ConflictFailure(
          userMessage: 'This complaint was modified by another operation. Please refresh.',
          code: 'conflict',
        ),
      );
    }

    // Snapshot current state for rollback
    final prevComplaint = _complaints[complaintId];
    final prevEvents = _events[complaintId] != null
        ? List<ComplaintAuditEvent>.from(_events[complaintId]!)
        : <ComplaintAuditEvent>[];
    final prevVersion = currentVersion;

    // Apply mutation optimistically in memory
    final updatedComplaint = mutation(prevComplaint);
    final updatedEvents = [...prevEvents, ...newEvents];

    // Validate invariants BEFORE emitting
    final violations = ConsistencyRules.validateComplaint(
      updatedComplaint,
      updatedEvents,
    );

    if (violations.isNotEmpty) {
      // Roll back
      if (prevComplaint != null) {
        _complaints[complaintId] = prevComplaint;
      } else {
        _complaints.remove(complaintId);
      }
      _events[complaintId] = prevEvents;
      _versions[complaintId] = prevVersion;

      throw ValidationFailure(
        userMessage:
            'Data consistency check failed: ${violations.first.detail}',
        original: violations,
      );
    }

    // Commit state
    _complaints[complaintId] = updatedComplaint;
    _events[complaintId] = updatedEvents;
    _versions[complaintId] = prevVersion + 1;
    if (idempotencyKey != null) {
      _processedIdempotencyKeys.add(idempotencyKey);
      _idempotentResults[idempotencyKey] = updatedComplaint;
    }

    _eventStreams[complaintId]?.add(List.unmodifiable(updatedEvents));
    _notify();
    return updatedComplaint;
  }

  /// Performs an optimistic mutation on complaint [id].
  Future<Complaint> optimisticUpdate(
    String id,
    Complaint Function(Complaint current) update,
    Future<void> Function() serverWrite,
  ) async {
    final current = _complaints[id];
    if (current == null) {
      throw StateError(
        'Cannot optimistically update non-existent complaint: $id',
      );
    }

    final optimistic = update(current);
    _complaints[id] = optimistic;
    _notify();

    try {
      await serverWrite();
      return optimistic;
    } catch (e) {
      // Roll back to previous canonical state
      _complaints[id] = current;
      _notify();
      rethrow;
    }
  }

  void _notify() {
    if (_isDisposed) return;
    _allStream.add(_complaints.values.toList(growable: false));
  }

  /// Disposes the store and releases its stream controllers.
  void dispose() {
    _isDisposed = true;
    _allStream.close();
    for (final stream in _eventStreams.values) {
      stream.close();
    }
    _eventStreams.clear();
  }
}

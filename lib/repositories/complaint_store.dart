import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/fixtures/sample_fixtures.dart';
import '../core/models/complaint.dart';
import '../utils/complaint_query.dart';
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
/// - Prepared for future Firestore snapshot listeners via documented extension points.
class ComplaintStore {
  ComplaintStore({List<Complaint>? initialComplaints}) {
    final seed = initialComplaints ?? SampleFixtures.sampleComplaints;
    for (final complaint in seed) {
      _complaints[complaint.id] = complaint;
    }
    _allStream = ReplayStream<List<Complaint>>(
      initialValue: _complaints.values.toList(growable: false),
    );
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

  final Map<String, Complaint> _complaints = <String, Complaint>{};
  late final ReplayStream<List<Complaint>> _allStream;
  bool _isDisposed = false;

  /// Returns whether this store has been disposed.
  bool get isDisposed => _isDisposed;

  /// Returns an immutable snapshot list of all complaints currently in store.
  List<Complaint> get snapshot => _complaints.values.toList(growable: false);

  /// Returns the current complaint matching [id], or null if not found.
  Complaint? getById(String id) => _complaints[id];

  /// Watches all complaints as a real-time reactive stream.
  ///
  /// Replays the current snapshot immediately to new subscribers.
  ///
  /// // TODO: Firestore snapshots()
  /// // Future integration: merge FirebaseFirestore.instance.collection('complaints').snapshots()
  Stream<List<Complaint>> watchAll() => _allStream.stream;

  /// Watches a single complaint by its [id].
  ///
  /// Replays the current complaint state immediately to late subscribers.
  /// Emits updates whenever this specific complaint changes, suppressing
  /// emissions if unrelated complaints in the store are modified.
  ///
  /// // TODO: Firestore snapshots()
  /// // Future integration: FirebaseFirestore.instance.collection('complaints').doc(id).snapshots()
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
  ///
  /// Filters are evaluated reactively against the canonical store snapshot.
  ///
  /// // TODO: Firestore snapshots()
  /// // Future integration: map query constraints to Firestore query.where(...)
  Stream<List<Complaint>> watchFiltered(ComplaintFilter filter) {
    return _allStream.stream
        .map((list) => applyFilter(list, filter))
        .distinct(listEquals);
  }

  /// Adds or updates a single complaint in the store and broadcasts to subscribers.
  void addOrUpdate(Complaint complaint) {
    if (_isDisposed) return;
    _complaints[complaint.id] = complaint;
    _notify();
  }

  /// Adds or updates a batch of complaints in the store and broadcasts once.
  void addOrUpdateAll(Iterable<Complaint> complaints) {
    if (_isDisposed) return;
    for (final c in complaints) {
      _complaints[c.id] = c;
    }
    _notify();
  }

  /// Removes a complaint by [id] and broadcasts to subscribers.
  void remove(String id) {
    if (_isDisposed) return;
    if (_complaints.remove(id) != null) {
      _notify();
    }
  }

  /// Replaces the entire store contents with [newComplaints].
  void replaceAll(Iterable<Complaint> newComplaints) {
    if (_isDisposed) return;
    _complaints.clear();
    for (final c in newComplaints) {
      _complaints[c.id] = c;
    }
    _notify();
  }

  /// Performs an optimistic mutation on complaint [id].
  ///
  /// 1. Immediately updates the in-memory store using [update] and broadcasts
  ///    the optimistic state to all active stream subscribers.
  /// 2. Awaits the asynchronous [serverWrite] operation.
  /// 3. If [serverWrite] succeeds, returns the updated complaint.
  /// 4. If [serverWrite] throws an error, rolls back the complaint to its
  ///    previous state, broadcasts the rollback to all subscribers, and re-throws.
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
  }
}

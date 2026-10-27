import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/enums/complaint_audit_event_type.dart';
import '../../../core/enums/complaint_priority.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/models/complaint.dart';
import '../../../core/models/complaint_audit_event.dart';
import '../../../core/models/maintenance_visit.dart';
import '../../../repositories/complaint_repository.dart';
import '../../../services/complaint_lifecycle_service.dart';
import '../../../services/errors/firebase_error_mapper.dart';
import '../../../utils/visit_validators.dart';
import 'complaint_detail_models.dart';

/// Single source of truth controller for a complaint and its audit trail.
///
/// Listens to [ComplaintRepository.watchComplaint] and [ComplaintRepository.watchAuditEvents].
/// Any mutation is dispatched through the repository, which appends an event.
/// The controller reacts to the stream update and publishes an updated
/// immutable [ComplaintDetailState].
class ComplaintDetailController extends ChangeNotifier {
  ComplaintDetailController({
    required this.complaintId,
    required this.repository,
    Complaint? initialComplaint,
    List<ActivityEvent>? initialEvents,
    this.currentUserId = 'usr_001',
    this.currentUserName = 'Riya Sharma',
    this.currentUserRole = 'Operations Staff',
    DateTime? referenceNow,
  }) : _referenceNow = referenceNow,
       _state = initialComplaint != null
           ? ComplaintDetailState(
               status: ComplaintDetailStatus.data,
               complaint: initialComplaint,
               events: (initialEvents != null && initialEvents.isNotEmpty)
                   ? initialEvents
                   : _buildDefaultInitialEvents(initialComplaint),
               visits: const <MaintenanceVisit>[],
               referenceNow: referenceNow,
             )
           : const ComplaintDetailState(status: ComplaintDetailStatus.loading) {
    if (initialComplaint != null) {
      _latestComplaint = initialComplaint;
      _latestEvents = _state.events;
      if (repository is InMemoryComplaintRepository) {
        (repository as InMemoryComplaintRepository).seedComplaint(
          initialComplaint,
        );
      }
    }
    _initStreams();
  }

  static List<ActivityEvent> _buildDefaultInitialEvents(Complaint c) {
    final list = <ActivityEvent>[
      ActivityEvent(
        id: '${c.id}_created',
        complaintId: c.id,
        type: ActivityEventType.created,
        actorId: c.createdBy,
        actorName: 'Priya Patel',
        actorRole: 'Tenant',
        timestamp: c.createdAt ?? DateTime.now(),
        note: 'Reported via GrihSetu tenant portal.',
      ),
    ];
    if (c.currentTechnicianId != null && c.currentTechnicianId!.isNotEmpty) {
      list.add(
        ActivityEvent(
          id: '${c.id}_assigned',
          complaintId: c.id,
          type: ActivityEventType.assigned,
          actorId: 'usr_staff_01',
          actorName: 'Riya Sharma',
          actorRole: 'Operations Staff',
          timestamp:
              c.firstAssignedAt ??
              (c.createdAt != null
                  ? c.createdAt!.add(const Duration(hours: 1))
                  : DateTime.now()),
          note: 'Assigned to technician.',
          metadata: {
            'technicianId': c.currentTechnicianId,
            'technicianName': c.currentTechnicianId == 'usr_002'
                ? 'Aman Verma'
                : 'Assigned Technician',
          },
        ),
      );
    }
    if (c.status == ComplaintStatus.resolved || c.resolvedAt != null) {
      list.add(
        ActivityEvent(
          id: '${c.id}_resolved',
          complaintId: c.id,
          type: ActivityEventType.markedResolved,
          actorId: c.currentTechnicianId ?? 'usr_002',
          actorName: c.currentTechnicianId == 'usr_002'
              ? 'Aman Verma'
              : 'Technician',
          actorRole: 'Technician',
          timestamp:
              c.resolvedAt ??
              (c.firstAssignedAt != null
                  ? c.firstAssignedAt!.add(const Duration(hours: 4))
                  : DateTime.now()),
          note: 'Issue resolved on site.',
        ),
      );
    } else if (c.status == ComplaintStatus.closed || c.closedAt != null) {
      list.add(
        ActivityEvent(
          id: '${c.id}_closed',
          complaintId: c.id,
          type: ActivityEventType.closed,
          actorId: c.createdBy,
          actorName: 'Priya Patel',
          actorRole: 'Tenant',
          timestamp: c.closedAt ?? DateTime.now(),
          note: 'Resolution verified and closed.',
        ),
      );
    }
    return list;
  }

  final String complaintId;
  final ComplaintRepository repository;
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole;
  final DateTime? _referenceNow;

  ComplaintDetailState _state;
  ComplaintDetailState get state => _state;

  StreamSubscription<Complaint?>? _complaintSub;
  StreamSubscription<List<ComplaintAuditEvent>>? _eventsSub;
  StreamSubscription<List<MaintenanceVisit>>? _visitsSub;

  Complaint? _latestComplaint;
  List<ActivityEvent> _latestEvents = const [];
  List<MaintenanceVisit> _latestVisits = const [];
  bool _isDisposed = false;

  Stream<List<MaintenanceVisit>> _watchMaintenanceVisits() {
    if (repository is FirestoreComplaintRepository ||
        repository is InMemoryComplaintRepository) {
      return repository.watchMaintenanceVisits(complaintId);
    }
    return Stream<List<MaintenanceVisit>>.value(const <MaintenanceVisit>[]);
  }

  void _initStreams() {
    _complaintSub = repository
        .watchComplaint(complaintId)
        .listen(
          (complaint) {
            if (_isDisposed) return;
            if (complaint == null) {
              if (_latestComplaint == null) {
                _updateState(
                  const ComplaintDetailState(
                    status: ComplaintDetailStatus.notFound,
                  ),
                );
              }
            } else {
              _latestComplaint = complaint;
              _updateState(
                ComplaintDetailState(
                  status: ComplaintDetailStatus.data,
                  complaint: _latestComplaint,
                  events: _latestEvents,
                  visits: _latestVisits,
                  referenceNow: _referenceNow,
                ),
              );
            }
          },
          onError: (Object error) {
            if (_isDisposed) return;
            _updateState(
              ComplaintDetailState(
                status: ComplaintDetailStatus.error,
                errorMessage: FirebaseErrorMapper.map(error).userMessage,
              ),
            );
          },
        );

    _eventsSub = repository
        .watchAuditEvents(complaintId)
        .listen(
          (auditEvents) {
            if (_isDisposed) return;
            if (auditEvents.isNotEmpty) {
              final seenIds = <String>{};
              _latestEvents = auditEvents
                  .where((a) => seenIds.add(a.id))
                  .map((a) => ActivityEvent.fromAuditEvent(a))
                  .toList();
            } else if (_latestEvents.isEmpty && _latestComplaint != null) {
              _latestEvents = _buildDefaultInitialEvents(_latestComplaint!);
            }
            if (_latestComplaint != null) {
              _updateState(
                ComplaintDetailState(
                  status: ComplaintDetailStatus.data,
                  complaint: _latestComplaint,
                  events: _latestEvents,
                  visits: _latestVisits,
                  referenceNow: _referenceNow,
                ),
              );
            }
          },
          onError: (Object error) {
            if (_isDisposed) return;
            if (_latestComplaint == null) {
              _updateState(
                ComplaintDetailState(
                  status: ComplaintDetailStatus.error,
                  errorMessage: FirebaseErrorMapper.map(error).userMessage,
                ),
              );
            }
          },
        );

    _visitsSub = _watchMaintenanceVisits().listen(
      (visits) {
        if (_isDisposed) return;
        _latestVisits = visits;
        if (_latestComplaint != null) {
          _updateState(
            ComplaintDetailState(
              status: ComplaintDetailStatus.data,
              complaint: _latestComplaint,
              events: _latestEvents,
              visits: _latestVisits,
              referenceNow: _referenceNow,
            ),
          );
        }
      },
      onError: (Object error) {
        if (_isDisposed || _latestComplaint == null) return;
        _updateState(
          ComplaintDetailState(
            status: ComplaintDetailStatus.data,
            complaint: _latestComplaint,
            events: _latestEvents,
            visits: _latestVisits,
            errorMessage: FirebaseErrorMapper.map(error).userMessage,
            referenceNow: _referenceNow,
          ),
        );
      },
    );
  }

  void _updateState(ComplaintDetailState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Reloads data by re-fetching and resetting subscriptions.
  Future<void> retry() async {
    _updateState(
      const ComplaintDetailState(status: ComplaintDetailStatus.loading),
    );
    await _complaintSub?.cancel();
    await _eventsSub?.cancel();
    await _visitsSub?.cancel();
    _initStreams();
  }

  /// Assigns or reassigns technician via repository.
  Future<void> assignTechnician(
    String technicianId, {
    String? technicianName,
    String? notes,
    String? reason,
    DateTime? scheduledDate,
    String? timeSlot,
    String? role,
    String? actorId,
  }) async {
    final updated = await repository.assignComplaintTechnician(
      complaintId,
      technicianId,
      actorId: actorId ?? currentUserId,
      reason: reason ?? notes,
      role: role ?? currentUserRole,
      scheduledDate: scheduledDate,
      timeSlot: timeSlot,
    );
    _latestComplaint = updated;
    final repoEvents = await repository.loadAuditEvents(complaintId);
    if (repoEvents.isNotEmpty) {
      final seenIds = <String>{};
      _latestEvents = repoEvents
          .where((a) => seenIds.add(a.id))
          .map((a) => ActivityEvent.fromAuditEvent(a))
          .toList();
    }

    _updateState(
      ComplaintDetailState(
        status: ComplaintDetailStatus.data,
        complaint: _latestComplaint,
        events: _latestEvents,
        visits: _latestVisits,
        referenceNow: _referenceNow,
      ),
    );
    notifyListeners();
  }

  /// Changes priority via repository.
  Future<void> changePriority(
    ComplaintPriority newPriority, {
    String? reason,
    String? actorId,
  }) async {
    final updated = await repository.updateComplaintPriority(
      complaintId,
      newPriority,
      actorId: actorId ?? currentUserId,
      reason: reason,
    );
    _latestComplaint = updated;
    notifyListeners();
  }

  /// Records an internal note visible only to staff.
  Future<void> addInternalNote(
    String note, {
    List<String> photos = const [],
    String? actorId,
    String? actorName,
  }) async {
    final now = DateTime.now();
    final event = ComplaintAuditEvent(
      id: '${complaintId}_note_${now.millisecondsSinceEpoch}',
      complaintId: complaintId,
      eventType: ComplaintAuditEventType.unknown,
      rawEventType: 'NOTE_ADDED',
      actorId: actorId ?? currentUserId,
      timestamp: now,
      metadata: {
        'actorName': actorName ?? currentUserName,
        'actorRole': currentUserRole,
        'note': note,
        'isInternal': true,
        if (photos.isNotEmpty) 'photos': photos,
      },
    );
    await repository.appendAuditEvent(event);
  }

  /// Moves the workflow forward for an assigned technician.
  Future<void> advanceTechnicianStep(
    ActivityEventType stepType, {
    String? note,
    List<String> photos = const [],
    String? actorId,
    String? actorName,
  }) async {
    final now = DateTime.now();
    final eventType = switch (stepType) {
      ActivityEventType.accepted => 'TECHNICIAN_ACCEPTED',
      ActivityEventType.travelStarted => 'TRAVEL_STARTED',
      ActivityEventType.arrived => 'TECHNICIAN_ARRIVED',
      ActivityEventType.workStarted => 'WORK_STARTED',
      ActivityEventType.repairCompleted => 'REPAIR_COMPLETED',
      ActivityEventType.markedResolved => 'MARKED_RESOLVED',
      _ => stepType.name.toUpperCase(),
    };

    final event = ComplaintAuditEvent(
      id: '${complaintId}_tech_${now.millisecondsSinceEpoch}',
      complaintId: complaintId,
      eventType:
          ComplaintAuditEventType.tryFromValue(eventType) ??
          ComplaintAuditEventType.unknown,
      rawEventType: eventType,
      actorId: actorId ?? currentUserId,
      timestamp: now,
      metadata: {
        'actorName': actorName ?? currentUserName,
        'actorRole': 'Technician',
        'note': ?note,
        if (photos.isNotEmpty) 'photos': photos,
      },
    );
    await repository.appendAuditEvent(event);

    // If step resolves the complaint, update status in complaint repository
    if (stepType == ActivityEventType.repairCompleted ||
        stepType == ActivityEventType.markedResolved) {
      await repository.updateComplaintStatus(
        complaintId,
        ComplaintStatus.resolved,
        actorId: actorId ?? currentUserId,
        role: 'Technician',
        note: note,
      );
    } else if (stepType == ActivityEventType.arrived ||
        stepType == ActivityEventType.workStarted) {
      if (_state.currentStatus != ComplaintStatus.inProgress) {
        await repository.updateComplaintStatus(
          complaintId,
          ComplaintStatus.inProgress,
          actorId: actorId ?? currentUserId,
          role: 'Technician',
          note: note,
        );
      }
    }
  }

  /// Advances the technician visit workflow using VisitWorkflowStep through the repository.
  Future<void> advanceVisitWorkflowStep(
    VisitWorkflowStep step, {
    String? note,
    List<String>? photos,
    String? actorId,
  }) async {
    final updated = await repository.advanceVisitStep(
      complaintId,
      step,
      actorId: actorId ?? currentUserId,
      role: 'technician',
      note: note,
      photos: photos,
    );
    _latestComplaint = updated;
    notifyListeners();
  }

  /// Tenant confirms resolution.
  Future<void> confirmFixed({
    String? note,
    String? actorId,
    String? actorName,
  }) async {
    if (repository is FirestoreComplaintRepository) {
      await ComplaintLifecycleService().closeComplaint(
        complaintId: complaintId,
      );
    } else {
      await repository.updateComplaintStatus(
        complaintId,
        ComplaintStatus.closed,
        actorId: actorId ?? currentUserId,
        role: 'Tenant',
        note: note ?? 'Tenant confirmed repair was successful.',
        metadata: {'actorName': actorName ?? currentUserName},
      );
    }
  }

  /// Tenant reopens resolved complaint with reason.
  Future<void> reopen({
    required String reason,
    String? actorId,
    String? actorName,
  }) async {
    if (reason.trim().isEmpty) {
      throw const ComplaintLifecycleFailure(
        ComplaintLifecycleFailureCode.missingReason,
      );
    }
    if (repository is FirestoreComplaintRepository) {
      await ComplaintLifecycleService().reopenComplaint(
        complaintId: complaintId,
        reason: reason,
      );
    } else {
      await repository.updateComplaintStatus(
        complaintId,
        ComplaintStatus.reopened,
        actorId: actorId ?? currentUserId,
        role: 'Tenant',
        note: reason,
        metadata: {'actorName': actorName ?? currentUserName, 'reason': reason},
      );
    }
  }

  Future<void> cancel({required String reason, String? actorId}) async {
    if (reason.trim().isEmpty) {
      throw const ComplaintLifecycleFailure(
        ComplaintLifecycleFailureCode.missingReason,
      );
    }
    if (repository is FirestoreComplaintRepository) {
      await ComplaintLifecycleService().cancelComplaint(
        complaintId: complaintId,
        reason: reason,
      );
    } else {
      await repository.updateComplaintStatus(
        complaintId,
        ComplaintStatus.cancelled,
        actorId: actorId ?? currentUserId,
        role: currentUserRole,
        note: reason,
      );
    }
  }

  /// Transitions the complaint status via repository and refreshes state from audit events.
  Future<Complaint> changeComplaintStatus(StatusChange change) async {
    final updated = await repository.changeStatus(change);
    _latestComplaint = updated;
    final repoEvents = await repository.loadAuditEvents(complaintId);
    if (repoEvents.isNotEmpty) {
      final seenIds = <String>{};
      _latestEvents = repoEvents
          .where((a) => seenIds.add(a.id))
          .map((a) => ActivityEvent.fromAuditEvent(a))
          .toList();
    }
    _updateState(
      ComplaintDetailState(
        status: ComplaintDetailStatus.data,
        complaint: _latestComplaint,
        events: _latestEvents,
        visits: _latestVisits,
        referenceNow: _referenceNow,
      ),
    );
    notifyListeners();
    return updated;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _complaintSub?.cancel();
    _eventsSub?.cancel();
    _visitsSub?.cancel();
    super.dispose();
  }
}

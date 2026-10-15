import '../core/models/complaint.dart';
import '../core/models/complaint_audit_event.dart';
import '../core/models/maintenance_visit.dart';
import '../screens/complaints/detail/complaint_detail_models.dart';

/// Legacy/generic alias for complaint audit events.
typedef AuditEvent = ComplaintAuditEvent;

/// Represents an on-site technician visit derived from audit events or visit logs.
class VisitRecord {
  const VisitRecord({
    required this.date,
    required this.technician,
    this.arrival,
    this.end,
    this.timeOnSite,
    required this.outcome,
    this.notes,
    this.parts = const <String>[],
    this.photoCount = 0,
    this.visitNumber,
    String? technicianName,
    String? note,
  }) : technicianName = technicianName ?? technician,
       note = note ?? notes;

  final DateTime date;
  final String technician;
  final String technicianName;
  final DateTime? arrival;
  final DateTime? end;
  final Duration? timeOnSite;
  final String outcome;
  final String? notes;
  final String? note;
  final List<String> parts;
  final int photoCount;
  final int? visitNumber;

  bool get isResolved {
    final lower = outcome.toLowerCase();
    return lower.contains('resolved');
  }

  bool get needsAnotherVisit {
    final lower = outcome.toLowerCase();
    return lower.contains('needs another visit') ||
        lower.contains('follow_up') ||
        lower.contains('waiting');
  }

  bool get isInProgress {
    final lower = outcome.toLowerCase();
    return lower.contains('progress') || (!isResolved && !needsAnotherVisit);
  }
}

/// Repeat visit and recurring issue summary.
class RepeatInfo {
  const RepeatInfo({
    required this.repeatVisit,
    required this.recurringIssue,
    this.count = 0,
    this.visitCount = 0,
    this.previousTechnicians = const <String>[],
    this.previousActions = const <String>[],
  });

  /// True if 2 or more visits have occurred on this complaint.
  final bool repeatVisit;

  /// True if 2 or more complaints occurred in the same unit and category within 60 days.
  final bool recurringIssue;

  /// Number of matching complaints in same unit and category within 60 days.
  final int count;

  /// Number of visits on this complaint.
  final int visitCount;

  /// Distinct list of technicians involved in previous matching visits/complaints.
  final List<String> previousTechnicians;

  /// Distinct list of action descriptions from previous matching visits/complaints.
  final List<String> previousActions;
}

/// Pure function deriving on-site visits from a complaint's audit event sequence.
///
/// Handles [ComplaintAuditEvent], [ActivityEvent], [MaintenanceVisit], or generic event maps.
List<VisitRecord> visitsFromEvents(List<dynamic> events) {
  if (events.isEmpty) return const <VisitRecord>[];

  // If already MaintenanceVisit objects, map directly.
  if (events.every((e) => e is MaintenanceVisit)) {
    final visits = events.cast<MaintenanceVisit>().toList()
      ..sort((a, b) => a.visitNumber.compareTo(b.visitNumber));
    return visits.map((v) {
      final started = v.startedAt;
      final completed = v.completedAt;
      final duration = (started != null && completed != null)
          ? completed.difference(started)
          : null;
      final outcomeStr = v.outcome?.value ??
          (v.isResolved
              ? 'resolved'
              : (v.followUpRequired ? 'needs another visit' : 'in progress'));
      return VisitRecord(
        date: started ?? completed ?? DateTime.now(),
        technician: v.technicianId.isNotEmpty ? v.technicianId : 'Technician',
        arrival: started,
        end: completed,
        timeOnSite: duration,
        outcome: outcomeStr,
        notes: v.resolutionSummary ?? v.observation,
        visitNumber: v.visitNumber,
      );
    }).toList();
  }

  // Normalize all events to standardized raw items.
  final rawItems = <_RawEventItem>[];
  for (final e in events) {
    if (e is ComplaintAuditEvent) {
      rawItems.add(_RawEventItem.fromAuditEvent(e));
    } else if (e is ActivityEvent) {
      rawItems.add(_RawEventItem.fromActivityEvent(e));
    } else if (e is MaintenanceVisit) {
      final started = e.startedAt;
      final completed = e.completedAt;
      return [
        VisitRecord(
          date: started ?? completed ?? DateTime.now(),
          technician: e.technicianId.isNotEmpty ? e.technicianId : 'Technician',
          arrival: started,
          end: completed,
          timeOnSite: (started != null && completed != null)
              ? completed.difference(started)
              : null,
          outcome: e.outcome?.value ?? (e.isResolved ? 'resolved' : 'in progress'),
          notes: e.resolutionSummary ?? e.observation,
          visitNumber: e.visitNumber,
        ),
      ];
    } else if (e is Map<String, dynamic>) {
      rawItems.add(_RawEventItem.fromMap(e));
    } else {
      // Try reflection-like duck typing for title/actor/timestamp/note.
      try {
        final dynamic dyn = e;
        rawItems.add(
          _RawEventItem(
            eventType: (dyn.title as String?) ?? '',
            actorName: (dyn.actor as String?) ?? '',
            timestamp: (dyn.timestamp as DateTime?) ?? DateTime.now(),
            note: dyn.note as String?,
          ),
        );
      } catch (_) {}
    }
  }

  if (rawItems.isEmpty) return const <VisitRecord>[];

  // Sort chronologically ascending
  rawItems.sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final visits = <VisitRecord>[];
  _VisitAccumulator? current;
  var visitCounter = 0;

  void closeCurrent(String outcome, DateTime? end) {
    if (current == null) return;
    visitCounter++;
    final duration = (current!.arrival != null && end != null)
        ? end.difference(current!.arrival!)
        : null;
    visits.add(
      VisitRecord(
        date: current!.arrival ?? current!.firstSeen,
        technician: current!.technician.isNotEmpty ? current!.technician : 'Technician',
        arrival: current!.arrival,
        end: end,
        timeOnSite: duration,
        outcome: outcome,
        notes: current!.notes,
        parts: List.unmodifiable(current!.parts),
        photoCount: current!.photoCount,
        visitNumber: current!.visitNumber ?? visitCounter,
      ),
    );
    current = null;
  }

  for (final item in rawItems) {
    final type = item.eventType.toUpperCase();

    // Check if this event starts a visit.
    final isArrival = type.contains('ARRIV') || type.contains('VISIT_STARTED');
    final isInspection = type.contains('INSPECT');
    final isRepairWork = type.contains('REPAIR_STARTED') ||
        type.contains('WORK_STARTED');
    final isResolved = type.contains('RESOLV') ||
        type.contains('REPAIR_COMPLETED') ||
        (type.contains('VISIT_COMPLETED') && item.isResolvedOutcome);
    final isNeedsAnother = type.contains('NEEDS_ANOTHER') ||
        type.contains('FOLLOW_UP') ||
        (type.contains('VISIT_COMPLETED') && !item.isResolvedOutcome);
    final isPartAdded = type.contains('PART');
    final isPhotoUploaded = type.contains('PHOTO') || type.contains('ATTACHMENT');

    if (isArrival) {
      if (current != null) {
        closeCurrent(current!.lastOutcome ?? 'in progress', current!.lastSeen);
      }
      current = _VisitAccumulator(
        arrival: item.timestamp,
        firstSeen: item.timestamp,
        technician: item.actorName,
        visitNumber: item.visitNumber,
      );
      if (item.note != null && item.note!.trim().isNotEmpty) {
        current.notes = item.note!.trim();
      }
      continue;
    }

    if (isInspection || isRepairWork) {
      current ??= _VisitAccumulator(
        arrival: item.timestamp,
        firstSeen: item.timestamp,
        technician: item.actorName,
        visitNumber: item.visitNumber,
      );
      if (item.actorName.isNotEmpty && current.technician.isEmpty) {
        current.technician = item.actorName;
      }
      if (item.note != null && item.note!.trim().isNotEmpty) {
        current.notes = item.note!.trim();
      }
      current.lastSeen = item.timestamp;
      continue;
    }

    if (isPartAdded) {
      current ??= _VisitAccumulator(
        firstSeen: item.timestamp,
        technician: item.actorName,
        visitNumber: item.visitNumber,
      );
      if (item.partName != null && item.partName!.isNotEmpty) {
        current.parts.add(item.partName!);
      }
      current.parts.addAll(item.parts);
      current.lastSeen = item.timestamp;
      continue;
    }

    if (isPhotoUploaded) {
      current ??= _VisitAccumulator(
        firstSeen: item.timestamp,
        technician: item.actorName,
        visitNumber: item.visitNumber,
      );
      current.photoCount += item.photoCount > 0 ? item.photoCount : 1;
      current.lastSeen = item.timestamp;
      continue;
    }

    if (isResolved) {
      current ??= _VisitAccumulator(
        firstSeen: item.timestamp,
        technician: item.actorName,
        visitNumber: item.visitNumber,
      );
      if (item.note != null && item.note!.trim().isNotEmpty) {
        current.notes = item.note!.trim();
      }
      if (item.actorName.isNotEmpty && current.technician.isEmpty) {
        current.technician = item.actorName;
      }
      current.parts.addAll(item.parts);
      if (item.photoCount > 0) current.photoCount += item.photoCount;
      closeCurrent('resolved', item.timestamp);
      continue;
    }

    if (isNeedsAnother) {
      current ??= _VisitAccumulator(
        firstSeen: item.timestamp,
        technician: item.actorName,
        visitNumber: item.visitNumber,
      );
      if (item.note != null && item.note!.trim().isNotEmpty) {
        current.notes = item.note!.trim();
      }
      if (item.actorName.isNotEmpty && current.technician.isEmpty) {
        current.technician = item.actorName;
      }
      current.parts.addAll(item.parts);
      closeCurrent('needs another visit', item.timestamp);
      continue;
    }

    // General note or other event during visit
    if (current != null) {
      if (item.note != null && item.note!.trim().isNotEmpty) {
        current.notes = item.note!.trim();
      }
      current.lastSeen = item.timestamp;
    }
  }

  // If a visit remains open at the end
  if (current != null) {
    closeCurrent('in progress', null);
  }

  return visits;
}

/// Pure function determining repeat visits on [c] and recurring issues within [sameUnit].
RepeatInfo repeatInfo(Complaint c, List<Complaint> sameUnit) {
  final refDate = c.createdAt ?? DateTime.now();
  final matchingComplaints = <String, Complaint>{};
  matchingComplaints[c.id] = c;

  for (final other in sameUnit) {
    if (other.unitId == c.unitId && other.category == c.category) {
      final otherDate = other.createdAt ?? refDate;
      if (_isWithin60Days(refDate, otherDate)) {
        matchingComplaints[other.id] = other;
      }
    }
  }

  final totalMatchingCount = matchingComplaints.length;
  final hasRecurring = totalMatchingCount >= 2;
  final isRepeat = c.visitCount >= 2 || c.isRepeatVisit;

  final previousTechs = <String>{};
  final previousActions = <String>[];

  for (final comp in matchingComplaints.values) {
    if (comp.currentTechnicianId != null &&
        comp.currentTechnicianId!.isNotEmpty) {
      previousTechs.add(comp.currentTechnicianId!);
    }
    final action = comp.description.isNotEmpty ? comp.description : comp.title;
    if (action.isNotEmpty && !previousActions.contains(action)) {
      previousActions.add(action);
    }
  }

  return RepeatInfo(
    repeatVisit: isRepeat,
    recurringIssue: hasRecurring,
    count: totalMatchingCount,
    visitCount: c.visitCount,
    previousTechnicians: previousTechs.toList(),
    previousActions: previousActions,
  );
}

/// Exact 60-day boundary test: day 60 counts (true), day 61 does not (false).
bool _isWithin60Days(DateTime ref, DateTime target) {
  final diffSecs = (ref.difference(target).inSeconds).abs();
  final diffDaysExact = diffSecs / 86400.0;
  // If calendar days or exact duration is <= 60 days
  final calendarDiff = DateTime(ref.year, ref.month, ref.day)
      .difference(DateTime(target.year, target.month, target.day))
      .inDays
      .abs();
  return calendarDiff <= 60 && diffDaysExact <= 60.5;
}

class _RawEventItem {
  _RawEventItem({
    required this.eventType,
    required this.actorName,
    required this.timestamp,
    this.note,
    this.partName,
    this.parts = const <String>[],
    this.photoCount = 0,
    this.visitNumber,
    this.isResolvedOutcome = false,
  });

  final String eventType;
  final String actorName;
  final DateTime timestamp;
  final String? note;
  final String? partName;
  final List<String> parts;
  final int photoCount;
  final int? visitNumber;
  final bool isResolvedOutcome;

  factory _RawEventItem.fromAuditEvent(ComplaintAuditEvent audit) {
    final meta = audit.metadata;
    final typeStr = audit.eventTypeValue;
    final part = (meta['partName'] ?? meta['part']) as String?;
    final partsList = <String>[];
    if (meta['parts'] is List) {
      for (final p in meta['parts']) {
        if (p is String) partsList.add(p);
        if (p is Map && p['name'] != null) partsList.add(p['name'].toString());
      }
    }
    var photos = 0;
    if (meta['photos'] is List) photos += (meta['photos'] as List).length;
    if (meta['photoUrl'] != null || meta['photo'] != null) photos += 1;

    final outcome = meta['outcome']?.toString().toLowerCase();
    final isRes = outcome == 'resolved' || meta['isResolved'] == true;

    return _RawEventItem(
      eventType: typeStr,
      actorName: (meta['actorName'] as String?) ?? audit.actorId,
      timestamp: audit.createdAt ?? DateTime.now(),
      note: (meta['note'] ?? meta['reason'] ?? meta['comment']) as String?,
      partName: part,
      parts: partsList,
      photoCount: photos,
      visitNumber: (meta['visitNumber'] as num?)?.toInt(),
      isResolvedOutcome: isRes,
    );
  }

  factory _RawEventItem.fromActivityEvent(ActivityEvent act) {
    final meta = act.metadata;
    final partsList = <String>[];
    if (meta['parts'] is List) {
      for (final p in meta['parts']) {
        if (p is String) partsList.add(p);
        if (p is Map && p['name'] != null) partsList.add(p['name'].toString());
      }
    }
    final outcome = meta['outcome']?.toString().toLowerCase();
    final isRes = outcome == 'resolved' ||
        act.type == ActivityEventType.markedResolved ||
        act.type == ActivityEventType.repairCompleted;

    return _RawEventItem(
      eventType: act.type.name,
      actorName: act.actorName,
      timestamp: act.timestamp,
      note: act.note,
      parts: partsList,
      photoCount: act.photos.length,
      visitNumber: (meta['visitNumber'] as num?)?.toInt(),
      isResolvedOutcome: isRes,
    );
  }

  factory _RawEventItem.fromMap(Map<String, dynamic> map) {
    return _RawEventItem(
      eventType: (map['eventType'] ?? map['title'] ?? '') as String,
      actorName: (map['actorName'] ?? map['actor'] ?? '') as String,
      timestamp: map['timestamp'] is DateTime
          ? map['timestamp'] as DateTime
          : DateTime.now(),
      note: (map['note'] ?? map['reason']) as String?,
    );
  }
}

class _VisitAccumulator {
  _VisitAccumulator({
    this.arrival,
    required this.firstSeen,
    required this.technician,
    this.visitNumber,
  }) : lastSeen = arrival ?? firstSeen;

  DateTime? arrival;
  DateTime firstSeen;
  DateTime lastSeen;
  String technician;
  String? notes;
  String? lastOutcome;
  final parts = <String>[];
  int photoCount = 0;
  int? visitNumber;
}

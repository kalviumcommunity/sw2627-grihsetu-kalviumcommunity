/// Stable event names persisted in complaint audit documents.
enum ComplaintAuditEventType {
  complaintCreated('COMPLAINT_CREATED'),
  complaintUpdated('COMPLAINT_UPDATED'),
  technicianAssigned('TECHNICIAN_ASSIGNED'),
  technicianReassigned('TECHNICIAN_REASSIGNED'),
  complaintStatusChanged('COMPLAINT_STATUS_CHANGED'),
  complaintResolved('COMPLAINT_RESOLVED'),
  complaintReopened('COMPLAINT_REOPENED'),
  complaintClosed('COMPLAINT_CLOSED'),
  complaintCancelled('COMPLAINT_CANCELLED'),
  complaintWaitingForParts('COMPLAINT_WAITING_FOR_PARTS'),
  priorityChanged('PRIORITY_CHANGED'),
  visitStarted('VISIT_STARTED'),
  visitCompleted('VISIT_COMPLETED'),
  followUpRequested('FOLLOW_UP_REQUESTED'),
  unknown('UNKNOWN');

  const ComplaintAuditEventType(this.value);

  final String value;

  static ComplaintAuditEventType? tryFromValue(String? value) {
    if (value == null) return null;
    for (final type in values) {
      if (type != unknown && type.value == value) return type;
    }
    return null;
  }
}

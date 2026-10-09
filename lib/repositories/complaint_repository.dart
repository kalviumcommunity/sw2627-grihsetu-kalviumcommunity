import '../core/enums/complaint_category.dart';
import '../core/enums/complaint_status.dart';
import '../core/fixtures/sample_fixtures.dart';
import '../core/models/complaint.dart';
import '../screens/complaints/complaint_draft.dart';

abstract interface class ComplaintRepository {
  Future<Complaint> create(ComplaintDraft draft);
  Future<Complaint?> findOpenDuplicate({
    required String unitId,
    required ComplaintCategory category,
  });
}

class InMemoryComplaintRepository implements ComplaintRepository {
  InMemoryComplaintRepository({this.delay = const Duration(milliseconds: 250)});

  final Duration delay;
  final List<Complaint> _complaints = [...SampleFixtures.sampleComplaints];
  int _nextId = 1047;

  @override
  Future<Complaint?> findOpenDuplicate({
    required String unitId,
    required ComplaintCategory category,
  }) async {
    await Future<void>.delayed(delay);
    for (final complaint in _complaints.reversed) {
      if (complaint.unitId == unitId &&
          complaint.category == category &&
          complaint.status.isUnresolved) {
        return complaint;
      }
    }
    return null;
  }

  @override
  Future<Complaint> create(ComplaintDraft draft) async {
    await Future<void>.delayed(delay);
    final now = DateTime.now();
    final complaint = Complaint(
      id: 'C-${_nextId++}',
      tenantId: draft.tenantId ?? '',
      propertyId: draft.propertyId ?? '',
      unitId: draft.unitId ?? '',
      title: draft.title.trim(),
      description: draft.description.trim(),
      category: draft.category!,
      priority: draft.priority,
      status: ComplaintStatus.open,
      createdBy: draft.tenantId ?? 'current-user',
      createdAt: now,
    );
    _complaints.add(complaint);
    // TODO: Replace this in-memory audit trail with Firestore events.
    return complaint;
  }
}

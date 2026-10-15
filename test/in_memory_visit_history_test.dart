import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/screens/technician/visit/visit_models.dart';
import 'package:grihsetu/utils/visit_validators.dart';

void main() {
  test(
    'records first, second and third visits without recounting completion',
    () async {
      final repository = InMemoryComplaintRepository(
        initialComplaints: [
          Complaint(
            id: 'complaint-history',
            tenantId: 'tenant-1',
            propertyId: 'property-1',
            unitId: 'unit-1',
            title: 'Leak',
            description: 'Kitchen leak',
            category: ComplaintCategory.plumbing,
            priority: ComplaintPriority.high,
            status: ComplaintStatus.assigned,
            currentTechnicianId: 'tech-1',
            createdBy: 'ops-1',
          ),
        ],
      );

      Future<void> completeResolvedVisit() async {
        await repository.advanceVisitStep(
          'complaint-history',
          VisitWorkflowStep.accepted,
          actorId: 'tech-1',
        );
        await repository.completeVisit(
          'complaint-history',
          const VisitCompletionInput(
            whatWasFound: 'Fault found',
            whatWasRepaired: 'Repair completed',
            tenantResolutionNotes: 'Recorded',
            noPartsUsed: true,
          ),
          actorId: 'tech-1',
        );
      }

      await completeResolvedVisit();
      var complaint = await repository.loadComplaint('complaint-history');
      expect(complaint?.visitCount, 1);
      expect(complaint?.isRepeatVisit, isFalse);

      await repository.requestFollowUpVisit(
        'complaint-history',
        const FollowUpRequestInput(
          reason: FollowUpReason.other,
          otherReasonDetails: 'Further inspection required',
          details: 'The leak returned after repair.',
        ),
        actorId: 'tech-1',
      );
      complaint = await repository.loadComplaint('complaint-history');
      expect(complaint?.visitCount, 2);
      expect(complaint?.isRepeatVisit, isTrue);

      await completeResolvedVisit();
      complaint = await repository.loadComplaint('complaint-history');
      expect(complaint?.visitCount, 3);
      expect(complaint?.isRepeatVisit, isTrue);

      final visits = await repository.loadMaintenanceVisits(
        'complaint-history',
      );
      expect(visits.map((visit) => visit.visitNumber), [1, 2, 3]);
      expect(visits.where((visit) => visit.completedAt != null), hasLength(3));
    },
  );
}

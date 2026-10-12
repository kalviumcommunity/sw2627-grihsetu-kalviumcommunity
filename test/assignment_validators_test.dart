import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/utils/assignment_validators.dart';

void main() {
  group('AssignmentValidators unit tests', () {
    final fixedNow = DateTime(2026, 10, 12, 10, 0);

    test('validateTechnician requires non-empty technician ID', () {
      expect(
        AssignmentValidators.validateTechnician(selectedTechnicianId: null),
        contains('Please select a technician'),
      );
      expect(
        AssignmentValidators.validateTechnician(selectedTechnicianId: '   '),
        contains('Please select a technician'),
      );
      expect(
        AssignmentValidators.validateTechnician(selectedTechnicianId: 'tech_1'),
        isNull,
      );
    });

    test('validateTechnician blocks same technician in reassign mode', () {
      expect(
        AssignmentValidators.validateTechnician(
          selectedTechnicianId: 'tech_1',
          currentTechnicianId: 'tech_1',
          isReassign: true,
        ),
        contains('different technician'),
      );
      expect(
        AssignmentValidators.validateTechnician(
          selectedTechnicianId: 'tech_2',
          currentTechnicianId: 'tech_1',
          isReassign: true,
        ),
        isNull,
      );
      expect(
        AssignmentValidators.validateTechnician(
          selectedTechnicianId: 'tech_1',
          currentTechnicianId: 'tech_1',
          isReassign: false,
        ),
        isNull,
      );
    });

    test('validateVisitDate checks past, today, max 14 days, and beyond', () {
      final pastDate = DateTime(2026, 10, 11);
      final todayDate = DateTime(2026, 10, 12);
      final fourteenDaysAhead = DateTime(2026, 10, 26);
      final fifteenDaysAhead = DateTime(2026, 10, 27);

      expect(
        AssignmentValidators.validateVisitDate(pastDate, now: fixedNow),
        contains('cannot be in the past'),
      );
      expect(
        AssignmentValidators.validateVisitDate(todayDate, now: fixedNow),
        isNull,
      );
      expect(
        AssignmentValidators.validateVisitDate(
          fourteenDaysAhead,
          now: fixedNow,
        ),
        isNull,
      );
      expect(
        AssignmentValidators.validateVisitDate(fifteenDaysAhead, now: fixedNow),
        contains('cannot be more than 14 days ahead'),
      );
      expect(AssignmentValidators.validateVisitDate(null, now: fixedNow), isNull);
    });

    test('validateSlot requires slot when visit date is present', () {
      final date = DateTime(2026, 10, 15);
      expect(
        AssignmentValidators.validateSlot(date, null),
        contains('Please select a time slot'),
      );
      expect(
        AssignmentValidators.validateSlot(date, AssignmentSlot.morning),
        isNull,
      );
      expect(AssignmentValidators.validateSlot(null, null), isNull);
    });

    test('validateNote checks 300 char boundary and mandatory note on other', () {
      final valid299 = 'a' * 299;
      final valid300 = 'a' * 300;
      final invalid301 = 'a' * 301;

      expect(AssignmentValidators.validateNote(valid299), isNull);
      expect(AssignmentValidators.validateNote(valid300), isNull);
      expect(
        AssignmentValidators.validateNote(invalid301),
        contains('300 characters or fewer'),
      );
      expect(
        AssignmentValidators.validateNote('', isRequired: true),
        contains('is required'),
      );
      expect(
        AssignmentValidators.validateNote('Valid note', isRequired: true),
        isNull,
      );
    });

    test('validateReassignmentReason requires reason and note when Other', () {
      expect(
        AssignmentValidators.validateReassignmentReason(
          isReassign: false,
          reason: null,
        ),
        isNull,
      );
      expect(
        AssignmentValidators.validateReassignmentReason(
          isReassign: true,
          reason: null,
        ),
        contains('Please select a reason'),
      );
      expect(
        AssignmentValidators.validateReassignmentReason(
          isReassign: true,
          reason: ReassignmentReason.technicianUnavailable,
        ),
        isNull,
      );
      expect(
        AssignmentValidators.validateReassignmentReason(
          isReassign: true,
          reason: ReassignmentReason.other,
          note: '',
        ),
        contains('explain the reason in the note'),
      );
      expect(
        AssignmentValidators.validateReassignmentReason(
          isReassign: true,
          reason: ReassignmentReason.other,
          note: 'Emergency shift change',
        ),
        isNull,
      );
    });

    test('generateWarnings checks off-duty, category mismatch, and load > 5', () {
      final noWarnings = AssignmentValidators.generateWarnings(
        isOffDuty: false,
        matchesCategory: true,
        todayJobCount: 3,
        complaintCategory: ComplaintCategory.plumbing,
      );
      expect(noWarnings, isEmpty);

      final allWarnings = AssignmentValidators.generateWarnings(
        isOffDuty: true,
        matchesCategory: false,
        todayJobCount: 6,
        complaintCategory: ComplaintCategory.plumbing,
      );
      expect(allWarnings.length, 3);
      expect(allWarnings[0], contains('off duty'));
      expect(allWarnings[1], contains('Specialty does not match Plumbing'));
      expect(allWarnings[2], contains('currently assigned 6 jobs'));
    });

    test('validateAll combines checks and computes isValid and warnings', () {
      final invalidResult = AssignmentValidators.validateAll(
        selectedTechnicianId: null,
        now: fixedNow,
      );
      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.technicianError, isNotNull);

      final validResult = AssignmentValidators.validateAll(
        selectedTechnicianId: 'tech_01',
        isOffDuty: true,
        matchesCategory: false,
        todayJobCount: 6,
        complaintCategory: ComplaintCategory.electrical,
        now: fixedNow,
      );
      expect(validResult.isValid, isTrue);
      expect(validResult.hasWarnings, isTrue);
      expect(validResult.warnings.length, 3);
    });
  });
}

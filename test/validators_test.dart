import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/screens/complaints/complaint_draft.dart';
import 'package:grihsetu/screens/rent/rent_models.dart';
import 'package:grihsetu/utils/complaint_validators.dart';
import 'package:grihsetu/utils/rent_rules.dart';
import 'package:grihsetu/utils/validators.dart';

void main() {
  group('Validators - Required Text', () {
    test(
      'rejects null, empty, and whitespace-only text with default message',
      () {
        expect(Validators.requiredText(null), 'This field is required');
        expect(Validators.requiredText(''), 'This field is required');
        expect(Validators.requiredText('   \t\n  '), 'This field is required');
      },
    );

    test('supports custom field names and explicit custom messages', () {
      expect(
        Validators.requiredText(null, field: 'Title'),
        'Title is required',
      );
      expect(
        Validators.requiredText('  ', message: 'Please enter a valid title.'),
        'Please enter a valid title.',
      );
    });

    test('valid trimmed text passes', () {
      expect(Validators.requiredText('hello'), isNull);
      expect(Validators.requiredText('  trimmed string  '), isNull);
    });

    test('enforces minimum length when configured', () {
      expect(
        Validators.requiredText('abc', minLength: 5, field: 'Code'),
        'Code must be at least 5 characters',
      );
      expect(
        Validators.requiredText(
          'abc',
          minLength: 5,
          minLengthError: 'Custom min length error',
        ),
        'Custom min length error',
      );
      expect(Validators.requiredText('abcde', minLength: 5), isNull);
      expect(Validators.requiredText('abcdef', minLength: 5), isNull);
    });

    test('enforces maximum length when configured', () {
      expect(
        Validators.requiredText('123456', maxLength: 5, field: 'Pin'),
        'Pin must be 5 characters or fewer',
      );
      expect(
        Validators.requiredText(
          '123456',
          maxLength: 5,
          maxLengthError: 'Custom max length error',
        ),
        'Custom max length error',
      );
      expect(Validators.requiredText('12345', maxLength: 5), isNull);
      expect(Validators.requiredText('1234', maxLength: 5), isNull);
    });

    test('preserves backward compatibility with notEmpty', () {
      expect(Validators.notEmpty(null, 'Subject'), 'Subject is required');
      expect(Validators.notEmpty('   ', 'Subject'), 'Subject is required');
      expect(Validators.notEmpty('Valid subject', 'Subject'), isNull);
    });
  });

  group('Validators - Optional Text', () {
    test('permits null and empty string', () {
      expect(Validators.optionalText(null), isNull);
      expect(Validators.optionalText(''), isNull);
    });

    test('rejects non-empty whitespace-only strings', () {
      expect(
        Validators.optionalText('   ', field: 'Remarks'),
        'Remarks cannot contain only whitespace',
      );
      expect(
        Validators.optionalText(
          ' \t ',
          whitespaceError: 'Whitespace not allowed',
        ),
        'Whitespace not allowed',
      );
    });

    test('enforces length constraints on non-empty values', () {
      expect(
        Validators.optionalText('abc', minLength: 5, field: 'Remarks'),
        'Remarks must be at least 5 characters',
      );
      expect(
        Validators.optionalText('abcdef', maxLength: 5, field: 'Remarks'),
        'Remarks cannot exceed 5 characters',
      );
      expect(
        Validators.optionalText('abcde', minLength: 3, maxLength: 5),
        isNull,
      );
    });
  });

  group('Validators - Email', () {
    test('rejects missing or blank email addresses', () {
      expect(Validators.email(null), 'Email is required');
      expect(Validators.email(''), 'Email is required');
      expect(Validators.email('   '), 'Email is required');
    });

    test('rejects malformed email formats', () {
      const invalid = [
        'plainaddress',
        '@missinguser.com',
        'missingatdomain.com',
        'user@.com',
        'user@domain',
        'user@domain..com',
        'user name@domain.com',
      ];
      for (final email in invalid) {
        expect(
          Validators.email(email),
          'Enter a valid email address',
          reason: 'Failed for: $email',
        );
      }
    });

    test('accepts valid email addresses and handles whitespace', () {
      const valid = [
        'tenant@grihsetu.in',
        'operations.lead@estate-mgmt.co.in',
        'user+tag@sub.domain.org',
        'john.doe123@example.com',
      ];
      for (final email in valid) {
        expect(Validators.email(email), isNull, reason: 'Failed for: $email');
        expect(
          Validators.email('  $email  '),
          isNull,
          reason: 'Failed for trimmed: $email',
        );
      }
    });
  });

  group('Validators - Phone', () {
    test('rejects null, empty, and non-digit strings', () {
      expect(Validators.phone(null), 'Phone number is required');
      expect(Validators.phone(''), 'Phone number is required');
      expect(
        Validators.phone('abcdefghij'),
        'Enter a valid 10-digit mobile number',
      );
      expect(Validators.phone('98765'), 'Enter a valid 10-digit mobile number');
      expect(
        Validators.phone('98765432101'),
        'Enter a valid 10-digit mobile number',
      );
    });

    test('rejects numbers not starting with 6-9', () {
      expect(
        Validators.phone('5876543210'),
        'Enter a valid 10-digit mobile number',
      );
      expect(
        Validators.phone('1234567890'),
        'Enter a valid 10-digit mobile number',
      );
    });

    test('accepts valid 10-digit mobile numbers with whitespace trimming', () {
      expect(Validators.phone('9876543210'), isNull);
      expect(Validators.phone('8123456789'), isNull);
      expect(Validators.phone('7012345678'), isNull);
      expect(Validators.phone('6987654321'), isNull);
      expect(Validators.phone('  9876543210  '), isNull);
    });
  });

  group('Validators - Name', () {
    test('rejects missing or too short names', () {
      expect(Validators.name(null), 'Name is required');
      expect(Validators.name(''), 'Name is required');
      expect(Validators.name('   '), 'Name is required');
      expect(Validators.name('A'), 'Enter your full name');
    });

    test('accepts valid full names', () {
      expect(Validators.name('Al'), isNull);
      expect(Validators.name('Aarav Sharma'), isNull);
      expect(Validators.name('  Priya Patel  '), isNull);
    });
  });

  group('Validators - Password and Confirmation', () {
    test('password enforces presence, length, and character composition', () {
      expect(Validators.password(null), 'Password is required');
      expect(Validators.password(''), 'Password is required');
      expect(Validators.password('Pass1'), 'Use at least 8 characters');
      expect(
        Validators.password('abcdefgh'),
        'Include at least one letter and one number',
      );
      expect(
        Validators.password('12345678'),
        'Include at least one letter and one number',
      );
      expect(Validators.password('Secret12'), isNull);
    });

    test('confirmPassword verifies matching inputs', () {
      expect(
        Validators.confirmPassword(null, 'Secret12'),
        'Please confirm your password is required',
      );
      expect(
        Validators.confirmPassword('Different1', 'Secret12'),
        'Passwords do not match',
      );
      expect(Validators.confirmPassword('Secret12', 'Secret12'), isNull);
    });
  });

  group('Validators - Numeric Amount', () {
    test('amountValue validates presence, finite, NaN, min, and max', () {
      // presence
      expect(
        Validators.amountValue(null, isRequired: true),
        'Amount is required',
      );
      expect(Validators.amountValue(null, isRequired: false), isNull);
      expect(
        Validators.amountValue(null, requiredError: 'Enter an amount'),
        'Enter an amount',
      );

      // NaN and infinity
      expect(
        Validators.amountValue(double.nan, field: 'Cost'),
        'Cost must be a valid number',
      );
      expect(
        Validators.amountValue(double.infinity, field: 'Cost'),
        'Cost must be a valid number',
      );
      expect(
        Validators.amountValue(double.negativeInfinity, field: 'Cost'),
        'Cost must be a valid number',
      );

      // min bounds
      expect(
        Validators.amountValue(0, min: 1, field: 'Payment'),
        'Payment must be at least 1',
      );
      expect(
        Validators.amountValue(
          0,
          min: 1,
          minError: 'Payment amount must be greater than ₹0',
        ),
        'Payment amount must be greater than ₹0',
      );
      expect(Validators.amountValue(1, min: 1), isNull);

      // max bounds
      expect(
        Validators.amountValue(50000, max: 25000, field: 'Promise'),
        'Promise cannot exceed 25000',
      );
      expect(
        Validators.amountValue(
          30000,
          max: 25000,
          maxError: 'Promised amount cannot exceed balance',
        ),
        'Promised amount cannot exceed balance',
      );
      expect(Validators.amountValue(25000, max: 25000), isNull);
      expect(Validators.amountValue(10000, min: 1, max: 25000), isNull);
    });

    test('amount string validator parses and validates user input', () {
      expect(Validators.amount(null), 'Amount is required');
      expect(Validators.amount(''), 'Amount is required');
      expect(Validators.amount('   '), 'Amount is required');
      expect(Validators.amount(null, isRequired: false), isNull);

      expect(Validators.amount('not-a-number'), 'Enter a valid amount');
      expect(Validators.amount('12.34.56'), 'Enter a valid amount');

      expect(
        Validators.amount(
          '0',
          min: 1,
          minError: 'Promised amount must be at least ₹1',
        ),
        'Promised amount must be at least ₹1',
      );
      expect(
        Validators.amount(
          '30000',
          max: 25000,
          maxError: 'Payment amount cannot exceed balance',
        ),
        'Payment amount cannot exceed balance',
      );

      expect(Validators.amount('15000'), isNull);
      expect(Validators.amount('  25000.50  '), isNull);
    });

    test('tryParseAmount safely extracts doubles', () {
      expect(Validators.tryParseAmount(null), isNull);
      expect(Validators.tryParseAmount(''), isNull);
      expect(Validators.tryParseAmount('   '), isNull);
      expect(Validators.tryParseAmount('abc'), isNull);
      expect(Validators.tryParseAmount('25000'), 25000.0);
      expect(Validators.tryParseAmount('  12500.75  '), 12500.75);
    });
  });

  group('Validators - Date', () {
    final refTime = DateTime(2026, 10, 15, 14, 30);
    final today = DateTime(2026, 10, 15);
    final yesterday = DateTime(2026, 10, 14);
    final tomorrow = DateTime(2026, 10, 16);

    test('dateOnly normalizes to midnight calendar date', () {
      final normalized = Validators.dateOnly(refTime);
      expect(normalized.year, 2026);
      expect(normalized.month, 10);
      expect(normalized.day, 15);
      expect(normalized.hour, 0);
      expect(normalized.minute, 0);
      expect(normalized.second, 0);
    });

    test('optional vs required dates', () {
      expect(Validators.date(null, isRequired: false), isNull);
      expect(Validators.date(null, isRequired: true), 'Date is required');
      expect(
        Validators.date(null, field: 'Visit date'),
        'Visit date is required',
      );
      expect(
        Validators.date(null, requiredError: 'Promised date is required'),
        'Promised date is required',
      );
    });

    test(
      'allowPast: false with allowToday: true (rent promise / complaint visit)',
      () {
        expect(
          Validators.date(
            yesterday,
            now: refTime,
            allowPast: false,
            allowToday: true,
            pastError: 'Promised date cannot be in the past',
          ),
          'Promised date cannot be in the past',
        );
        expect(
          Validators.date(
            today,
            now: refTime,
            allowPast: false,
            allowToday: true,
          ),
          isNull,
        );
        expect(
          Validators.date(
            tomorrow,
            now: refTime,
            allowPast: false,
            allowToday: true,
          ),
          isNull,
        );
      },
    );

    test('allowPast: false with allowToday: false (next follow-up date strictly after today)', () {
      expect(
        Validators.date(
          yesterday,
          now: refTime,
          allowPast: false,
          allowToday: false,
          pastError: 'Next follow-up date must be after today',
        ),
        'Next follow-up date must be after today',
      );
      expect(
        Validators.date(
          today,
          now: refTime,
          allowPast: false,
          allowToday: false,
          pastError: 'Next follow-up date must be after today',
        ),
        'Next follow-up date must be after today',
      );
      expect(
        Validators.date(
          tomorrow,
          now: refTime,
          allowPast: false,
          allowToday: false,
        ),
        isNull,
      );
    });

    test('maxDaysAhead limits forward scheduling window', () {
      final inWindow = today.add(const Duration(days: 14));
      final outsideWindow = today.add(const Duration(days: 15));

      expect(Validators.date(inWindow, now: refTime, maxDaysAhead: 14), isNull);
      expect(
        Validators.date(
          outsideWindow,
          now: refTime,
          maxDaysAhead: 14,
          field: 'Visit date',
          maxDateError: 'Visit date must be within the next 14 days',
        ),
        'Visit date must be within the next 14 days',
      );
    });

    test('explicit minDate and maxDate limits', () {
      final min = DateTime(2026, 10, 10);
      final max = DateTime(2026, 10, 20);

      expect(
        Validators.date(
          DateTime(2026, 10, 9),
          now: refTime,
          allowPast: true,
          minDate: min,
          minDateError: 'Too early',
        ),
        'Too early',
      );
      expect(
        Validators.date(
          DateTime(2026, 10, 21),
          now: refTime,
          maxDate: max,
          maxDateError: 'Too late',
        ),
        'Too late',
      );
      expect(
        Validators.date(
          DateTime(2026, 10, 15),
          now: refTime,
          minDate: min,
          maxDate: max,
        ),
        isNull,
      );
    });
  });

  group('Complaint and Reopen Validators', () {
    test('complaint title enforces 5-80 characters and required presence', () {
      expect(ComplaintValidators.title(''), 'Title is required');
      expect(ComplaintValidators.title('   '), 'Title is required');
      expect(
        ComplaintValidators.title('Leak'),
        'Title must be at least 5 characters',
      );
      expect(
        ComplaintValidators.title('Water leak in master bathroom'),
        isNull,
      );
      expect(
        ComplaintValidators.title('A' * 81),
        'Title must be 80 characters or fewer',
      );
      expect(ComplaintValidators.title('A' * 80), isNull);
    });

    test('complaint description enforces standard and urgent limits', () {
      expect(ComplaintValidators.description(''), 'Description is required');
      expect(ComplaintValidators.description('   '), 'Description is required');
      expect(
        ComplaintValidators.description('Too short note'),
        'Description must be at least 20 characters',
      );
      expect(
        ComplaintValidators.description(
          'This is a valid routine description of an issue.',
          priority: ComplaintPriority.medium,
        ),
        isNull,
      );
      expect(
        ComplaintValidators.description(
          'Short urgent note under forty chars',
          priority: ComplaintPriority.urgent,
        ),
        'Urgent complaints need at least 40 characters',
      );
      expect(
        ComplaintValidators.description(
          'A' * 39,
          priority: ComplaintPriority.urgent,
        ),
        'Urgent complaints need at least 40 characters',
      );
      expect(
        ComplaintValidators.description(
          'A' * 40,
          priority: ComplaintPriority.urgent,
        ),
        isNull,
      );
      expect(
        ComplaintValidators.description('A' * 1001),
        'Description must be 1000 characters or fewer',
      );
    });

    test('reopen reason validation', () {
      expect(
        ComplaintValidators.reopenReason(null),
        'Please select a reason for reopening.',
      );
      expect(
        ComplaintValidators.reopenReason(''),
        'Please select a reason for reopening.',
      );
      expect(
        ComplaintValidators.reopenReason('   '),
        'Please select a reason for reopening.',
      );
      expect(ComplaintValidators.reopenReason('Problem came back'), isNull);
    });

    test('reopen explanation enforces minimum 15 characters', () {
      expect(
        ComplaintValidators.reopenExplanation(null),
        'Note must be at least 15 characters describing the issue.',
      );
      expect(
        ComplaintValidators.reopenExplanation(''),
        'Note must be at least 15 characters describing the issue.',
      );
      expect(
        ComplaintValidators.reopenExplanation('Too short'),
        'Note must be at least 15 characters describing the issue.',
      );
      expect(
        ComplaintValidators.reopenExplanation(
          'Problem persists after technician visit; water continues to drip.',
        ),
        isNull,
      );
      expect(
        ComplaintValidators.reopenNote(
          'Problem persists after technician visit; water continues to drip.',
        ),
        isNull,
      );
    });

    test('complaint preferred visit validation', () {
      final refDate = DateTime(2026, 10, 15);
      const draft = ComplaintDraft();

      // No visit date is optional
      expect(ComplaintValidators.visit(draft, today: refDate), isNull);

      final pastDraft = draft.copyWith(
        preferredVisitDate: DateTime(2026, 10, 14),
        preferredVisitSlot: 'Morning',
      );
      expect(
        ComplaintValidators.visit(pastDraft, today: refDate),
        'Visit date cannot be in the past',
      );

      final futureDraft = draft.copyWith(
        preferredVisitDate: DateTime(2026, 10, 20),
        preferredVisitSlot: 'Morning',
      );
      expect(ComplaintValidators.visit(futureDraft, today: refDate), isNull);

      final tooFarDraft = draft.copyWith(
        preferredVisitDate: DateTime(2026, 10, 30),
        preferredVisitSlot: 'Morning',
      );
      expect(
        ComplaintValidators.visit(tooFarDraft, today: refDate),
        'Visit date must be within the next 14 days',
      );

      final missingSlotDraft = draft.copyWith(
        preferredVisitDate: DateTime(2026, 10, 20),
        preferredVisitSlot: null,
      );
      expect(
        ComplaintValidators.visit(missingSlotDraft, today: refDate),
        'Choose a preferred time slot',
      );
    });
  });

  group('Rent Rules - Form Validation (validateFollowUp)', () {
    final refDate = DateTime(2026, 10, 15);

    test('requires contact method and outcome', () {
      final missingMethod = validateFollowUp(
        method: null,
        outcome: FollowUpOutcome.spokeToTenant,
        note: 'Valid follow-up discussion note.',
        currentBalance: 25000,
        now: refDate,
      );
      expect(missingMethod.isValid, isFalse);
      expect(missingMethod.methodError, 'Follow-up method is required');

      final missingOutcome = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: null,
        note: 'Valid follow-up discussion note.',
        currentBalance: 25000,
        now: refDate,
      );
      expect(missingOutcome.isValid, isFalse);
      expect(missingOutcome.outcomeError, 'Follow-up outcome is required');
    });

    test('promisedToPay outcome enforces promise date rules', () {
      // missing date
      final noDate = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: null,
        promisedAmount: 10000,
        note: 'Tenant promised to pay by Tuesday.',
        currentBalance: 25000,
        now: refDate,
      );
      expect(noDate.isValid, isFalse);
      expect(noDate.promisedDateError, 'Promised date is required');

      // past date
      final pastDate = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: DateTime(2026, 10, 14),
        promisedAmount: 10000,
        note: 'Tenant promised to pay by Tuesday.',
        currentBalance: 25000,
        now: refDate,
      );
      expect(pastDate.isValid, isFalse);
      expect(pastDate.promisedDateError, 'Promised date cannot be in the past');

      // today is allowed
      final todayDate = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: DateTime(2026, 10, 15),
        promisedAmount: 10000,
        note: 'Tenant promised to pay by Tuesday.',
        currentBalance: 25000,
        now: refDate,
      );
      expect(todayDate.promisedDateError, isNull);

      // > 30 days ahead rejected
      final farDate = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: DateTime(2026, 11, 20),
        promisedAmount: 10000,
        note: 'Tenant promised to pay next month.',
        currentBalance: 25000,
        now: refDate,
      );
      expect(farDate.isValid, isFalse);
      expect(
        farDate.promisedDateError,
        'Promised date cannot be more than 30 days ahead',
      );
    });

    test('promisedToPay outcome enforces promise amount constraints', () {
      // missing amount
      final noAmount = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: DateTime(2026, 10, 18),
        promisedAmount: null,
        note: 'Tenant promised to pay soon.',
        currentBalance: 25000,
        now: refDate,
      );
      expect(noAmount.isValid, isFalse);
      expect(noAmount.promisedAmountError, 'Promised amount is required');

      // less than 1
      final zeroAmount = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: DateTime(2026, 10, 18),
        promisedAmount: 0,
        note: 'Tenant promised to pay soon.',
        currentBalance: 25000,
        now: refDate,
      );
      expect(zeroAmount.isValid, isFalse);
      expect(
        zeroAmount.promisedAmountError,
        'Promised amount must be at least ₹1',
      );

      // exceeding balance
      final excessAmount = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: DateTime(2026, 10, 18),
        promisedAmount: 30000,
        note: 'Tenant promised to pay soon.',
        currentBalance: 25000,
        now: refDate,
      );
      expect(excessAmount.isValid, isFalse);
      expect(
        excessAmount.promisedAmountError,
        'Promised amount cannot exceed balance',
      );

      // valid promise
      final validPromise = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        promisedDate: DateTime(2026, 10, 18),
        promisedAmount: 25000,
        note: 'Tenant promised full payment by weekend.',
        currentBalance: 25000,
        now: refDate,
      );
      expect(validPromise.isValid, isTrue);
    });

    test('note requirements for standard vs noAnswer outcomes', () {
      // Standard outcome requires note of at least 10 chars
      final blankNote = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: '',
        currentBalance: 25000,
        now: refDate,
      );
      expect(blankNote.noteError, 'Note is required (at least 10 characters)');

      final shortNote = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: 'Short',
        currentBalance: 25000,
        now: refDate,
      );
      expect(shortNote.noteError, 'Note must be at least 10 characters');

      // noAnswer allows optional note, but rejects whitespace-only
      final noAnswerEmpty = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.noAnswer,
        note: '',
        currentBalance: 25000,
        now: refDate,
      );
      expect(noAnswerEmpty.isValid, isTrue);

      final noAnswerWhitespace = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.noAnswer,
        note: '     ',
        currentBalance: 25000,
        now: refDate,
      );
      expect(noAnswerWhitespace.isValid, isFalse);
      expect(
        noAnswerWhitespace.noteError,
        'Note cannot contain only whitespace',
      );
    });

    test('tenant response is optional and rejects whitespace-only', () {
      final validNone = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: 'Spoke with tenant; confirmed invoice sent.',
        tenantResponse: null,
        currentBalance: 25000,
        now: refDate,
      );
      expect(validNone.isValid, isTrue);

      final whitespaceResponse = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: 'Spoke with tenant; confirmed invoice sent.',
        tenantResponse: '   ',
        currentBalance: 25000,
        now: refDate,
      );
      expect(whitespaceResponse.isValid, isFalse);
      expect(
        whitespaceResponse.tenantResponseError,
        'Tenant response cannot contain only whitespace',
      );
    });

    test('next follow-up date must be strictly after today', () {
      final todayNext = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: 'Spoke with tenant; confirmed invoice sent.',
        nextFollowUpDate: refDate,
        currentBalance: 25000,
        now: refDate,
      );
      expect(todayNext.isValid, isFalse);
      expect(
        todayNext.nextFollowUpDateError,
        'Next follow-up date must be after today',
      );

      final futureNext = validateFollowUp(
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.spokeToTenant,
        note: 'Spoke with tenant; confirmed invoice sent.',
        nextFollowUpDate: refDate.add(const Duration(days: 3)),
        currentBalance: 25000,
        now: refDate,
      );
      expect(futureNext.isValid, isTrue);
    });
  });
}

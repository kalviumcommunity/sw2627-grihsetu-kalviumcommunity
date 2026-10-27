import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/models/models.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/repositories/property_repository.dart';
import 'package:grihsetu/repositories/rent_repository.dart';
import 'package:grihsetu/screens/auth/login_screen.dart';
import 'package:grihsetu/screens/auth/signup_screen.dart';
import 'package:grihsetu/screens/complaints/complaint_detail_screen.dart';
import 'package:grihsetu/screens/property/tenant_picker_screen.dart';
import 'package:grihsetu/screens/property/unit_picker_screen.dart';
import 'package:grihsetu/screens/rent/mark_paid_sheet.dart';
import 'package:grihsetu/screens/rent/rent_models.dart';
import 'package:grihsetu/screens/technician/visit/visit_screen.dart';
import 'package:grihsetu/services/auth_service.dart';
import 'package:grihsetu/widgets/empty_state.dart';
import 'package:grihsetu/widgets/error_state.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService()
    : _authStateController = StreamController<fb.User?>.broadcast();

  final StreamController<fb.User?> _authStateController;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<fb.User?> get authStateChanges => _authStateController.stream;

  @override
  fb.User? get currentUser => null;
}

class _ErrorComplaintRepository extends InMemoryComplaintRepository {
  _ErrorComplaintRepository({this.errorToThrow});

  final Object? errorToThrow;

  @override
  Stream<Complaint?> watchComplaint(String id) {
    return Stream<Complaint?>.error(
      errorToThrow ?? TimeoutException('Connection timed out'),
    );
  }
}

class _SubmittingRentRepository extends InMemoryRentRepository {
  _SubmittingRentRepository() : super(simulatedDelay: Duration.zero);

  Completer<void> completer = Completer<void>();

  @override
  Future<RentItem> markPaid(PaymentRecord payment) async {
    await completer.future;
    return super.markPaid(payment);
  }
}

void main() {
  group('GRIH-051 Screen States and Low-Risk UX Defect Fixes', () {
    testWidgets(
      'ComplaintDetailScreen shows EmptyState.noResults when complaint is not found',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ComplaintDetailScreen(
              complaintId: 'missing_complaint_999',
              complaintRepository: InMemoryComplaintRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('Complaint not found'), findsOneWidget);
        expect(
          find.text(
            'The requested complaint record (#missing_complaint_999) could not be located.',
          ),
          findsOneWidget,
        );
        expect(find.text('Go back'), findsOneWidget);
      },
    );

    testWidgets(
      'UnitPickerScreen displays EmptyState when property is not in directory',
      (tester) async {
        const missingProperty = Property(
          id: 'missing_prop_123',
          name: 'Nonexistent Heights',
          address: '404 Street, Bangalore',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: UnitPickerScreen(
              property: missingProperty,
              repository: InMemoryPropertyRepository(
                loadingDelay: Duration.zero,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('Property not found'), findsOneWidget);
        expect(
          find.text('This property is no longer available in the directory.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TenantPickerScreen displays EmptyState when unit is not in directory',
      (tester) async {
        const property = Property(
          id: 'prop_001',
          name: 'Palm Grove Residency',
          address: 'Outer Ring Road, Bengaluru',
        );
        const missingUnit = Unit(
          id: 'missing_unit_999',
          propertyId: 'prop_001',
          unitNumber: 'Z-999',
          floor: 99,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: TenantPickerScreen(
              property: property,
              unit: missingUnit,
              repository: InMemoryPropertyRepository(
                loadingDelay: Duration.zero,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('Unit not found'), findsOneWidget);
        expect(
          find.text('This unit is no longer available in the directory.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('LoginScreen forwards injected AuthService to SignupScreen', (
      tester,
    ) async {
      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authService: fakeAuth)),
      );

      final createAccountButton = find.text('New here? Create an account');
      expect(createAccountButton, findsOneWidget);
      await tester.tap(createAccountButton);
      await tester.pumpAndSettle();

      final signupScreenFinder = find.byType(SignupScreen);
      expect(signupScreenFinder, findsOneWidget);
      final signupScreen = tester.widget<SignupScreen>(signupScreenFinder);
      expect(signupScreen.authService, same(fakeAuth));
    });

    testWidgets('MarkPaidSheet disables close button during submission', (
      tester,
    ) async {
      final submittingRepo = _SubmittingRentRepository();
      final item = await submittingRepo.get('rnt_3001');
      expect(item, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkPaidSheet(item: item!, repository: submittingRepo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially close button is enabled
      final closeFinder = find.widgetWithIcon(IconButton, Icons.close);
      expect(closeFinder, findsOneWidget);
      expect(tester.widget<IconButton>(closeFinder).onPressed, isNotNull);

      // Advance to review/confirmation
      final proceedButton = find.byKey(const Key('mark_paid_proceed_button'));
      await tester.tap(proceedButton);
      await tester.pumpAndSettle();

      // Tap confirm payment button to initiate submit
      final confirmButton = find.byKey(const Key('mark_paid_confirm_button'));
      await tester.tap(confirmButton);
      await tester.pump();

      // While submission is pending, close button must be disabled
      expect(tester.widget<IconButton>(closeFinder).onPressed, isNull);

      // Complete the submission
      submittingRepo.completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'VisitScreen displays ErrorState with sanitized error message on stream error',
      (tester) async {
        final errorRepo = _ErrorComplaintRepository(
          errorToThrow: TimeoutException('Operation timed out 0xDEADBEEF'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: VisitScreen(
              complaintId: 'c_error_001',
              repository: errorRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ErrorState), findsOneWidget);
        expect(find.text('Unable to load visit'), findsOneWidget);
        // The raw exception details must NOT be leaked
        expect(find.textContaining('0xDEADBEEF'), findsNothing);
        // Retry button should be present
        expect(find.text('Retry'), findsOneWidget);
      },
    );
  });
}

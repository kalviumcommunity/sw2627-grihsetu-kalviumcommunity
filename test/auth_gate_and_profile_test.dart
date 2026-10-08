import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/app.dart';
import 'package:grihsetu/app/app_shell.dart';
import 'package:grihsetu/core/enums/user_role.dart';
import 'package:grihsetu/core/models/user.dart';
import 'package:grihsetu/screens/auth/login_screen.dart';
import 'package:grihsetu/services/auth_failure.dart';
import 'package:grihsetu/services/auth_service.dart';
import 'package:grihsetu/widgets/profile_header.dart';

class FakeFirebaseUser implements User {
  FakeFirebaseUser({required this.uid, this.email = 'test@example.com'});

  @override
  final String uid;

  @override
  final String? email;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  FakeAuthService({User? initialUser})
    : _authStateController = StreamController<User?>.broadcast() {
    if (initialUser != null) {
      _currentUser = initialUser;
      scheduleMicrotask(() => _authStateController.add(initialUser));
    }
  }

  final StreamController<User?> _authStateController;
  User? _currentUser;

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  @override
  User? get currentUser => _currentUser;

  void emitUser(User? user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  AppUser? profileToReturn;
  Object? profileErrorToThrow;
  Completer<AppUser>? profileCompleter;

  @override
  Future<AppUser> loadProfile(String uid) async {
    if (profileCompleter != null) {
      return profileCompleter!.future;
    }
    if (profileErrorToThrow != null) {
      throw profileErrorToThrow!;
    }
    return profileToReturn ??
        AppUser(
          id: uid,
          name: 'Riya Sharma',
          email: 'riya@example.com',
          role: UserRole.propertyOperations,
          createdAt: null,
        );
  }

  bool signOutCalled = false;
  AuthFailure? signOutError;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    if (signOutError != null) {
      throw signOutError!;
    }
    emitUser(null);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (profileErrorToThrow != null) {
      throw profileErrorToThrow!;
    }
    final user = FakeFirebaseUser(uid: 'signed-in-uid', email: email);
    emitUser(user);
    return profileToReturn ??
        AppUser(
          id: 'signed-in-uid',
          name: 'Signed In User',
          email: email,
          role: UserRole.propertyOperations,
          createdAt: null,
        );
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
    String? phoneNumber,
  }) async {
    return AppUser(
      id: 'new-uid',
      name: displayName ?? '',
      email: email,
      role: null,
      createdAt: null,
    );
  }

  void dispose() {
    _authStateController.close();
  }
}

void main() {
  group('AuthGate', () {
    late FakeAuthService authService;

    setUp(() {
      authService = FakeAuthService();
    });

    tearDown(() {
      authService.dispose();
    });

    testWidgets('auth state with no Firebase user resolves to LoginScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: AuthGate(authService: authService)),
      );

      // Loading indicator while waiting for first stream event
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      authService.emitUser(null);
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets(
      'auth state with a valid user loads the profile and resolves to AppShell',
      (tester) async {
        authService.profileToReturn = const AppUser(
          id: 'user-42',
          name: 'Riya Sharma',
          email: 'riya@example.com',
          role: UserRole.propertyOperations,
          createdAt: null,
        );

        await tester.pumpWidget(
          MaterialApp(home: AuthGate(authService: authService)),
        );

        authService.emitUser(FakeFirebaseUser(uid: 'user-42'));
        await tester.pump(); // Stream emits
        await tester.pump(); // Profile future completes

        expect(find.byType(AppShell), findsOneWidget);
        expect(find.text('Riya Sharma'), findsOneWidget);
        expect(find.text('Property Operations'), findsWidgets);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );

    testWidgets(
      'auth/profile loading shows a loading indicator while pending',
      (tester) async {
        final completer = Completer<AppUser>();
        authService.profileCompleter = completer;

        await tester.pumpWidget(
          MaterialApp(home: AuthGate(authService: authService)),
        );

        authService.emitUser(FakeFirebaseUser(uid: 'user-pending'));
        await tester.pump(); // Emits user, triggers loadProfile

        // Pending profile loading displays progress indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);
        expect(find.byType(LoginScreen), findsNothing);

        // Once resolved, advances to AppShell
        completer.complete(
          const AppUser(
            id: 'user-pending',
            name: 'Aman Verma',
            email: 'aman@example.com',
            role: UserRole.technician,
            createdAt: null,
          ),
        );
        await tester.pump();

        expect(find.byType(AppShell), findsOneWidget);
        expect(find.text('Aman Verma'), findsOneWidget);
      },
    );

    testWidgets(
      'profile failure produces safe profile-access error and allows sign out',
      (tester) async {
        authService.profileErrorToThrow = const AuthFailure(
          AuthFailureCode.profileNotFound,
        );

        await tester.pumpWidget(
          MaterialApp(home: AuthGate(authService: authService)),
        );

        authService.emitUser(FakeFirebaseUser(uid: 'user-missing'));
        await tester.pump(); // Emits user
        await tester.pump(); // Profile future errors

        expect(find.byType(AppShell), findsNothing);
        expect(
          find.text('Your account profile could not be found.'),
          findsOneWidget,
        );
        expect(find.text('Sign out'), findsOneWidget);

        // Tap Sign out button in safe error state
        await tester.tap(find.text('Sign out'));
        await tester.pump();

        expect(authService.signOutCalled, isTrue);

        // Auth stream emits null, transitioning safely to LoginScreen
        await tester.pump();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);
      },
    );

    testWidgets(
      'profile failure with roleNotAssigned displays safe message without raw error',
      (tester) async {
        authService.profileErrorToThrow = const AuthFailure(
          AuthFailureCode.roleNotAssigned,
        );

        await tester.pumpWidget(
          MaterialApp(home: AuthGate(authService: authService)),
        );

        authService.emitUser(FakeFirebaseUser(uid: 'user-unassigned'));
        await tester.pump();
        await tester.pump();

        expect(find.byType(AppShell), findsNothing);
        expect(
          find.text('Your account is awaiting role assignment.'),
          findsOneWidget,
        );
      },
    );
  });

  group('ProfileHeader', () {
    testWidgets('renders AppUser.name, role displayLabel, and avatar initial', (
      tester,
    ) async {
      const profile = AppUser(
        id: 'u-1',
        name: 'Riya Sharma',
        email: 'riya@example.com',
        role: UserRole.propertyOperations,
        createdAt: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProfileHeader(profile: profile)),
        ),
      );

      expect(find.text('Riya Sharma'), findsOneWidget);
      expect(find.text('Property Operations'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
    });

    testWidgets('does not use hard-coded production user data', (tester) async {
      const technicianProfile = AppUser(
        id: 'u-2',
        name: 'Vikram Joshi',
        email: 'vikram@example.com',
        role: UserRole.technician,
        createdAt: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProfileHeader(profile: technicianProfile)),
        ),
      );

      expect(find.text('Vikram Joshi'), findsOneWidget);
      expect(find.text('Technician'), findsOneWidget);
      expect(find.text('V'), findsOneWidget);
      expect(find.text('Riya Sharma'), findsNothing);
    });

    testWidgets('defensively handles nullable or unassigned role', (
      tester,
    ) async {
      const unassignedProfile = AppUser(
        id: 'u-3',
        name: 'New Registrant',
        email: 'new@example.com',
        role: null,
        createdAt: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProfileHeader(profile: unassignedProfile)),
        ),
      );

      expect(find.text('New Registrant'), findsOneWidget);
      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
    });
  });

  group('Logout', () {
    late FakeAuthService authService;

    setUp(() {
      authService = FakeAuthService();
    });

    tearDown(() {
      authService.dispose();
    });

    testWidgets(
      'successful logout invokes existing auth service and resolves via AuthGate to LoginScreen',
      (tester) async {
        const profile = AppUser(
          id: 'u-logout',
          name: 'Riya Sharma',
          email: 'riya@example.com',
          role: UserRole.propertyOperations,
          createdAt: null,
        );
        authService.profileToReturn = profile;

        await tester.pumpWidget(
          MaterialApp(home: AuthGate(authService: authService)),
        );

        // Start in authenticated state
        authService.emitUser(FakeFirebaseUser(uid: 'u-logout'));
        await tester.pump();
        await tester.pump();

        expect(find.byType(AppShell), findsOneWidget);

        // Tap Sign out icon button in AppShell
        await tester.tap(find.byTooltip('Sign out'));
        await tester.pump();

        expect(authService.signOutCalled, isTrue);

        // Auth stream emission resolves to LoginScreen
        await tester.pump();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);
      },
    );

    testWidgets(
      'failed logout does not falsely navigate away and surfaces safe error',
      (tester) async {
        const profile = AppUser(
          id: 'u-logout-fail',
          name: 'Riya Sharma',
          email: 'riya@example.com',
          role: UserRole.propertyOperations,
          createdAt: null,
        );
        authService.signOutError = const AuthFailure(
          AuthFailureCode.networkError,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppShell(profile: profile, authService: authService),
            ),
          ),
        );

        await tester.tap(find.byTooltip('Sign out'));
        await tester.pump();

        // Remains in authenticated AppShell
        expect(find.byType(AppShell), findsOneWidget);
        // Safe error message surfaced in snackbar
        expect(
          find.text(
            'A network error occurred. Check your connection and try again.',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('LoginScreen auth state driving', () {
    testWidgets(
      'submitting login invokes authService without manual route replacement',
      (tester) async {
        final authService = FakeAuthService();
        authService.profileToReturn = const AppUser(
          id: 'login-uid',
          name: 'Login User',
          email: 'login@example.com',
          role: UserRole.tenant,
          createdAt: null,
        );

        await tester.pumpWidget(
          MaterialApp(home: AuthGate(authService: authService)),
        );

        authService.emitUser(null);
        await tester.pump();

        expect(find.byType(LoginScreen), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'login@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'ValidPassword123',
        );
        await tester.tap(find.text('Sign in'));
        await tester.pump(); // Processes submit & signIn -> emits user
        await tester.pump(); // Profile future resolves

        expect(find.byType(AppShell), findsOneWidget);
        expect(find.text('Login User'), findsOneWidget);
        expect(find.text('Tenant'), findsWidgets);

        authService.dispose();
      },
    );
  });
}

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/app.dart';
import 'package:grihsetu/app/app_shell.dart';
import 'package:grihsetu/core/enums/user_role.dart';
import 'package:grihsetu/core/models/user.dart';
import 'package:grihsetu/screens/auth/login_screen.dart';
import 'package:grihsetu/screens/auth/signup_screen.dart';
import 'package:grihsetu/services/auth_service.dart';

import '../support/app_harness.dart';

class _FakeUser implements User {
  const _FakeUser(this.uid, this.email);

  @override
  final String uid;
  @override
  final String? email;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService implements AuthService {
  final _states = StreamController<User?>.broadcast();
  User? _user;
  bool signedUp = false;
  bool signedOut = false;

  @override
  Stream<User?> get authStateChanges => _states.stream;

  @override
  User? get currentUser => _user;

  void emit(User? user) {
    _user = user;
    _states.add(user);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    emit(_FakeUser('tenant-login', email));
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
    String? phoneNumber,
  }) async {
    signedUp = true;
    return AppUser(
      id: 'new-account',
      name: displayName ?? '',
      email: email,
      role: null,
      createdAt: null,
    );
  }

  @override
  Future<AppUser> loadProfile(String uid) async => const AppUser(
    id: 'tenant-login',
    name: 'Kabir Mehta',
    email: 'kabir.mehta@example.com',
    role: UserRole.tenant,
    createdAt: null,
  );

  @override
  Future<void> signOut() async {
    signedOut = true;
    emit(null);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  Future<void> close() => _states.close();
}

void main() {
  testWidgets('sign-up validates fields and creates an unassigned account', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    addTearDown(auth.close);
    await tester.pumpWidget(MaterialApp(home: SignupScreen(authService: auth)));

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.textContaining('Please accept the Terms'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);

    await enterByLabel(tester, 'Full name', 'Kabir Mehta');
    await enterByLabel(tester, 'Email', 'kabir.mehta@example.com');
    await enterByLabel(tester, 'Mobile number', '9811120401');
    await enterByLabel(tester, 'Password', 'Secure123');
    await enterByLabel(tester, 'Confirm password', 'Secure123');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await settle(tester);

    expect(auth.signedUp, isTrue);
    expect(auth.signedOut, isTrue);
    expect(find.textContaining('Account created.'), findsOneWidget);
    expectNoOverflow(tester);
  });

  testWidgets('bad login shows field errors', (tester) async {
    final auth = _FakeAuthService();
    addTearDown(auth.close);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: auth)));

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    await enterByLabel(tester, 'Email', 'not-an-email');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('valid login reaches role home and sign out clears app shell', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    addTearDown(auth.close);
    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: auth)));
    auth.emit(null);
    await tester.pump();

    await enterByLabel(tester, 'Email', 'kabir.mehta@example.com');
    await enterByLabel(tester, 'Password', 'Secure123');
    await tester.tap(find.text('Sign in'));
    await settle(tester);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Kabir Mehta'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.byTooltip('Sign out'));
    await settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    expect(auth.signedOut, isTrue);
  });
}

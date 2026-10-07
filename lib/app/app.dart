import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../core/enums/user_role.dart';
import '../core/models/user.dart';
import '../screens/auth/login_screen.dart';
import '../services/auth_failure.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

class GrihSetuApp extends StatelessWidget {
  const GrihSetuApp({
    super.key,
    this.webFonts = true,
    this.enableAuthentication = false,
    this.authService,
  });

  final bool webFonts; // false in tests, so no font downloads
  final bool enableAuthentication;
  final AuthService? authService;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppStrings.appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(webFonts: webFonts),
    darkTheme: AppTheme.dark(webFonts: webFonts),
    themeMode: ThemeMode.system,
    home: enableAuthentication
        ? AuthGate(authService: authService ?? AuthService.firebase())
        : const AppShell(profile: _previewProfile),
  );
}

/// Resolves Firebase identity first, then loads the trusted Firestore profile.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          return LoginScreen(authService: authService);
        }

        return FutureBuilder<AppUser>(
          future: authService.loadProfile(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final profile = profileSnapshot.data;
            if (profile != null) {
              return AppShell(profile: profile, authService: authService);
            }
            final error = profileSnapshot.error;
            final message = error is AuthFailure
                ? error.message
                : const AuthFailure(AuthFailureCode.unknown).message;
            return _ProfileAccessError(
              message: message,
              authService: authService,
            );
          },
        );
      },
    );
  }
}

class _ProfileAccessError extends StatelessWidget {
  const _ProfileAccessError({required this.message, required this.authService});

  final String message;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    await authService.signOut();
                  } on AuthFailure {
                    // The auth stream remains the source of truth. If the
                    // sign-out fails, leave this safe error state in place.
                  }
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Used only by the existing unauthenticated widget-gallery preview. The
// production entry point enables [AuthGate] below.
const _previewProfile = AppUser(
  id: 'preview',
  name: 'Preview',
  email: 'preview@grihsetu.local',
  role: UserRole.technician,
  createdAt: null,
);

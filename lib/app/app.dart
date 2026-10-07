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
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.authService});

  final AuthService authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _currentUid;
  Future<AppUser>? _profileFuture;

  void _syncProfileFuture(User? firebaseUser) {
    if (firebaseUser == null) {
      _currentUid = null;
      _profileFuture = null;
    } else if (firebaseUser.uid != _currentUid) {
      _currentUid = firebaseUser.uid;
      _profileFuture = widget.authService.loadProfile(firebaseUser.uid);
    }
  }

  @override
  void didUpdateWidget(AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authService != widget.authService) {
      _currentUid = null;
      _profileFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: widget.authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }
        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          _syncProfileFuture(null);
          return LoginScreen(authService: widget.authService);
        }

        _syncProfileFuture(firebaseUser);

        return FutureBuilder<AppUser>(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingScreen();
            }
            final profile = profileSnapshot.data;
            if (profile != null) {
              return AppShell(
                profile: profile,
                authService: widget.authService,
              );
            }
            final error = profileSnapshot.error;
            final message = error is AuthFailure
                ? error.message
                : const AuthFailure(AuthFailureCode.unknown).message;
            return _ProfileAccessError(
              message: message,
              authService: widget.authService,
            );
          },
        );
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ProfileAccessError extends StatefulWidget {
  const _ProfileAccessError({required this.message, required this.authService});

  final String message;
  final AuthService authService;

  @override
  State<_ProfileAccessError> createState() => _ProfileAccessErrorState();
}

class _ProfileAccessErrorState extends State<_ProfileAccessError> {
  bool _isSigningOut = false;

  Future<void> _handleSignOut() async {
    setState(() => _isSigningOut = true);
    try {
      await widget.authService.signOut();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSigningOut ? null : _handleSignOut,
                child: _isSigningOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign out'),
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

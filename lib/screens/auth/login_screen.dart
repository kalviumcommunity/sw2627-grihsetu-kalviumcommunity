import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/errors/app_failure.dart';
import '../../services/errors/firebase_error_mapper.dart';
import '../../utils/validators.dart';
import '../../widgets/error_banner.dart';
import 'auth_layout.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  AppFailure? _failure;

  AuthService get _authService => widget.authService ?? AuthService.firebase();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await _authService.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error, stackTrace) {
      final failure = FirebaseErrorMapper.map(error, stackTrace);
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to continue',
      form: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_failure != null) ...[
              ErrorBanner(
                failure: _failure,
                onDismiss: () => setState(() => _failure = null),
                onRetry: _failure!.retryable ? _submit : null,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _hide,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  tooltip: _hide ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _hide
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              validator: (value) => Validators.notEmpty(value, 'Password'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ForgotPasswordScreen(
                            authService: widget.authService,
                          ),
                        ),
                      ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SignupScreen(authService: widget.authService),
                      ),
                    ),
              child: const Text('New here? Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}

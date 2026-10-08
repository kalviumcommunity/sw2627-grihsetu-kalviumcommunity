import 'package:flutter/material.dart';

import '../../services/auth_failure.dart';
import '../../services/auth_service.dart';
import 'auth_layout.dart';
import '../../utils/validators.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  bool _termsAccepted = false;
  bool _showTermsError = false;
  String? _error;

  AuthService get _authService => widget.authService ?? AuthService.firebase();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_termsAccepted) {
      setState(() => _showTermsError = true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _authService.signUp(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _name.text,
        phoneNumber: _phone.text,
      );
      // A newly registered account has no authoritative role. End the local
      // Firebase session until a trusted process assigns one.
      try {
        await _authService.signOut();
      } on AuthFailure {
        // The account/profile result remains safe because no role was set.
      }
      if (!mounted) return;
      setState(
        () => _error = 'Account created. A trusted administrator must assign your role before you can sign in.',
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Create your account',
      subtitle: 'It takes less than a minute',
      form: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: Validators.name,
            ),
            const SizedBox(height: 16),
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
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                counterText: '',
              ),
              validator: Validators.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _hide,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least 8 characters, with a letter and a number',
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
              validator: Validators.password,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: _hide,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Confirm password'),
              validator: (value) =>
                  Validators.confirmPassword(value, _password.text),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _termsAccepted,
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _termsAccepted = value ?? false;
                      if (_termsAccepted) _showTermsError = false;
                    }),
              title: const Text('I agree to the Terms and Privacy Policy'),
            ),
            if (_showTermsError)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'Please accept the Terms and Privacy Policy to continue.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

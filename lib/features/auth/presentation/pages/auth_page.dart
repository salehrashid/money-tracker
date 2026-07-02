import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../providers/auth_providers.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({this.initialMessage, super.key});

  final String? initialMessage;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  var _mode = _AuthMode.signIn;
  var _obscurePassword = true;
  var _isSubmitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRegistering = _mode == _AuthMode.register;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: colorScheme.primary,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Money Tracker',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRegistering
                          ? 'Create your private finance account.'
                          : 'Sign in to continue.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<_AuthMode>(
                      segments: const [
                        ButtonSegment(
                          value: _AuthMode.signIn,
                          icon: Icon(Icons.login),
                          label: Text('Sign in'),
                        ),
                        ButtonSegment(
                          value: _AuthMode.register,
                          icon: Icon(Icons.person_add_alt_1),
                          label: Text('Register'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: _isSubmitting
                          ? null
                          : (selection) {
                              setState(() {
                                _mode = selection.first;
                                _message = null;
                              });
                            },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Email is required.';
                        }
                        if (!email.contains('@')) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isSubmitting,
                      obscureText: _obscurePassword,
                      textInputAction: isRegistering
                          ? TextInputAction.next
                          : TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final password = value ?? '';
                        if (password.isEmpty) {
                          return 'Password is required.';
                        }
                        if (password.length < 6) {
                          return 'Password must be at least 6 characters.';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!isRegistering) {
                          _submit();
                        }
                      },
                    ),
                    if (isRegistering) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !_isSubmitting,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_reset),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isRegistering ? Icons.person_add : Icons.login,
                            ),
                      label: Text(isRegistering ? 'Create account' : 'Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    final repository = ref.read(authRepositoryProvider);
    final result = switch (_mode) {
      _AuthMode.signIn => await repository.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      ),
      _AuthMode.register => await repository.registerWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      ),
    };

    if (!mounted) {
      return;
    }

    switch (result) {
      case Success():
        break;
      case Failure(:final failure):
        setState(() {
          _message = failure.message;
          _isSubmitting = false;
        });
    }
  }
}

enum _AuthMode { signIn, register }

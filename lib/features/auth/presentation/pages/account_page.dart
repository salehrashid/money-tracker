import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../providers/auth_providers.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  var _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _MessageState(
          icon: Icons.error_outline,
          title: 'Unable to load account',
          message: 'Please restart the app and try again.',
        ),
        data: (result) => result.when(
          failure: (failure) => _MessageState(
            icon: Icons.error_outline,
            title: 'Unable to load account',
            message: failure.message,
          ),
          success: (user) {
            if (user == null) {
              return const _MessageState(
                icon: Icons.lock_outline,
                title: 'Signed out',
                message: 'Sign in to access your Money Tracker data.',
              );
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.email ?? 'Signed in',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.isEmailVerified
                            ? 'Email verified'
                            : 'Email verification pending',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isSigningOut ? null : _signOut,
                        icon: _isSigningOut
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    final result = await ref.read(authRepositoryProvider).signOut();

    if (!mounted) {
      return;
    }

    switch (result) {
      case Success():
        break;
      case Failure(:final failure):
        setState(() {
          _isSigningOut = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

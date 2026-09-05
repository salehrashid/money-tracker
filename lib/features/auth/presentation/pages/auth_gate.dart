import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../../../features/accounts/presentation/providers/account_providers.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../domain/entities/auth_user.dart';
import '../providers/auth_providers.dart';
import 'auth_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // Whenever the auth state transitions to a signed-in user, ensure a
    // default financial account exists. This is intentionally a fire-and-forget
    // side-effect that runs once per auth-state change, not on every rebuild.
    ref.listen(authStateProvider, (_, next) {
      next.whenData((result) {
        if (result case Success<AuthUser?>(:final value)) {
          final user = value;
          if (user == null) return;
          ref
              .read(firestoreUserProfileServiceProvider(user.id))
              .upsertProfile(user)
              .catchError((Object error) {
                if (kDebugMode) {
                  debugPrint('[UserProfile] Firestore error: $error');
                }
              });
          ref
              .read(ensureDefaultAccountUseCaseProvider(user.id))
              .execute(user.id);
        }
      });
    });

    return authState.when(
      loading: () => const _AuthLoadingPage(),
      error: (_, _) => const AuthPage(
        initialMessage: 'Unable to check sign-in status. Please try again.',
      ),
      data: (result) => result.when(
        failure: (failure) => AuthPage(initialMessage: failure.message),
        success: (user) => user == null
            ? const AuthPage()
            : _AuthenticatedApp(userId: user.id),
      ),
    );
  }
}

class _AuthenticatedApp extends ConsumerWidget {
  const _AuthenticatedApp({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.watch(syncCoordinatorProvider(userId));
    for (final collection in const [
      'accounts',
      'categories',
      'transactions',
      'transaction_drafts',
      'debts',
      'notification_logs',
      'settings',
    ]) {
      coordinator.register(collection);
    }
    return const AppShell();
  }
}

class _AuthLoadingPage extends StatelessWidget {
  const _AuthLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

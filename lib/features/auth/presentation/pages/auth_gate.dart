import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_shell.dart';
import '../providers/auth_providers.dart';
import 'auth_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _AuthLoadingPage(),
      error: (_, _) => const AuthPage(
        initialMessage: 'Unable to check sign-in status. Please try again.',
      ),
      data: (result) => result.when(
        failure: (failure) => AuthPage(initialMessage: failure.message),
        success: (user) => user == null ? const AuthPage() : const AppShell(),
      ),
    );
  }
}

class _AuthLoadingPage extends StatelessWidget {
  const _AuthLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

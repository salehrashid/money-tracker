import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase/firebase_app_initializer.dart';
import 'core/utils/result.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'shared/theme/app_theme.dart';
import 'shared/undo_delete/pending_delete_controller.dart';

final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);

  final firebaseResult = await const FirebaseAppInitializer().initialize();

  runApp(MyApp(firebaseResult: firebaseResult));
}

class MyApp extends StatelessWidget {
  const MyApp({required this.firebaseResult, super.key});

  final Result<Object> firebaseResult;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(child: _App(firebaseResult: firebaseResult));
  }
}

class _App extends ConsumerWidget {
  const _App({required this.firebaseResult});

  final Result<Object> firebaseResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<PendingDeleteFailure?>(pendingDeleteFailureProvider, (
      previous,
      next,
    ) {
      if (next == null || previous?.serial == next.serial) {
        return;
      }
      final messenger = appScaffoldMessengerKey.currentState;
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(next.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
    return MaterialApp(
      scaffoldMessengerKey: appScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Fleeca',
      theme: buildAppTheme(),
      home: firebaseResult.when(
        success: (_) => const AuthGate(),
        failure: (failure) => _StartupFailurePage(message: failure.message),
      ),
    );
  }
}

class _StartupFailurePage extends StatelessWidget {
  const _StartupFailurePage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Fleeca')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Unable to start Fleeca',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

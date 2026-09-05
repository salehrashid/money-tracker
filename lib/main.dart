import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/firebase/firebase_app_initializer.dart';
import 'core/offline/offline_database.dart';
import 'core/utils/result.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/settings/presentation/providers/financial_settings_providers.dart';
import 'shared/theme/app_theme.dart';
import 'shared/undo_delete/pending_delete_controller.dart';

final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      minimumSize: Size(900, 600),
      center: true,
      fullScreen: false,
      skipTaskbar: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.maximize();
    });
  }

  await dotenv.load(fileName: '.env', isOptional: true);
  await OfflineDatabase.initialize();

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
    final authResult = ref.watch(authStateProvider).value;
    final userId = authResult?.when(
      success: (user) => user?.id,
      failure: (_) => null,
    );
    final settingsResult = userId == null
        ? null
        : ref.watch(financialSettingsProvider(userId)).value;
    final isDarkMode =
        settingsResult?.when(
          success: (settings) => settings?.isDarkMode ?? false,
          failure: (_) => false,
        ) ??
        false;

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
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
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

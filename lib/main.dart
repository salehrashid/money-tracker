import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase/firebase_app_initializer.dart';
import 'core/utils/result.dart';
import 'features/categories/presentation/pages/category_management_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);

  final firebaseResult = await const FirebaseAppInitializer().initialize();

  runApp(ProviderScope(child: MyApp(firebaseResult: firebaseResult)));
}

class MyApp extends StatelessWidget {
  const MyApp({required this.firebaseResult, super.key});

  final Result<Object> firebaseResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: firebaseResult.when(
        success: (_) => const CategoryManagementPage(),
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
      appBar: AppBar(title: const Text('Money Tracker')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Unable to start Money Tracker',
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

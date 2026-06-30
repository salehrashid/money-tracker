import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase/firebase_app_initializer.dart';
import 'core/utils/result.dart';

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
      home: MyHomePage(title: 'Money Tracker', firebaseResult: firebaseResult),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    required this.title,
    required this.firebaseResult,
    super.key,
  });

  final String title;
  final Result<Object> firebaseResult;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FirebaseStatus(result: widget.firebaseResult),
            const SizedBox(height: 24),
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FirebaseStatus extends StatelessWidget {
  const _FirebaseStatus({required this.result});

  final Result<Object> result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return result.when(
      success: (_) =>
          Text('Firebase ready', style: TextStyle(color: colorScheme.primary)),
      failure: (failure) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          failure.message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.error),
        ),
      ),
    );
  }
}

import 'package:firebase_core/firebase_core.dart';

import '../errors/firebase_error_mapper.dart';
import '../utils/result.dart';
import 'firebase_environment.dart';

class FirebaseAppInitializer {
  const FirebaseAppInitializer({
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _errorMapper = errorMapper;

  final FirebaseErrorMapper _errorMapper;

  Future<Result<FirebaseApp>> initialize() async {
    final optionsResult = FirebaseEnvironment.optionsForCurrentPlatform();

    return switch (optionsResult) {
      Failure<FirebaseOptions>(:final failure) => Failure(failure),
      Success<FirebaseOptions>(:final value) => _initializeWithOptions(value),
    };
  }

  Future<Result<FirebaseApp>> _initializeWithOptions(
    FirebaseOptions options,
  ) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        return Success(Firebase.app());
      }

      final app = await Firebase.initializeApp(options: options);
      return Success(app);
    } catch (error) {
      return Failure(_errorMapper.map(error));
    }
  }
}

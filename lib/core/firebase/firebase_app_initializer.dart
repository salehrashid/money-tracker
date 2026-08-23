import 'package:firedart/firedart.dart';

import '../errors/firebase_error_mapper.dart';
import '../utils/result.dart';
import 'firebase_environment.dart';
import '../../features/auth/data/datasources/secure_auth_token_store.dart';

class FirebaseAppInitializer {
  const FirebaseAppInitializer({
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _errorMapper = errorMapper;

  final FirebaseErrorMapper _errorMapper;

  Future<Result<Object>> initialize() async {
    final optionsResult = FirebaseEnvironment.optionsForCurrentPlatform();

    return switch (optionsResult) {
      Failure<FirebaseConfiguration>(:final failure) => Failure(failure),
      Success<FirebaseConfiguration>(:final value) => _initialize(value),
    };
  }

  Future<Result<Object>> _initialize(
    FirebaseConfiguration configuration,
  ) async {
    try {
      if (!FirebaseAuth.initialized) {
        final tokenStore = await SecureAuthTokenStore.create();
        FirebaseAuth.initialize(configuration.webApiKey, tokenStore);
      }
      if (!Firestore.initialized) {
        Firestore.initialize(configuration.projectId);
      }
      return Success(Firestore.instance);
    } catch (error) {
      return Failure(_errorMapper.map(error));
    }
  }
}

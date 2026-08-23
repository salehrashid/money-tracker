import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../errors/app_failure.dart';
import '../utils/result.dart';

class FirebaseEnvironment {
  const FirebaseEnvironment._();

  static const _apiKeyFromDefine = String.fromEnvironment('FIREBASE_API_KEY');
  static const _webApiKeyFromDefine = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
  );
  static const _projectIdFromDefine = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  static Result<FirebaseConfiguration> optionsForCurrentPlatform() {
    final projectId = _read('FIREBASE_PROJECT_ID', _projectIdFromDefine);
    final apiKey = _read(
      'FIREBASE_WEB_API_KEY',
      _fallback(_webApiKeyFromDefine, _apiKeyFromDefine),
    );
    final missingKeys = <String>[
      if (projectId.isEmpty) 'FIREBASE_PROJECT_ID',
      if (apiKey.isEmpty) 'FIREBASE_WEB_API_KEY',
    ];

    if (missingKeys.isNotEmpty) {
      return Failure(
        AppFailure(
          type: AppFailureType.configuration,
          code: 'missing-firebase-config',
          message: 'Firebase is not configured for this build.',
          details: missingKeys,
        ),
      );
    }

    return Success(
      FirebaseConfiguration(projectId: projectId, webApiKey: apiKey),
    );
  }

  static String _read(String key, String fallback) {
    if (!dotenv.isInitialized) {
      return fallback;
    }

    final value = dotenv.maybeGet(key)?.trim();
    return _fallback(value, fallback);
  }

  static String _fallback(String? primary, String fallback) {
    if (primary == null || primary.isEmpty) {
      return fallback;
    }

    return primary;
  }
}

class FirebaseConfiguration {
  const FirebaseConfiguration({
    required this.projectId,
    required this.webApiKey,
  });

  final String projectId;
  final String webApiKey;
}

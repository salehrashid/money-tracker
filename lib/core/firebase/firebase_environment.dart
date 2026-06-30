import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../errors/app_failure.dart';
import '../utils/result.dart';

class FirebaseEnvironment {
  const FirebaseEnvironment._();

  static const _apiKeyFromDefine = String.fromEnvironment('FIREBASE_API_KEY');
  static const _webApiKeyFromDefine = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
  );
  static const _appIdFromDefine = String.fromEnvironment('FIREBASE_APP_ID');
  static const _messagingSenderIdFromDefine = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectIdFromDefine = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const _authDomainFromDefine = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const _storageBucketFromDefine = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const _measurementIdFromDefine = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
  );

  static Result<FirebaseOptions> optionsForCurrentPlatform() {
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

    final messagingSenderId = _fallback(
      _read('FIREBASE_MESSAGING_SENDER_ID', _messagingSenderIdFromDefine),
      projectId,
    );
    final appId = _fallback(
      _read('FIREBASE_APP_ID', _appIdFromDefine),
      '1:$messagingSenderId:web:$projectId',
    );
    final authDomain = _fallback(
      _read('FIREBASE_AUTH_DOMAIN', _authDomainFromDefine),
      '$projectId.firebaseapp.com',
    );
    final storageBucket = _fallback(
      _read('FIREBASE_STORAGE_BUCKET', _storageBucketFromDefine),
      '$projectId.firebasestorage.app',
    );
    final measurementId = _read(
      'FIREBASE_MEASUREMENT_ID',
      _measurementIdFromDefine,
    );

    return Success(
      FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: _optionalWebValue(authDomain),
        storageBucket: _optionalValue(storageBucket),
        measurementId: _optionalWebValue(measurementId),
      ),
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

  static String? _optionalValue(String value) {
    return value.isEmpty ? null : value;
  }

  static String? _optionalWebValue(String value) {
    if (!kIsWeb) {
      return null;
    }

    return _optionalValue(value);
  }
}

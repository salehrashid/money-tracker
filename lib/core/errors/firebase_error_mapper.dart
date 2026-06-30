import 'package:firebase_core/firebase_core.dart';

import 'app_failure.dart';

class FirebaseErrorMapper {
  const FirebaseErrorMapper();

  AppFailure map(Object error) {
    if (error is FirebaseException) {
      return _mapFirebaseException(error);
    }

    return AppFailure(
      type: AppFailureType.unknown,
      message: 'Something went wrong. Please try again.',
      details: error,
    );
  }

  AppFailure _mapFirebaseException(FirebaseException error) {
    final code = error.code.toLowerCase();

    if (_networkCodes.contains(code)) {
      return AppFailure(
        type: AppFailureType.network,
        code: error.code,
        message:
            'Network connection failed. Check your connection and try again.',
        details: error,
      );
    }

    if (_authCodes.containsKey(code)) {
      return AppFailure(
        type: AppFailureType.authentication,
        code: error.code,
        message: _authCodes[code]!,
        details: error,
      );
    }

    if (_permissionCodes.contains(code)) {
      return AppFailure(
        type: AppFailureType.authorization,
        code: error.code,
        message: 'You do not have permission to do that.',
        details: error,
      );
    }

    if (_notFoundCodes.contains(code)) {
      return AppFailure(
        type: AppFailureType.notFound,
        code: error.code,
        message: 'The requested data could not be found.',
        details: error,
      );
    }

    if (_unavailableCodes.contains(code)) {
      return AppFailure(
        type: AppFailureType.unavailable,
        code: error.code,
        message:
            'The service is temporarily unavailable. Please try again later.',
        details: error,
      );
    }

    return AppFailure(
      type: AppFailureType.unknown,
      code: error.code,
      message: 'Something went wrong. Please try again.',
      details: error,
    );
  }

  static const _networkCodes = {
    'network-request-failed',
    'unavailable',
    'deadline-exceeded',
  };

  static const _permissionCodes = {
    'permission-denied',
    'unauthorized',
    'operation-not-allowed',
  };

  static const _notFoundCodes = {'not-found', 'user-not-found'};

  static const _unavailableCodes = {'internal', 'resource-exhausted'};

  static const _authCodes = {
    'invalid-email': 'Enter a valid email address.',
    'invalid-credential': 'The email or password is incorrect.',
    'wrong-password': 'The email or password is incorrect.',
    'user-disabled': 'This account has been disabled.',
    'too-many-requests': 'Too many attempts. Please wait and try again.',
  };
}

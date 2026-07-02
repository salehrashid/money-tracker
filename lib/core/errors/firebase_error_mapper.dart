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

    if (_configurationCodes.containsKey(code)) {
      return AppFailure(
        type: AppFailureType.configuration,
        code: error.code,
        message: _configurationCodes[code]!,
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

    final failureFromMessage = _mapUnknownFirebaseMessage(error);
    if (failureFromMessage != null) {
      return failureFromMessage;
    }

    return AppFailure(
      type: AppFailureType.unknown,
      code: error.code,
      message: _unknownFirebaseMessage(error),
      details: error,
    );
  }

  AppFailure? _mapUnknownFirebaseMessage(FirebaseException error) {
    final message = error.message?.toLowerCase() ?? '';

    if (message.contains('configuration_not_found') ||
        message.contains('configuration-not-found')) {
      return AppFailure(
        type: AppFailureType.configuration,
        code: error.code,
        message:
            'Firebase Authentication is not configured. Enable Email/Password sign-in in Firebase Console.',
        details: error,
      );
    }

    if (message.contains('operation_not_allowed') ||
        message.contains('operation-not-allowed')) {
      return AppFailure(
        type: AppFailureType.authentication,
        code: error.code,
        message:
            'Email/password sign-in is disabled. Enable it in Firebase Console.',
        details: error,
      );
    }

    if (message.contains('api key') && message.contains('not valid')) {
      return AppFailure(
        type: AppFailureType.configuration,
        code: error.code,
        message:
            'Firebase API key is not valid for this app. Check your Firebase API key and app registration.',
        details: error,
      );
    }

    if (message.contains('app') && message.contains('not authorized')) {
      return AppFailure(
        type: AppFailureType.configuration,
        code: error.code,
        message:
            'This app is not authorized for your Firebase project. Check the Android app package and API key restrictions in Firebase Console.',
        details: error,
      );
    }

    return null;
  }

  String _unknownFirebaseMessage(FirebaseException error) {
    final detail = error.message?.trim();
    if (detail == null || detail.isEmpty) {
      return 'Firebase returned an unexpected error (${error.code}). Please check your Firebase setup.';
    }

    return 'Firebase returned an unexpected error (${error.code}): $detail';
  }

  static const _networkCodes = {
    'network-request-failed',
    'unavailable',
    'deadline-exceeded',
  };

  static const _configurationCodes = {
    'api-key-not-valid':
        'Firebase API key is not valid. Check the FIREBASE_WEB_API_KEY value.',
    'app-not-authorized':
        'This app is not authorized for your Firebase project. Check the app registration in Firebase Console.',
    'configuration-not-found':
        'Firebase Authentication is not configured. Enable Email/Password sign-in in Firebase Console.',
    'invalid-api-key':
        'Firebase API key is not valid. Check the FIREBASE_WEB_API_KEY value.',
    'missing-api-key':
        'Firebase API key is missing. Add FIREBASE_WEB_API_KEY to your .env file.',
  };

  static const _permissionCodes = {'permission-denied', 'unauthorized'};

  static const _notFoundCodes = {'not-found', 'user-not-found'};

  static const _unavailableCodes = {'internal', 'resource-exhausted'};

  static const _authCodes = {
    'invalid-email': 'Enter a valid email address.',
    'invalid-credential': 'The email or password is incorrect.',
    'wrong-password': 'The email or password is incorrect.',
    'email-already-in-use': 'An account already exists for this email.',
    'operation-not-allowed':
        'Email/password sign-in is disabled. Enable it in Firebase Console.',
    'weak-password': 'Password must be at least 6 characters.',
    'user-disabled': 'This account has been disabled.',
    'too-many-requests': 'Too many attempts. Please wait and try again.',
  };
}

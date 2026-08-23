import 'dart:async';
import 'dart:io';

import 'package:firedart/auth/exceptions.dart';
import 'package:firedart/firedart.dart';

import 'app_failure.dart';

class FirebaseErrorMapper {
  const FirebaseErrorMapper();

  AppFailure map(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return AppFailure(
        type: AppFailureType.network,
        code: 'network-request-failed',
        message:
            'Network connection failed. Check your connection and try again.',
        details: error,
      );
    }
    if (error is AuthException) return _mapAuthException(error);
    if (error is SignedOutException) {
      return AppFailure(
        type: AppFailureType.authentication,
        code: 'signed-out',
        message: 'Your session has expired. Please sign in again.',
        details: error,
      );
    }
    if (error is GrpcError) return _mapGrpcError(error);
    return AppFailure(
      type: AppFailureType.unknown,
      message: 'Something went wrong. Please try again.',
      details: error,
    );
  }

  AppFailure _mapAuthException(AuthException error) {
    final code = error.errorCode.toLowerCase().replaceAll('_', '-');
    final mappedCode = switch (code) {
      'email-not-found' ||
      'invalid-password' ||
      'invalid-login-credentials' => 'invalid-credential',
      'email-exists' => 'email-already-in-use',
      'too-many-attempts-try-later' => 'too-many-requests',
      _ => code,
    };
    if (_configurationCodes.containsKey(mappedCode)) {
      return AppFailure(
        type: AppFailureType.configuration,
        code: mappedCode,
        message: _configurationCodes[mappedCode]!,
        details: error,
      );
    }
    if (_authCodes.containsKey(mappedCode)) {
      return AppFailure(
        type: AppFailureType.authentication,
        code: mappedCode,
        message: _authCodes[mappedCode]!,
        details: error,
      );
    }
    return AppFailure(
      type: AppFailureType.authentication,
      code: mappedCode,
      message: 'Firebase Authentication returned an unexpected error.',
      details: error,
    );
  }

  AppFailure _mapGrpcError(GrpcError error) {
    return switch (error.code) {
      5 => AppFailure(
        type: AppFailureType.notFound,
        code: 'not-found',
        message: 'The requested data could not be found.',
        details: error,
      ),
      7 => AppFailure(
        type: AppFailureType.authorization,
        code: 'permission-denied',
        message: 'You do not have permission to do that.',
        details: error,
      ),
      14 => AppFailure(
        type: AppFailureType.network,
        code: 'unavailable',
        message:
            'Network connection failed. Check your connection and try again.',
        details: error,
      ),
      16 => AppFailure(
        type: AppFailureType.authentication,
        code: 'unauthenticated',
        message: 'Your session has expired. Please sign in again.',
        details: error,
      ),
      _ => AppFailure(
        type: AppFailureType.unknown,
        code: 'firestore-${error.code}',
        message: 'Firestore returned an unexpected error. Please try again.',
        details: error,
      ),
    };
  }

  static const _configurationCodes = {
    'api-key-not-valid':
        'Firebase API key is not valid. Check the FIREBASE_WEB_API_KEY value.',
    'invalid-api-key':
        'Firebase API key is not valid. Check the FIREBASE_WEB_API_KEY value.',
    'operation-not-allowed':
        'Email/password sign-in is disabled. Enable it in Firebase Console.',
  };

  static const _authCodes = {
    'invalid-email': 'Enter a valid email address.',
    'invalid-credential': 'The email or password is incorrect.',
    'email-already-in-use': 'An account already exists for this email.',
    'weak-password': 'Password must be at least 6 characters.',
    'user-disabled': 'This account has been disabled.',
    'too-many-requests': 'Too many attempts. Please wait and try again.',
  };
}

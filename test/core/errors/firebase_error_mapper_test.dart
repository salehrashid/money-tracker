import 'package:firedart/auth/exceptions.dart';
import 'package:firedart/firedart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/errors/app_failure.dart';
import 'package:money_tracker/core/errors/firebase_error_mapper.dart';

void main() {
  const mapper = FirebaseErrorMapper();

  test('maps Firedart credential errors to a safe message', () {
    final failure = mapper.map(_authError('INVALID_LOGIN_CREDENTIALS'));

    expect(failure.type, AppFailureType.authentication);
    expect(failure.message, 'The email or password is incorrect.');
    expect(failure.code, 'invalid-credential');
  });

  test('maps Firestore network errors without exposing raw details', () {
    final failure = mapper.map(GrpcError.unavailable('Low-level details'));

    expect(failure.type, AppFailureType.network);
    expect(failure.message, contains('Network connection failed'));
  });

  test('maps Firebase configuration errors to actionable messages', () {
    final failure = mapper.map(_authError('OPERATION_NOT_ALLOWED'));

    expect(failure.type, AppFailureType.configuration);
    expect(failure.message, contains('Enable it in Firebase Console'));
  });

  test('keeps unknown auth codes safe', () {
    final failure = mapper.map(_authError('UNEXPECTED_AUTH_CODE'));

    expect(failure.type, AppFailureType.authentication);
    expect(failure.code, 'unexpected-auth-code');
    expect(failure.message, isNot(contains('provider details')));
  });

  test('maps Firestore permission errors', () {
    final failure = mapper.map(GrpcError.permissionDenied('rules details'));

    expect(failure.type, AppFailureType.authorization);
    expect(failure.code, 'permission-denied');
  });

  test('maps unknown errors to a generic failure', () {
    final failure = mapper.map(StateError('internal details'));

    expect(failure.type, AppFailureType.unknown);
    expect(failure.message, 'Something went wrong. Please try again.');
  });
}

AuthException _authError(String code) {
  return AuthException('{"error":{"message":"$code : provider details"}}');
}

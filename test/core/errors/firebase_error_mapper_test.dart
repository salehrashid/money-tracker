import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/errors/app_failure.dart';
import 'package:money_tracker/core/errors/firebase_error_mapper.dart';

void main() {
  const mapper = FirebaseErrorMapper();

  test('maps Firebase Auth credential errors to a safe message', () {
    final failure = mapper.map(
      FirebaseException(
        plugin: 'firebase_auth',
        code: 'invalid-credential',
        message: 'Sensitive provider message',
      ),
    );

    expect(failure.type, AppFailureType.authentication);
    expect(failure.message, 'The email or password is incorrect.');
    expect(failure.code, 'invalid-credential');
  });

  test('maps network errors without exposing raw Firebase messages', () {
    final failure = mapper.map(
      FirebaseException(
        plugin: 'firebase_auth',
        code: 'network-request-failed',
        message: 'Low-level network details',
      ),
    );

    expect(failure.type, AppFailureType.network);
    expect(failure.message, contains('Network connection failed'));
  });

  test('maps unknown non-Firebase errors to a generic failure', () {
    final failure = mapper.map(StateError('internal details'));

    expect(failure.type, AppFailureType.unknown);
    expect(failure.message, 'Something went wrong. Please try again.');
  });
}

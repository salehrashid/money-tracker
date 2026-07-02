import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/firebase/firebase_environment.dart';
import 'package:money_tracker/core/utils/result.dart';

void main() {
  tearDown(dotenv.clean);

  test('loads Firebase options from dotenv', () {
    dotenv.loadFromString(
      envString: '''
FIREBASE_PROJECT_ID=test-project
FIREBASE_WEB_API_KEY=test-api-key
FIREBASE_MESSAGING_SENDER_ID=123456789
FIREBASE_APP_ID=1:123456789:web:abcdef
FIREBASE_ANDROID_APP_ID=1:123456789:android:abcdef
''',
    );

    final result = FirebaseEnvironment.optionsForCurrentPlatform();

    expect(result, isA<Success>());
    final options = (result as Success).value;
    expect(options.projectId, 'test-project');
    expect(options.apiKey, 'test-api-key');
    expect(options.messagingSenderId, '123456789');
    expect(
      options.appId,
      defaultTargetPlatform == TargetPlatform.android
          ? '1:123456789:android:abcdef'
          : '1:123456789:web:abcdef',
    );
  });

  test('requires the dotenv Firebase keys used by the app', () {
    dotenv.loadFromString(envString: '', isOptional: true);

    final result = FirebaseEnvironment.optionsForCurrentPlatform();

    expect(result, isA<Failure>());
    final failure = (result as Failure).failure;
    expect(failure.details, contains('FIREBASE_PROJECT_ID'));
    expect(failure.details, contains('FIREBASE_WEB_API_KEY'));
    expect(failure.details, contains('FIREBASE_MESSAGING_SENDER_ID'));
    expect(
      failure.details,
      contains(
        defaultTargetPlatform == TargetPlatform.android
            ? 'FIREBASE_ANDROID_APP_ID or FIREBASE_APP_ID'
            : 'FIREBASE_APP_ID',
      ),
    );
  });

  test('allows Android app id from FIREBASE_APP_ID for local env files', () {
    dotenv.loadFromString(
      envString: '''
FIREBASE_PROJECT_ID=test-project
FIREBASE_WEB_API_KEY=test-api-key
FIREBASE_MESSAGING_SENDER_ID=123456789
FIREBASE_APP_ID=1:123456789:android:abcdef
''',
    );

    final result = FirebaseEnvironment.optionsForCurrentPlatform();

    if (defaultTargetPlatform == TargetPlatform.android) {
      expect(result, isA<Success>());
      final options = (result as Success).value;
      expect(options.appId, '1:123456789:android:abcdef');
    }
  });
}

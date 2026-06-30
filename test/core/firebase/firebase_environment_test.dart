import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/firebase/firebase_environment.dart';
import 'package:money_tracker/core/utils/result.dart';

void main() {
  tearDown(dotenv.clean);

  test('loads Firebase project id and web API key from dotenv', () {
    dotenv.loadFromString(
      envString: '''
FIREBASE_PROJECT_ID=test-project
FIREBASE_WEB_API_KEY=test-api-key
''',
    );

    final result = FirebaseEnvironment.optionsForCurrentPlatform();

    expect(result, isA<Success>());
    final options = (result as Success).value;
    expect(options.projectId, 'test-project');
    expect(options.apiKey, 'test-api-key');
  });

  test('requires the dotenv Firebase keys used by the app', () {
    dotenv.loadFromString(envString: '', isOptional: true);

    final result = FirebaseEnvironment.optionsForCurrentPlatform();

    expect(result, isA<Failure>());
    final failure = (result as Failure).failure;
    expect(failure.details, contains('FIREBASE_PROJECT_ID'));
    expect(failure.details, contains('FIREBASE_WEB_API_KEY'));
  });
}

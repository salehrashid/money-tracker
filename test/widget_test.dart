import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:money_tracker/core/errors/app_failure.dart';
import 'package:money_tracker/core/utils/result.dart';
import 'package:money_tracker/main.dart';

void main() {
  testWidgets('shows startup failure when Firebase is unavailable', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MyApp(
        firebaseResult: Failure(
          AppFailure(
            type: AppFailureType.configuration,
            message: 'Firebase is not configured for this build.',
          ),
        ),
        sharedPreferences: sharedPreferences,
      ),
    );

    expect(find.text('Unable to start Fleeca'), findsOneWidget);
    expect(
      find.text('Firebase is not configured for this build.'),
      findsOneWidget,
    );
  });
}

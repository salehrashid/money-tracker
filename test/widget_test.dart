import 'package:flutter_test/flutter_test.dart';

import 'package:money_tracker/core/errors/app_failure.dart';
import 'package:money_tracker/core/utils/result.dart';
import 'package:money_tracker/main.dart';

void main() {
  testWidgets('shows startup failure when Firebase is unavailable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MyApp(
        firebaseResult: Failure(
          AppFailure(
            type: AppFailureType.configuration,
            message: 'Firebase is not configured for this build.',
          ),
        ),
      ),
    );

    expect(find.text('Unable to start Money Tracker'), findsOneWidget);
    expect(
      find.text('Firebase is not configured for this build.'),
      findsOneWidget,
    );
  });
}

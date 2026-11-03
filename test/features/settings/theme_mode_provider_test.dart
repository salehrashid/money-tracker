import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/settings/data/dto/financial_settings_dto.dart';
import 'package:money_tracker/features/settings/presentation/providers/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads and persists dark mode using only local preferences', () async {
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(container.read(darkModeProvider), isFalse);

    await container.read(darkModeProvider.notifier).setDarkMode(true);

    expect(container.read(darkModeProvider), isTrue);
    expect(preferences.getBool('isDarkMode'), isTrue);

    final reloaded = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(reloaded.dispose);
    expect(reloaded.read(darkModeProvider), isTrue);
  });

  test('ignores legacy remote dark mode fields', () {
    final settings = FinancialSettingsDto.fromMap({
      'id': 'app',
      'financialCycleDay': 20,
      'isDarkMode': true,
    });

    expect(settings.toFirestore(), {'id': 'app', 'financialCycleDay': 20});
  });
}

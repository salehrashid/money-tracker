import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _darkModePreferenceKey = 'isDarkMode';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be provided at startup.');
});

final darkModeProvider = NotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);

class DarkModeNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_darkModePreferenceKey) ??
      false;

  Future<void> setDarkMode(bool isDarkMode) async {
    final previous = state;
    state = isDarkMode;
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setBool(_darkModePreferenceKey, isDarkMode);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

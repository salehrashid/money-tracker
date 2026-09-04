import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/financial_cycle/financial_cycle_service.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../core/offline/sync_coordinator.dart';
import '../../../../core/utils/result.dart';
import '../../data/dto/financial_settings_dto.dart';
import '../../data/repositories/local_financial_settings_repository.dart';
import '../../domain/entities/financial_settings.dart';
import '../../domain/repositories/financial_settings_repository.dart';

final financialSettingsRepositoryProvider =
    Provider.family<FinancialSettingsRepository, String>((ref, userId) {
      return LocalFinancialSettingsRepository(
        local: LocalFirstCollection<FinancialSettings>(
          userId: userId,
          collection: 'settings',
          database: ref.watch(offlineDatabaseProvider),
          coordinator: ref.watch(syncCoordinatorProvider(userId)),
          fromMap: (map) => FinancialSettingsDto.fromMap(map).toDomain(),
          toMap: (value) =>
              FinancialSettingsDto.fromDomain(value).toFirestore(),
          idOf: (value) => value.id,
          isDeleted: (_) => false,
        ),
      );
    });

final financialSettingsProvider =
    StreamProvider.family<Result<FinancialSettings?>, String>((ref, userId) {
      return ref
          .watch(financialSettingsRepositoryProvider(userId))
          .watchSettings();
    });

final financialCycleDayProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) async* {
  final repository = ref.watch(financialSettingsRepositoryProvider(userId));
  await for (final state in repository.watchSettings()) {
    yield state.when(
      success: (settings) => const FinancialCycleService().normalizeCycleDay(
        settings?.financialCycleDay,
      ),
      failure: (_) => FinancialCycleService.defaultCycleDay,
    );
  }
});

final saveFinancialSettingsProvider =
    Provider.family<Future<Result<void>> Function(int), String>((ref, userId) {
      return (day) => ref
          .read(financialSettingsRepositoryProvider(userId))
          .saveSettings(
            FinancialSettings(
              financialCycleDay: day,
              isDarkMode: _currentSettings(ref, userId)?.isDarkMode ?? false,
            ),
          );
    });

final saveDarkModeProvider =
    Provider.family<Future<Result<void>> Function(bool), String>((ref, userId) {
      return (isDarkMode) => ref
          .read(financialSettingsRepositoryProvider(userId))
          .saveSettings(
            FinancialSettings(
              financialCycleDay:
                  _currentSettings(ref, userId)?.financialCycleDay ??
                  FinancialCycleService.defaultCycleDay,
              isDarkMode: isDarkMode,
            ),
          );
    });

FinancialSettings? _currentSettings(Ref ref, String userId) {
  final result = ref.read(financialSettingsProvider(userId)).value;
  return result?.when(success: (settings) => settings, failure: (_) => null);
}

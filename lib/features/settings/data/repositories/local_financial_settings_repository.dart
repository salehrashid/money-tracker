import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/offline/sync_coordinator.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/financial_settings.dart';
import '../../domain/repositories/financial_settings_repository.dart';

class LocalFinancialSettingsRepository implements FinancialSettingsRepository {
  LocalFinancialSettingsRepository({
    required LocalFirstCollection<FinancialSettings> local,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _local = local,
       _errorMapper = errorMapper;

  final LocalFirstCollection<FinancialSettings> _local;
  final FirebaseErrorMapper _errorMapper;

  @override
  Stream<Result<FinancialSettings?>> watchSettings() async* {
    await for (final settings in _local.watch()) {
      yield Success(settings.isEmpty ? null : settings.first);
    }
  }

  @override
  Future<Result<void>> saveSettings(FinancialSettings settings) async {
    try {
      await _local.save(settings, isCreate: _local.current.isEmpty);
      return const Success(null);
    } catch (error) {
      return Failure(
        error is FormatException
            ? AppFailure(
                type: AppFailureType.validation,
                code: 'invalid-financial-settings',
                message: 'Financial settings are invalid.',
                details: error,
              )
            : _errorMapper.map(error),
      );
    }
  }
}

import '../../../../core/utils/result.dart';
import '../entities/financial_settings.dart';

abstract interface class FinancialSettingsRepository {
  Stream<Result<FinancialSettings?>> watchSettings();

  Future<Result<void>> saveSettings(FinancialSettings settings);
}

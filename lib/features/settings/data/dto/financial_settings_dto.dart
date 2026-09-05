import '../../../../core/financial_cycle/financial_cycle_service.dart';
import '../../domain/entities/financial_settings.dart';

class FinancialSettingsDto {
  const FinancialSettingsDto({
    required this.id,
    required this.financialCycleDay,
    required this.isDarkMode,
  });

  final String id;
  final int financialCycleDay;
  final bool isDarkMode;

  factory FinancialSettingsDto.fromMap(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    final rawDay = data['financialCycleDay'];
    final day = rawDay is num && rawDay % 1 == 0 ? rawDay.toInt() : null;
    return FinancialSettingsDto(
      id: data['id'] is String && (data['id'] as String).isNotEmpty
          ? data['id'] as String
          : documentId ?? 'app',
      financialCycleDay: const FinancialCycleService().normalizeCycleDay(day),
      isDarkMode: data['isDarkMode'] == true,
    );
  }

  factory FinancialSettingsDto.fromDomain(FinancialSettings settings) {
    return FinancialSettingsDto(
      id: settings.id,
      financialCycleDay: const FinancialCycleService().normalizeCycleDay(
        settings.financialCycleDay,
      ),
      isDarkMode: settings.isDarkMode,
    );
  }

  FinancialSettings toDomain() {
    return FinancialSettings(
      id: id,
      financialCycleDay: financialCycleDay,
      isDarkMode: isDarkMode,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'financialCycleDay': financialCycleDay,
      'isDarkMode': isDarkMode,
    };
  }
}

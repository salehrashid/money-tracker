import '../../../../core/financial_cycle/financial_cycle_service.dart';
import '../../domain/entities/financial_settings.dart';

class FinancialSettingsDto {
  const FinancialSettingsDto({
    required this.id,
    required this.financialCycleDay,
  });

  final String id;
  final int financialCycleDay;

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
    );
  }

  factory FinancialSettingsDto.fromDomain(FinancialSettings settings) {
    return FinancialSettingsDto(
      id: settings.id,
      financialCycleDay: const FinancialCycleService().normalizeCycleDay(
        settings.financialCycleDay,
      ),
    );
  }

  FinancialSettings toDomain() {
    return FinancialSettings(id: id, financialCycleDay: financialCycleDay);
  }

  Map<String, dynamic> toFirestore() {
    return {'id': id, 'financialCycleDay': financialCycleDay};
  }
}

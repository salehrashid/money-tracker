class FinancialSettings {
  const FinancialSettings({
    this.id = 'app',
    required this.financialCycleDay,
    this.isDarkMode = false,
  });

  final String id;
  final int financialCycleDay;
  final bool isDarkMode;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'financial_cycle_service.dart';

final financialCycleServiceProvider = Provider<FinancialCycleService>((ref) {
  return const FinancialCycleService();
});

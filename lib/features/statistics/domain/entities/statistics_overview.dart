import '../../../../shared/models/finance_enums.dart';

class StatisticsOverview {
  const StatisticsOverview({
    required this.totalIncome,
    required this.totalExpense,
    required this.netCashFlow,
    required this.averageMonthlyIncome,
    required this.averageMonthlyExpense,
    required this.categoryBreakdown,
    required this.monthlyTrends,
    required this.sourceBreakdown,
  });

  final double totalIncome;
  final double totalExpense;
  final double netCashFlow;
  final double averageMonthlyIncome;
  final double averageMonthlyExpense;
  final List<StatisticsCategoryBreakdown> categoryBreakdown;
  final List<StatisticsMonthlyTrend> monthlyTrends;
  final List<StatisticsSourceBreakdown> sourceBreakdown;

  bool get isEmpty =>
      totalIncome == 0 &&
      totalExpense == 0 &&
      categoryBreakdown.isEmpty &&
      monthlyTrends.isEmpty &&
      sourceBreakdown.isEmpty;
}

class StatisticsCategoryBreakdown {
  const StatisticsCategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.type,
    required this.amount,
    required this.share,
    required this.transactionCount,
  });

  final String categoryId;
  final String categoryName;
  final TransactionType type;
  final double amount;
  final double share;
  final int transactionCount;
}

class StatisticsMonthlyTrend {
  const StatisticsMonthlyTrend({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });

  final int year;
  final int month;
  final double income;
  final double expense;

  double get netCashFlow => income - expense;
}

class StatisticsSourceBreakdown {
  const StatisticsSourceBreakdown({
    required this.source,
    required this.amount,
    required this.share,
    required this.transactionCount,
  });

  final TransactionSource source;
  final double amount;
  final double share;
  final int transactionCount;
}

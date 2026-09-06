import '../../../../shared/models/finance_enums.dart';
import '../../../transactions/domain/entities/transaction.dart';

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
    this.directAmount = 0,
    this.children = const [],
    this.typeShare,
    this.directTransactions = const [],
  });

  final String categoryId;
  final String categoryName;
  final TransactionType type;
  final double amount;
  final double share;
  final int transactionCount;
  final double directAmount;
  final List<StatisticsSubcategoryBreakdown> children;

  /// Share within income or expense. [share] remains the all-category share
  /// for compatibility with existing consumers.
  final double? typeShare;
  final List<TransactionEntity> directTransactions;
}

class StatisticsSubcategoryBreakdown {
  const StatisticsSubcategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.share,
    required this.transactionCount,
    this.transactions = const [],
  });
  final String categoryId;
  final String categoryName;
  final double amount;
  final double share;
  final int transactionCount;
  final List<TransactionEntity> transactions;
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

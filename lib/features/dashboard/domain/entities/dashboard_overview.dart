import '../../../../shared/models/finance_enums.dart';

class DashboardOverview {
  const DashboardOverview({
    required this.totalBalance,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.netCashFlow,
    required this.recentTransactions,
    required this.expenseBreakdown,
  });

  final double totalBalance;
  final double monthlyIncome;
  final double monthlyExpense;
  final double netCashFlow;
  final List<DashboardRecentTransaction> recentTransactions;
  final List<DashboardExpenseBreakdown> expenseBreakdown;

  bool get isEmpty =>
      totalBalance == 0 &&
      monthlyIncome == 0 &&
      monthlyExpense == 0 &&
      recentTransactions.isEmpty &&
      expenseBreakdown.isEmpty;
}

class DashboardRecentTransaction {
  const DashboardRecentTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryName,
    required this.accountName,
    required this.note,
    required this.transactionDate,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final String categoryName;
  final String accountName;
  final String note;
  final DateTime transactionDate;
}

class DashboardExpenseBreakdown {
  const DashboardExpenseBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.share,
  });

  final String categoryId;
  final String categoryName;
  final double amount;
  final double share;
}

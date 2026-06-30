import '../../../../shared/models/finance_enums.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../domain/entities/dashboard_overview.dart';

class BuildDashboardOverviewUseCase {
  const BuildDashboardOverviewUseCase();

  DashboardOverview execute({
    required List<Account> accounts,
    required List<Category> categories,
    required List<TransactionEntity> transactions,
    required DateTime now,
  }) {
    final activeAccounts = accounts.where((account) => !account.isArchived);
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final accountById = {for (final account in accounts) account.id: account};

    var totalBalance = activeAccounts.fold<double>(
      0,
      (total, account) => total + account.openingBalance,
    );
    var monthlyIncome = 0.0;
    var monthlyExpense = 0.0;
    final expenseByCategory = <String, double>{};

    for (final transaction in transactions.where((item) => !item.isDeleted)) {
      if (transaction.type == TransactionType.income) {
        totalBalance += transaction.amount;
      } else {
        totalBalance -= transaction.amount;
      }

      if (_isSameLocalMonth(transaction.transactionDate, now)) {
        if (transaction.type == TransactionType.income) {
          monthlyIncome += transaction.amount;
        } else {
          monthlyExpense += transaction.amount;
          expenseByCategory.update(
            transaction.categoryId,
            (amount) => amount + transaction.amount,
            ifAbsent: () => transaction.amount,
          );
        }
      }
    }

    final recentTransactions = [
      ...transactions.where((item) => !item.isDeleted),
    ]..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    final expenseTotal = expenseByCategory.values.fold<double>(
      0,
      (total, amount) => total + amount,
    );
    final expenseBreakdown =
        expenseByCategory.entries
            .map(
              (entry) => DashboardExpenseBreakdown(
                categoryId: entry.key,
                categoryName:
                    categoryById[entry.key]?.name ?? 'Unknown category',
                amount: entry.value,
                share: expenseTotal == 0 ? 0 : entry.value / expenseTotal,
              ),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    return DashboardOverview(
      totalBalance: totalBalance,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      netCashFlow: monthlyIncome - monthlyExpense,
      recentTransactions: recentTransactions
          .take(5)
          .map(
            (transaction) => DashboardRecentTransaction(
              id: transaction.id,
              type: transaction.type,
              amount: transaction.amount,
              categoryName:
                  categoryById[transaction.categoryId]?.name ??
                  'Unknown category',
              accountName:
                  accountById[transaction.accountId]?.name ?? 'Unknown account',
              note: transaction.note,
              transactionDate: transaction.transactionDate,
            ),
          )
          .toList(),
      expenseBreakdown: expenseBreakdown.take(5).toList(),
    );
  }

  bool _isSameLocalMonth(DateTime value, DateTime now) {
    final localValue = value.toLocal();
    final localNow = now.toLocal();
    return localValue.year == localNow.year &&
        localValue.month == localNow.month;
  }
}

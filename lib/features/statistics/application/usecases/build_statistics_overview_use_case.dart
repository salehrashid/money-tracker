import '../../../../shared/models/finance_enums.dart';
import '../../../../core/financial_cycle/financial_cycle_service.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../domain/entities/statistics_overview.dart';

class BuildStatisticsOverviewUseCase {
  const BuildStatisticsOverviewUseCase();

  StatisticsOverview execute({
    required List<Account> accounts,
    required List<Category> categories,
    required List<TransactionEntity> transactions,
    required DateTime now,
    int financialCycleDay = FinancialCycleService.defaultCycleDay,
    bool useFinancialCycles = false,
  }) {
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final accountById = {for (final account in accounts) account.id: account};
    final activeTransactions = transactions
        .where((transaction) => !transaction.isDeleted)
        .where((transaction) {
          final account = accountById[transaction.accountId];
          return account == null || !account.isArchived;
        });

    var totalIncome = 0.0;
    var totalExpense = 0.0;
    final amountByCategory = <String, double>{};
    final countByCategory = <String, int>{};
    final directAmountByCategory = <String, double>{};
    final rawAmountByCategory = <String, double>{};
    final rawCountByCategory = <String, int>{};
    final transactionsByCategory = <String, List<TransactionEntity>>{};
    final amountBySource = <TransactionSource, double>{};
    final countBySource = <TransactionSource, int>{};
    final monthlyBuckets = <_MonthKey, _MonthlyTotals>{};
    final service = const FinancialCycleService();
    final trendBase = useFinancialCycles
        ? service
              .periodByOffset(date: now, cycleDay: financialCycleDay, offset: 0)
              .start
        : now.toLocal();
    final startMonth = _MonthKey(
      trendBase.year,
      trendBase.month,
    ).minusMonths(5);

    for (var offset = 0; offset < 6; offset++) {
      monthlyBuckets[startMonth.plusMonths(offset)] = _MonthlyTotals();
    }

    for (final transaction in activeTransactions) {
      if (transaction.type == TransactionType.income) {
        totalIncome += transaction.amount;
      } else {
        totalExpense += transaction.amount;
      }

      final category = categoryById[transaction.categoryId];
      final groupingId =
          category?.parentCategoryId != null &&
              categoryById[category!.parentCategoryId]?.type == transaction.type
          ? category.parentCategoryId!
          : transaction.categoryId;
      rawAmountByCategory.update(
        transaction.categoryId,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
      rawCountByCategory.update(
        transaction.categoryId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      transactionsByCategory
          .putIfAbsent(transaction.categoryId, () => [])
          .add(transaction);
      if (groupingId == transaction.categoryId) {
        directAmountByCategory.update(
          groupingId,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
      amountByCategory.update(
        groupingId,
        (amount) => amount + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
      countByCategory.update(
        groupingId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      amountBySource.update(
        transaction.source,
        (amount) => amount + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
      countBySource.update(
        transaction.source,
        (count) => count + 1,
        ifAbsent: () => 1,
      );

      final localDate = transaction.transactionDate.toLocal();
      final financialPeriod = useFinancialCycles
          ? service.getFinancialPeriod(localDate, financialCycleDay)
          : null;
      final monthKey = financialPeriod == null
          ? _MonthKey(localDate.year, localDate.month)
          : _MonthKey(financialPeriod.start.year, financialPeriod.start.month);
      final monthlyTotals = monthlyBuckets[monthKey];
      if (monthlyTotals != null) {
        if (transaction.type == TransactionType.income) {
          monthlyTotals.income += transaction.amount;
        } else {
          monthlyTotals.expense += transaction.amount;
        }
      }
    }

    final sourceTotal = amountBySource.values.fold<double>(
      0,
      (total, amount) => total + amount,
    );
    final categoryTotal = amountByCategory.values.fold<double>(
      0,
      (total, amount) => total + amount,
    );
    final categoryBreakdown = amountByCategory.entries.map((entry) {
      final category = categoryById[entry.key];
      final children =
          categories
              .where(
                (item) =>
                    item.parentCategoryId == entry.key &&
                    item.type == category?.type,
              )
              .where((item) => (rawAmountByCategory[item.id] ?? 0) != 0)
              .map(
                (item) => StatisticsSubcategoryBreakdown(
                  categoryId: item.id,
                  categoryName: item.name,
                  amount: rawAmountByCategory[item.id] ?? 0,
                  share: entry.value == 0
                      ? 0
                      : (rawAmountByCategory[item.id] ?? 0) / entry.value,
                  transactionCount: rawCountByCategory[item.id] ?? 0,
                  transactions: transactionsByCategory[item.id] ?? const [],
                ),
              )
              .toList()
            ..sort((a, b) => b.amount.compareTo(a.amount));
      return StatisticsCategoryBreakdown(
        categoryId: entry.key,
        categoryName: category?.name ?? 'Unknown category',
        type: category?.type ?? TransactionType.expense,
        amount: entry.value,
        share: categoryTotal == 0 ? 0 : entry.value / categoryTotal,
        transactionCount: countByCategory[entry.key] ?? 0,
        directAmount: directAmountByCategory[entry.key] ?? 0,
        children: children,
        directTransactions: transactionsByCategory[entry.key] ?? const [],
        typeShare:
            (category?.type == TransactionType.income
                    ? totalIncome
                    : totalExpense) ==
                0
            ? 0
            : entry.value /
                  (category?.type == TransactionType.income
                      ? totalIncome
                      : totalExpense),
      );
    }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    final sourceBreakdown = amountBySource.entries.map((entry) {
      return StatisticsSourceBreakdown(
        source: entry.key,
        amount: entry.value,
        share: sourceTotal == 0 ? 0 : entry.value / sourceTotal,
        transactionCount: countBySource[entry.key] ?? 0,
      );
    }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    final monthlyTrends = monthlyBuckets.entries
        .map(
          (entry) => StatisticsMonthlyTrend(
            year: entry.key.year,
            month: entry.key.month,
            income: entry.value.income,
            expense: entry.value.expense,
          ),
        )
        .toList();

    return StatisticsOverview(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netCashFlow: totalIncome - totalExpense,
      averageMonthlyIncome: totalIncome / 6,
      averageMonthlyExpense: totalExpense / 6,
      categoryBreakdown: categoryBreakdown,
      monthlyTrends: monthlyTrends,
      sourceBreakdown: sourceBreakdown,
    );
  }
}

class _MonthlyTotals {
  var income = 0.0;
  var expense = 0.0;
}

class _MonthKey {
  const _MonthKey(this.year, this.month);

  final int year;
  final int month;

  _MonthKey plusMonths(int value) {
    final date = DateTime(year, month + value);
    return _MonthKey(date.year, date.month);
  }

  _MonthKey minusMonths(int value) {
    return plusMonths(-value);
  }

  @override
  bool operator ==(Object other) {
    return other is _MonthKey && other.year == year && other.month == month;
  }

  @override
  int get hashCode => Object.hash(year, month);
}

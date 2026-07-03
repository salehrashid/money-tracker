import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/accounts/domain/entities/account.dart';
import 'package:money_tracker/features/categories/domain/entities/category.dart';
import 'package:money_tracker/features/statistics/application/usecases/build_statistics_overview_use_case.dart';
import 'package:money_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

void main() {
  group('BuildStatisticsOverviewUseCase', () {
    test('builds totals, category distribution, sources, and trends', () {
      final overview = const BuildStatisticsOverviewUseCase().execute(
        accounts: [
          _account(id: 'cash', name: 'Cash'),
          _account(id: 'old', name: 'Old account', isArchived: true),
        ],
        categories: [
          _category(id: 'salary', name: 'Salary', type: TransactionType.income),
          _category(id: 'food', name: 'Food'),
          _category(id: 'rent', name: 'Rent'),
        ],
        transactions: [
          _transaction(
            id: 'salary',
            type: TransactionType.income,
            amount: 300000,
            categoryId: 'salary',
            source: TransactionSource.manual,
            transactionDate: DateTime.utc(2026, 7, 1),
          ),
          _transaction(
            id: 'food',
            amount: 50000,
            categoryId: 'food',
            source: TransactionSource.csv,
            transactionDate: DateTime.utc(2026, 7, 2),
          ),
          _transaction(
            id: 'rent',
            amount: 100000,
            categoryId: 'rent',
            source: TransactionSource.csv,
            transactionDate: DateTime.utc(2026, 6, 25),
          ),
          _transaction(
            id: 'archived-account',
            amount: 25000,
            categoryId: 'food',
            accountId: 'old',
            transactionDate: DateTime.utc(2026, 7, 2),
          ),
          _transaction(
            id: 'deleted',
            amount: 20000,
            categoryId: 'food',
            transactionDate: DateTime.utc(2026, 7, 3),
            deletedAt: DateTime.utc(2026, 7, 4),
          ),
        ],
        now: DateTime.utc(2026, 7, 3),
      );

      expect(overview.totalIncome, 300000);
      expect(overview.totalExpense, 150000);
      expect(overview.netCashFlow, 150000);
      expect(overview.averageMonthlyIncome, 50000);
      expect(overview.averageMonthlyExpense, 25000);
      expect(overview.categoryBreakdown.map((item) => item.categoryName), [
        'Salary',
        'Rent',
        'Food',
      ]);
      expect(overview.categoryBreakdown.first.share, closeTo(2 / 3, 0.001));
      expect(overview.sourceBreakdown.first.source, TransactionSource.manual);
      expect(overview.sourceBreakdown.first.transactionCount, 1);
      expect(overview.sourceBreakdown[1].source, TransactionSource.csv);
      expect(overview.sourceBreakdown[1].transactionCount, 2);
      expect(
        overview.monthlyTrends.map((item) => '${item.year}-${item.month}'),
        ['2026-2', '2026-3', '2026-4', '2026-5', '2026-6', '2026-7'],
      );
      expect(overview.monthlyTrends.last.income, 300000);
      expect(overview.monthlyTrends.last.expense, 50000);
    });
  });
}

Account _account({
  required String id,
  required String name,
  bool isArchived = false,
}) {
  final now = DateTime.utc(2026);
  return Account(
    id: id,
    name: name,
    type: AccountType.cash,
    currency: 'IDR',
    openingBalance: 0,
    isArchived: isArchived,
    createdAt: now,
    updatedAt: now,
  );
}

Category _category({
  required String id,
  required String name,
  TransactionType type = TransactionType.expense,
}) {
  final now = DateTime.utc(2026);
  return Category(
    id: id,
    name: name,
    type: type,
    icon: 'category',
    color: '#009688',
    isDefault: false,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

TransactionEntity _transaction({
  required String id,
  TransactionType type = TransactionType.expense,
  required double amount,
  required String categoryId,
  String accountId = 'cash',
  TransactionSource source = TransactionSource.manual,
  required DateTime transactionDate,
  DateTime? deletedAt,
}) {
  final now = DateTime.utc(2026);
  return TransactionEntity(
    id: id,
    type: type,
    amount: amount,
    currency: 'IDR',
    categoryId: categoryId,
    accountId: accountId,
    note: '',
    source: source,
    transactionDate: transactionDate,
    createdAt: now,
    updatedAt: now,
    deletedAt: deletedAt,
  );
}

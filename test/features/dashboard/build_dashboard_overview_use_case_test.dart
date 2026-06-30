import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/accounts/domain/entities/account.dart';
import 'package:money_tracker/features/categories/domain/entities/category.dart';
import 'package:money_tracker/features/dashboard/application/usecases/build_dashboard_overview_use_case.dart';
import 'package:money_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

void main() {
  group('BuildDashboardOverviewUseCase', () {
    test(
      'builds totals, monthly values, recent items, and expense breakdown',
      () {
        final overview = const BuildDashboardOverviewUseCase().execute(
          accounts: [
            _account(id: 'cash', name: 'Cash', openingBalance: 100000),
            _account(
              id: 'archived',
              name: 'Archived',
              openingBalance: 500000,
              isArchived: true,
            ),
          ],
          categories: [
            _category(
              id: 'salary',
              name: 'Salary',
              type: TransactionType.income,
            ),
            _category(id: 'food', name: 'Food'),
            _category(id: 'rent', name: 'Rent'),
          ],
          transactions: [
            _transaction(
              id: 'income',
              type: TransactionType.income,
              amount: 250000,
              categoryId: 'salary',
              transactionDate: DateTime.utc(2026, 6, 20),
            ),
            _transaction(
              id: 'food',
              amount: 50000,
              categoryId: 'food',
              transactionDate: DateTime.utc(2026, 6, 21),
            ),
            _transaction(
              id: 'rent',
              amount: 100000,
              categoryId: 'rent',
              transactionDate: DateTime.utc(2026, 6, 3),
            ),
            _transaction(
              id: 'last-month',
              amount: 25000,
              categoryId: 'food',
              transactionDate: DateTime.utc(2026, 5, 29),
            ),
          ],
          now: DateTime.utc(2026, 6, 30),
        );

        expect(overview.totalBalance, 175000);
        expect(overview.monthlyIncome, 250000);
        expect(overview.monthlyExpense, 150000);
        expect(overview.netCashFlow, 100000);
        expect(overview.recentTransactions.map((item) => item.id), [
          'food',
          'income',
          'rent',
          'last-month',
        ]);
        expect(overview.expenseBreakdown.map((item) => item.categoryName), [
          'Rent',
          'Food',
        ]);
        expect(overview.expenseBreakdown.first.share, closeTo(2 / 3, 0.001));
      },
    );

    test('ignores deleted transactions', () {
      final overview = const BuildDashboardOverviewUseCase().execute(
        accounts: [_account(id: 'cash', name: 'Cash', openingBalance: 0)],
        categories: [_category(id: 'food', name: 'Food')],
        transactions: [
          _transaction(
            id: 'deleted',
            amount: 100000,
            categoryId: 'food',
            transactionDate: DateTime.utc(2026, 6, 1),
            deletedAt: DateTime.utc(2026, 6, 2),
          ),
        ],
        now: DateTime.utc(2026, 6, 30),
      );

      expect(overview.isEmpty, isTrue);
    });
  });
}

Account _account({
  required String id,
  required String name,
  required double openingBalance,
  bool isArchived = false,
}) {
  final now = DateTime.utc(2026);
  return Account(
    id: id,
    name: name,
    type: AccountType.cash,
    currency: 'IDR',
    openingBalance: openingBalance,
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
    accountId: 'cash',
    note: '',
    source: TransactionSource.manual,
    transactionDate: transactionDate,
    createdAt: now,
    updatedAt: now,
    deletedAt: deletedAt,
  );
}

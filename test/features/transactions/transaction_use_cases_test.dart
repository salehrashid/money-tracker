import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/utils/result.dart';
import 'package:money_tracker/features/accounts/domain/entities/account.dart';
import 'package:money_tracker/features/categories/domain/entities/category.dart';
import 'package:money_tracker/features/transactions/application/usecases/transaction_commands.dart';
import 'package:money_tracker/features/transactions/application/usecases/transaction_filter.dart';
import 'package:money_tracker/features/transactions/application/usecases/transaction_use_cases.dart';
import 'package:money_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:money_tracker/features/transactions/domain/entities/transaction_draft.dart';
import 'package:money_tracker/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

void main() {
  group('CreateTransactionUseCase', () {
    test('returns validation failure for a zero amount', () async {
      final repository = _FakeTransactionRepository();
      final useCase = CreateTransactionUseCase(repository);

      final result = await useCase.execute(
        SaveTransactionCommand(
          type: TransactionType.expense,
          amount: 0,
          categoryId: 'food',
          accountId: 'cash',
          note: 'Lunch',
          transactionDate: DateTime.utc(2026, 1, 1),
        ),
      );

      expect(result, isA<Failure<TransactionEntity>>());
      expect(repository.transactions, isEmpty);
    });

    test('creates a manual IDR transaction with trimmed text values', () async {
      final repository = _FakeTransactionRepository();
      final useCase = CreateTransactionUseCase(repository);

      final result = await useCase.execute(
        SaveTransactionCommand(
          type: TransactionType.expense,
          amount: 50000,
          categoryId: ' food ',
          accountId: ' cash ',
          note: ' Lunch ',
          transactionDate: DateTime.utc(2026, 1, 1),
        ),
      );

      final transaction = (result as Success<TransactionEntity>).value;
      expect(transaction.currency, 'IDR');
      expect(transaction.source, TransactionSource.manual);
      expect(transaction.categoryId, 'food');
      expect(transaction.accountId, 'cash');
      expect(transaction.note, 'Lunch');
      expect(repository.transactions.single.id, 'transaction-1');
    });
  });

  group('SaveTransactionDraftUseCase', () {
    test(
      'saves a pending myBCA draft as a transaction and marks it saved',
      () async {
        final draft = _draft(
          id: 'draft-1',
          draftType: TransactionDraftType.mybcaNotification,
        );
        final repository = _FakeTransactionRepository(drafts: [draft]);
        final useCase = SaveTransactionDraftUseCase(repository);

        final result = await useCase.execute(
          draft: draft,
          command: SaveTransactionCommand(
            type: TransactionType.income,
            amount: 125000,
            categoryId: 'salary',
            accountId: 'bank',
            note: 'Transfer masuk',
            transactionDate: DateTime.utc(2026, 1, 2),
          ),
        );

        final transaction = (result as Success<TransactionEntity>).value;
        expect(transaction.source, TransactionSource.mybcaNotification);
        expect(repository.transactions.single.amount, 125000);
        expect(repository.drafts.single.status, TransactionDraftStatus.saved);
      },
    );
  });

  group('ApplyTransactionFiltersUseCase', () {
    test('filters by search text across note, category, and account', () {
      const useCase = ApplyTransactionFiltersUseCase();
      final result = useCase.execute(
        transactions: [
          _transaction(
            id: 'transaction-1',
            note: 'Lunch at kantin',
            categoryId: 'food',
            accountId: 'cash',
          ),
          _transaction(
            id: 'transaction-2',
            note: 'Monthly pay',
            type: TransactionType.income,
            categoryId: 'salary',
            accountId: 'bank',
          ),
        ],
        categories: [
          _category(id: 'food', name: 'Food'),
          _category(id: 'salary', name: 'Salary', type: TransactionType.income),
        ],
        accounts: [
          _account(id: 'cash', name: 'Cash'),
          _account(id: 'bank', name: 'BCA'),
        ],
        criteria: const TransactionFilterCriteria(searchQuery: 'bca'),
      );

      expect(result.map((transaction) => transaction.id), ['transaction-2']);
    });

    test('filters by type, category, account, amount, and date range', () {
      const useCase = ApplyTransactionFiltersUseCase();
      final result = useCase.execute(
        transactions: [
          _transaction(
            id: 'transaction-1',
            amount: 25000,
            categoryId: 'food',
            accountId: 'cash',
            transactionDate: DateTime.utc(2026, 1, 1),
          ),
          _transaction(
            id: 'transaction-2',
            amount: 75000,
            categoryId: 'food',
            accountId: 'cash',
            transactionDate: DateTime.utc(2026, 1, 15),
          ),
          _transaction(
            id: 'transaction-3',
            amount: 100000,
            type: TransactionType.income,
            categoryId: 'salary',
            accountId: 'bank',
            transactionDate: DateTime.utc(2026, 1, 15),
          ),
        ],
        categories: [
          _category(id: 'food', name: 'Food'),
          _category(id: 'salary', name: 'Salary', type: TransactionType.income),
        ],
        accounts: [
          _account(id: 'cash', name: 'Cash'),
          _account(id: 'bank', name: 'BCA'),
        ],
        criteria: TransactionFilterCriteria(
          type: TransactionType.expense,
          categoryId: 'food',
          accountId: 'cash',
          startDate: DateTime(2026, 1, 10),
          endDate: DateTime(2026, 1, 31),
          minAmount: 50000,
          maxAmount: 80000,
        ),
      );

      expect(result.map((transaction) => transaction.id), ['transaction-2']);
    });
  });
}

class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository({
    List<TransactionEntity>? transactions,
    List<TransactionDraft>? drafts,
  }) : transactions = [...?transactions],
       drafts = [...?drafts];

  final List<TransactionEntity> transactions;
  final List<TransactionDraft> drafts;

  @override
  Stream<Result<List<TransactionEntity>>> watchTransactions() {
    return Stream.value(Success(transactions));
  }

  @override
  Stream<Result<List<TransactionDraft>>> watchPendingDrafts() {
    return Stream.value(Success(drafts));
  }

  @override
  Future<Result<TransactionEntity>> createTransaction(
    TransactionEntity transaction,
  ) async {
    final saved = transaction.copyWith(
      id: transaction.id.isEmpty
          ? 'transaction-${transactions.length + 1}'
          : transaction.id,
    );
    transactions.add(saved);
    return Success(saved);
  }

  @override
  Future<Result<TransactionEntity>> updateTransaction(
    TransactionEntity transaction,
  ) async {
    final index = transactions.indexWhere((item) => item.id == transaction.id);
    transactions[index] = transaction;
    return Success(transaction);
  }

  @override
  Future<Result<void>> deleteTransaction(String transactionId) async {
    transactions.removeWhere((transaction) => transaction.id == transactionId);
    return const Success(null);
  }

  @override
  Future<Result<TransactionEntity>> createTransactionFromDraft({
    required TransactionEntity transaction,
    required String draftId,
  }) async {
    final saved = transaction.copyWith(
      id: 'transaction-${transactions.length + 1}',
    );
    transactions.add(saved);
    final draftIndex = drafts.indexWhere((draft) => draft.id == draftId);
    drafts[draftIndex] = drafts[draftIndex].copyWith(
      status: TransactionDraftStatus.saved,
      updatedAt: saved.updatedAt,
    );
    return Success(saved);
  }
}

TransactionDraft _draft({
  required String id,
  TransactionDraftType draftType = TransactionDraftType.ocr,
}) {
  final now = DateTime.utc(2026);
  return TransactionDraft(
    id: id,
    draftType: draftType,
    detectedType: TransactionType.income,
    detectedAmount: 125000,
    detectedCurrency: 'IDR',
    detectedText: 'Transfer masuk',
    suggestedCategoryId: 'salary',
    status: TransactionDraftStatus.pendingReview,
    confidence: 0.95,
    createdAt: now,
    updatedAt: now,
  );
}

TransactionEntity _transaction({
  required String id,
  TransactionType type = TransactionType.expense,
  double amount = 50000,
  String categoryId = 'food',
  String accountId = 'cash',
  String note = 'Lunch',
  DateTime? transactionDate,
}) {
  final now = DateTime.utc(2026);
  return TransactionEntity(
    id: id,
    type: type,
    amount: amount,
    currency: 'IDR',
    categoryId: categoryId,
    accountId: accountId,
    note: note,
    source: TransactionSource.manual,
    transactionDate: transactionDate ?? now,
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
    icon: 'restaurant',
    color: '#2E7D32',
    isDefault: false,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

Account _account({required String id, required String name}) {
  final now = DateTime.utc(2026);
  return Account(
    id: id,
    name: name,
    type: AccountType.cash,
    currency: 'IDR',
    openingBalance: 0,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

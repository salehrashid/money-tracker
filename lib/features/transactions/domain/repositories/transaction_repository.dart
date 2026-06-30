import '../../../../core/utils/result.dart';
import '../entities/transaction.dart';
import '../entities/transaction_draft.dart';

abstract interface class TransactionRepository {
  Stream<Result<List<TransactionEntity>>> watchTransactions();

  Stream<Result<List<TransactionDraft>>> watchPendingDrafts();

  Future<Result<TransactionEntity>> createTransaction(
    TransactionEntity transaction,
  );

  Future<Result<TransactionEntity>> updateTransaction(
    TransactionEntity transaction,
  );

  Future<Result<void>> deleteTransaction(String transactionId);

  Future<Result<TransactionEntity>> createTransactionFromDraft({
    required TransactionEntity transaction,
    required String draftId,
  });
}

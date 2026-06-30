import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_draft.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/firebase_transaction_data_source.dart';
import '../dto/transaction_dto.dart';

class FirebaseTransactionRepository implements TransactionRepository {
  const FirebaseTransactionRepository({
    required FirebaseTransactionDataSource dataSource,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _dataSource = dataSource,
       _errorMapper = errorMapper;

  final FirebaseTransactionDataSource _dataSource;
  final FirebaseErrorMapper _errorMapper;

  @override
  Stream<Result<List<TransactionEntity>>> watchTransactions() async* {
    try {
      await for (final dtos in _dataSource.watchTransactions()) {
        final transactions = dtos.map((dto) => dto.toDomain()).toList()
          ..sort(_sortTransactions);
        yield Success(transactions);
      }
    } catch (error) {
      yield Failure(_mapError(error, 'transaction'));
    }
  }

  @override
  Stream<Result<List<TransactionDraft>>> watchPendingDrafts() async* {
    try {
      await for (final dtos in _dataSource.watchPendingDrafts()) {
        final drafts = dtos.map((dto) => dto.toDomain()).toList()
          ..sort(_sortDrafts);
        yield Success(drafts);
      }
    } catch (error) {
      yield Failure(_mapError(error, 'transaction draft'));
    }
  }

  @override
  Future<Result<TransactionEntity>> createTransaction(
    TransactionEntity transaction,
  ) async {
    try {
      final saved = await _dataSource.saveTransaction(
        TransactionDto.fromDomain(transaction),
      );
      return Success(saved.toDomain());
    } catch (error) {
      return Failure(_mapError(error, 'transaction'));
    }
  }

  @override
  Future<Result<TransactionEntity>> updateTransaction(
    TransactionEntity transaction,
  ) async {
    try {
      final current = await _dataSource.fetchTransaction(transaction.id);
      if (current == null || current.deletedAt != null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'transaction-not-found',
            message: 'Transaction not found.',
          ),
        );
      }

      final saved = await _dataSource.saveTransaction(
        TransactionDto.fromDomain(transaction),
      );
      return Success(saved.toDomain());
    } catch (error) {
      return Failure(_mapError(error, 'transaction'));
    }
  }

  @override
  Future<Result<void>> deleteTransaction(String transactionId) async {
    try {
      final current = await _dataSource.fetchTransaction(transactionId);
      if (current == null || current.deletedAt != null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'transaction-not-found',
            message: 'Transaction not found.',
          ),
        );
      }

      final now = DateTime.now().toUtc();
      await _dataSource.saveTransaction(
        TransactionDto.fromDomain(
          current.toDomain().copyWith(deletedAt: now, updatedAt: now),
        ),
      );
      return const Success(null);
    } catch (error) {
      return Failure(_mapError(error, 'transaction'));
    }
  }

  @override
  Future<Result<TransactionEntity>> createTransactionFromDraft({
    required TransactionEntity transaction,
    required String draftId,
  }) async {
    try {
      final draft = await _dataSource.fetchDraft(draftId);
      if (draft == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'transaction-draft-not-found',
            message: 'Transaction draft not found.',
          ),
        );
      }
      if (draft.status != TransactionDraftStatus.pendingReview) {
        return const Failure(
          AppFailure(
            type: AppFailureType.validation,
            code: 'transaction-draft-not-pending',
            message: 'This draft has already been reviewed.',
          ),
        );
      }

      final saved = await _dataSource.saveTransactionFromDraft(
        transaction: TransactionDto.fromDomain(transaction),
        draft: draft,
      );
      return Success(saved.toDomain());
    } catch (error) {
      return Failure(_mapError(error, 'transaction draft'));
    }
  }

  AppFailure _mapError(Object error, String modelName) {
    if (error is FormatException) {
      return AppFailure(
        type: AppFailureType.validation,
        code: 'invalid-${modelName.replaceAll(' ', '-')}-data',
        message: 'Saved $modelName data is invalid. Please try again.',
        details: error,
      );
    }

    return _errorMapper.map(error);
  }
}

int _sortTransactions(TransactionEntity first, TransactionEntity second) {
  return second.transactionDate.compareTo(first.transactionDate);
}

int _sortDrafts(TransactionDraft first, TransactionDraft second) {
  return second.createdAt.compareTo(first.createdAt);
}

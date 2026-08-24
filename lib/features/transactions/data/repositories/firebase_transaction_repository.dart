import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/offline/sync_coordinator.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_draft.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/firebase_transaction_data_source.dart';
import 'package:uuid/uuid.dart';

class FirebaseTransactionRepository implements TransactionRepository {
  FirebaseTransactionRepository({
    required FirebaseTransactionDataSource dataSource,
    required LocalFirstCollection<TransactionEntity> local,
    required LocalFirstCollection<TransactionDraft> localDrafts,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _local = local,
       _localDrafts = localDrafts,
       _errorMapper = errorMapper;

  final LocalFirstCollection<TransactionEntity> _local;
  final LocalFirstCollection<TransactionDraft> _localDrafts;
  final FirebaseErrorMapper _errorMapper;

  @override
  Stream<Result<List<TransactionEntity>>> watchTransactions() async* {
    await for (final values in _local.watch()) {
      values.sort(_sortTransactions);
      yield Success(values);
    }
  }

  @override
  Stream<Result<List<TransactionDraft>>> watchPendingDrafts() async* {
    await for (final drafts in _localDrafts.watch()) {
      final pending =
          drafts
              .where(
                (draft) => draft.status == TransactionDraftStatus.pendingReview,
              )
              .toList()
            ..sort(_sortDrafts);
      yield Success(pending);
    }
  }

  @override
  Future<Result<TransactionEntity>> createTransaction(
    TransactionEntity transaction,
  ) async {
    try {
      final saved = transaction.copyWith(id: const Uuid().v4());
      await _local.save(saved, isCreate: true);
      return Success(saved);
    } catch (error) {
      return Failure(_mapError(error, 'transaction'));
    }
  }

  @override
  Future<Result<TransactionEntity>> updateTransaction(
    TransactionEntity transaction,
  ) async {
    try {
      final current = _local.current
          .where((item) => item.id == transaction.id)
          .firstOrNull;
      if (current == null || current.deletedAt != null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'transaction-not-found',
            message: 'Transaction not found.',
          ),
        );
      }

      await _local.save(transaction, isCreate: false);
      return Success(transaction);
    } catch (error) {
      return Failure(_mapError(error, 'transaction'));
    }
  }

  @override
  Future<Result<void>> deleteTransaction(String transactionId) async {
    try {
      final current = _local.current
          .where((item) => item.id == transactionId)
          .firstOrNull;
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
      await _local.delete(current.copyWith(deletedAt: now, updatedAt: now));
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
      final draft = _localDrafts.current
          .where((item) => item.id == draftId)
          .firstOrNull;
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

      final saved = transaction.copyWith(id: const Uuid().v4());
      await _local.save(saved, isCreate: true);
      await _localDrafts.save(
        draft.copyWith(
          status: TransactionDraftStatus.saved,
          updatedAt: DateTime.now().toUtc(),
        ),
        isCreate: false,
      );
      return Success(saved);
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

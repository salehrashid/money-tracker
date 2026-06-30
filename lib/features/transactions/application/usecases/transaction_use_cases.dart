import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_draft.dart';
import '../../domain/repositories/transaction_repository.dart';
import 'transaction_commands.dart';

class WatchTransactionsUseCase {
  const WatchTransactionsUseCase(this._repository);

  final TransactionRepository _repository;

  Stream<Result<List<TransactionEntity>>> execute() {
    return _repository.watchTransactions();
  }
}

class WatchPendingTransactionDraftsUseCase {
  const WatchPendingTransactionDraftsUseCase(this._repository);

  final TransactionRepository _repository;

  Stream<Result<List<TransactionDraft>>> execute() {
    return _repository.watchPendingDrafts();
  }
}

class CreateTransactionUseCase {
  const CreateTransactionUseCase(this._repository);

  final TransactionRepository _repository;

  Future<Result<TransactionEntity>> execute(SaveTransactionCommand command) {
    final failure = _validate(command);
    if (failure != null) {
      return Future.value(Failure(failure));
    }

    final now = DateTime.now().toUtc();
    return _repository.createTransaction(
      TransactionEntity(
        id: '',
        type: command.type,
        amount: command.amount,
        currency: 'IDR',
        categoryId: command.categoryId.trim(),
        accountId: command.accountId.trim(),
        note: command.note.trim(),
        source: TransactionSource.manual,
        transactionDate: command.transactionDate.toUtc(),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

class UpdateTransactionUseCase {
  const UpdateTransactionUseCase(this._repository);

  final TransactionRepository _repository;

  Future<Result<TransactionEntity>> execute({
    required TransactionEntity transaction,
    required SaveTransactionCommand command,
  }) {
    final failure = _validate(command);
    if (failure != null) {
      return Future.value(Failure(failure));
    }

    return _repository.updateTransaction(
      transaction.copyWith(
        type: command.type,
        amount: command.amount,
        currency: 'IDR',
        categoryId: command.categoryId.trim(),
        accountId: command.accountId.trim(),
        note: command.note.trim(),
        source: transaction.source,
        transactionDate: command.transactionDate.toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}

class DeleteTransactionUseCase {
  const DeleteTransactionUseCase(this._repository);

  final TransactionRepository _repository;

  Future<Result<void>> execute(String transactionId) {
    if (transactionId.trim().isEmpty) {
      return Future.value(
        const Failure(
          AppFailure(
            type: AppFailureType.validation,
            code: 'missing-transaction-id',
            message: 'Choose a transaction first.',
          ),
        ),
      );
    }

    return _repository.deleteTransaction(transactionId);
  }
}

class SaveTransactionDraftUseCase {
  const SaveTransactionDraftUseCase(this._repository);

  final TransactionRepository _repository;

  Future<Result<TransactionEntity>> execute({
    required TransactionDraft draft,
    required SaveTransactionCommand command,
  }) {
    final failure = _validate(command);
    if (failure != null) {
      return Future.value(Failure(failure));
    }
    if (draft.status != TransactionDraftStatus.pendingReview) {
      return Future.value(
        const Failure(
          AppFailure(
            type: AppFailureType.validation,
            code: 'transaction-draft-not-pending',
            message: 'This draft has already been reviewed.',
          ),
        ),
      );
    }

    final now = DateTime.now().toUtc();
    return _repository.createTransactionFromDraft(
      draftId: draft.id,
      transaction: TransactionEntity(
        id: '',
        type: command.type,
        amount: command.amount,
        currency: 'IDR',
        categoryId: command.categoryId.trim(),
        accountId: command.accountId.trim(),
        note: command.note.trim(),
        source: _sourceForDraft(draft.draftType),
        transactionDate: command.transactionDate.toUtc(),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

AppFailure? _validate(SaveTransactionCommand command) {
  if (command.amount <= 0) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'invalid-transaction-amount',
      message: 'Enter an amount greater than zero.',
    );
  }
  if (command.categoryId.trim().isEmpty) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'missing-transaction-category',
      message: 'Choose a category.',
    );
  }
  if (command.accountId.trim().isEmpty) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'missing-transaction-account',
      message: 'Choose an account.',
    );
  }
  if (command.note.trim().length > 120) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'transaction-note-too-long',
      message: 'Note must be 120 characters or fewer.',
    );
  }

  return null;
}

TransactionSource _sourceForDraft(TransactionDraftType draftType) {
  return switch (draftType) {
    TransactionDraftType.ocr => TransactionSource.ocr,
    TransactionDraftType.csv => TransactionSource.csv,
    TransactionDraftType.mybcaNotification =>
      TransactionSource.mybcaNotification,
  };
}

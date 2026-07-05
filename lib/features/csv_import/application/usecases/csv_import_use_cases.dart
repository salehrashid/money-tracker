import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../domain/entities/csv_import_preview.dart';

class ConfirmCsvImportCommand {
  const ConfirmCsvImportCommand({
    required this.preview,
    required this.accountId,
    required this.expenseCategoryId,
    required this.incomeCategoryId,
  });

  final CsvImportPreview preview;
  final String accountId;
  final String expenseCategoryId;
  final String incomeCategoryId;
}

class CsvImportConfirmationResult {
  const CsvImportConfirmationResult({
    required this.importedRows,
    required this.skippedRows,
  });

  final int importedRows;
  final int skippedRows;
}

class ConfirmCsvImportUseCase {
  const ConfirmCsvImportUseCase(this._repository);

  final TransactionRepository _repository;

  Future<Result<CsvImportConfirmationResult>> execute(
    ConfirmCsvImportCommand command,
  ) async {
    final failure = _validate(command);
    if (failure != null) {
      return Failure(failure);
    }

    var importedRows = 0;
    for (final row in command.preview.rows.where((row) => row.canImport)) {
      final categoryId = row.type == TransactionType.income
          ? command.incomeCategoryId.trim()
          : command.expenseCategoryId.trim();
      final now = DateTime.now().toUtc();
      final result = await _repository.createTransaction(
        TransactionEntity(
          id: '',
          type: row.type!,
          amount: row.amount!,
          currency: 'IDR',
          categoryId: categoryId,
          accountId: command.accountId.trim(),
          note: row.note.trim(),
          source: TransactionSource.csv,
          transactionDate: row.transactionDate!.toUtc(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      if (result case Failure<TransactionEntity>(:final failure)) {
        return Failure(failure);
      }
      importedRows++;
    }

    return Success(
      CsvImportConfirmationResult(
        importedRows: importedRows,
        skippedRows: command.preview.totalRows - importedRows,
      ),
    );
  }

  AppFailure? _validate(ConfirmCsvImportCommand command) {
    if (!command.preview.hasImportableRows) {
      return const AppFailure(
        type: AppFailureType.validation,
        code: 'no-importable-csv-rows',
        message: 'There are no valid CSV rows to import.',
      );
    }
    if (command.accountId.trim().isEmpty) {
      return const AppFailure(
        type: AppFailureType.validation,
        code: 'missing-csv-account',
        message: 'Choose an account for imported transactions.',
      );
    }
    if (command.expenseCategoryId.trim().isEmpty &&
        command.preview.rows.any(
          (row) => row.type == TransactionType.expense,
        )) {
      return const AppFailure(
        type: AppFailureType.validation,
        code: 'missing-csv-expense-category',
        message: 'Choose an expense category for imported transactions.',
      );
    }
    if (command.incomeCategoryId.trim().isEmpty &&
        command.preview.rows.any((row) => row.type == TransactionType.income)) {
      return const AppFailure(
        type: AppFailureType.validation,
        code: 'missing-csv-income-category',
        message: 'Choose an income category for imported transactions.',
      );
    }

    return null;
  }
}

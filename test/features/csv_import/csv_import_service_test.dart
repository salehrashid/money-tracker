import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/utils/result.dart';
import 'package:money_tracker/features/csv_import/application/services/csv_import_service.dart';
import 'package:money_tracker/features/csv_import/domain/entities/csv_import_preview.dart';
import 'package:money_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

void main() {
  group('CsvImportService', () {
    const service = CsvImportService();

    test('builds a preview for valid CSV rows', () {
      final result = service.buildPreview(
        fileName: 'transactions.csv',
        content: '''
date,type,amount,note
2026-01-02,expense,25000,Lunch
03/01/2026,income,1000000,Salary
''',
        existingTransactions: const [],
      );

      final preview = (result as Success<CsvImportPreview>).value;
      expect(preview.totalRows, 2);
      expect(preview.validRows, 2);
      expect(preview.rows.first.type, TransactionType.expense);
      expect(preview.rows.first.amount, 25000);
      expect(preview.rows.last.transactionDate, DateTime.utc(2026, 1, 3));
    });

    test('returns a failure when required columns are missing', () {
      final result = service.buildPreview(
        fileName: 'transactions.csv',
        content: '''
type,note
expense,Lunch
''',
        existingTransactions: const [],
      );

      expect(result, isA<Failure<CsvImportPreview>>());
    });

    test('marks rows duplicate when they match existing transactions', () {
      final result = service.buildPreview(
        fileName: 'transactions.csv',
        content: '''
date,type,amount,note
2026-01-02,expense,25000,Lunch
''',
        existingTransactions: [
          _transaction(
            type: TransactionType.expense,
            amount: 25000,
            note: 'Lunch',
            transactionDate: DateTime.utc(2026, 1, 2),
          ),
        ],
      );

      final preview = (result as Success<CsvImportPreview>).value;
      expect(preview.validRows, 0);
      expect(preview.duplicateRows, 1);
      expect(preview.rows.single.status, CsvImportRowStatus.duplicate);
    });
  });
}

TransactionEntity _transaction({
  required TransactionType type,
  required double amount,
  required String note,
  required DateTime transactionDate,
}) {
  final now = DateTime.utc(2026);
  return TransactionEntity(
    id: 'transaction-1',
    type: type,
    amount: amount,
    currency: 'IDR',
    categoryId: 'food',
    accountId: 'cash',
    note: note,
    source: TransactionSource.manual,
    transactionDate: transactionDate,
    createdAt: now,
    updatedAt: now,
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/accounts/data/dto/account_dto.dart';
import 'package:money_tracker/features/categories/data/dto/category_dto.dart';
import 'package:money_tracker/features/csv_import/data/dto/csv_import_batch_dto.dart';
import 'package:money_tracker/features/debt_loan/data/dto/debt_dto.dart';
import 'package:money_tracker/features/notification_reader/data/dto/notification_log_dto.dart';
import 'package:money_tracker/features/receipt_ocr/data/dto/receipt_ocr_result_dto.dart';
import 'package:money_tracker/features/transactions/data/dto/transaction_draft_dto.dart';
import 'package:money_tracker/features/transactions/data/dto/transaction_dto.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
  final updatedAt = DateTime.utc(2026, 1, 3, 3, 4, 5);

  group('Firestore DTO serialization', () {
    test('serializes and parses a transaction', () {
      final dto = TransactionDto(
        id: 'transaction-1',
        type: TransactionType.expense,
        amount: 50000,
        currency: 'IDR',
        categoryId: 'category-1',
        accountId: 'account-1',
        note: 'Lunch',
        source: TransactionSource.manual,
        transactionDate: createdAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final map = dto.toFirestore();
      final parsed = TransactionDto.fromMap(map);

      expect(map['type'], 'expense');
      expect(map['source'], 'manual');
      expect(map['transactionDate'], isA<Timestamp>());
      expect(parsed.toDomain().amount, 50000);
      expect(parsed.deletedAt, isNull);
    });

    test('serializes and parses a transaction draft', () {
      final dto = TransactionDraftDto(
        id: 'draft-1',
        draftType: TransactionDraftType.ocr,
        detectedType: TransactionType.income,
        detectedAmount: 125000,
        detectedCurrency: 'IDR',
        detectedText: 'Transfer masuk',
        suggestedCategoryId: 'category-1',
        status: TransactionDraftStatus.pendingReview,
        confidence: 0.92,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final parsed = TransactionDraftDto.fromMap(dto.toFirestore());

      expect(parsed.draftType, TransactionDraftType.ocr);
      expect(parsed.status, TransactionDraftStatus.pendingReview);
      expect(parsed.toDomain().suggestedCategoryId, 'category-1');
    });

    test('serializes and parses category, account, and debt models', () {
      final category = CategoryDto.fromMap({
        'id': 'food',
        'name': 'Food',
        'type': 'expense',
        'icon': 'restaurant',
        'color': '#4CAF50',
        'isDefault': true,
        'isArchived': false,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      });
      final account = AccountDto.fromMap({
        'id': 'cash',
        'name': 'Cash',
        'type': 'cash',
        'currency': 'IDR',
        'openingBalance': 100000,
        'isArchived': false,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      });
      final debt = DebtDto.fromMap({
        'id': 'debt-1',
        'kind': 'receivable',
        'personName': 'Ari',
        'amount': 75000,
        'currency': 'IDR',
        'status': 'open',
        'dueDate': null,
        'note': 'Dinner split',
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(category.toFirestore()['type'], 'expense');
      expect(account.toFirestore()['type'], 'cash');
      expect(debt.toFirestore()['kind'], 'receivable');
      expect(debt.toDomain().dueDate, isNull);
    });

    test('serializes and parses notification and receipt models', () {
      final notification = NotificationLogDto.fromMap({
        'id': 'notification-1',
        'appName': 'myBCA',
        'packageName': 'com.bca',
        'title': 'Catatan Finansial',
        'body': 'Transfer masuk Rp50.000',
        'detectedType': 'income',
        'detectedAmount': 50000,
        'status': 'pending_review',
        'dedupeHash': 'abc123',
        'receivedAt': Timestamp.fromDate(createdAt),
        'createdAt': Timestamp.fromDate(createdAt),
      });
      final receipt = ReceiptOcrResultDto.fromMap({
        'id': 'receipt-1',
        'imageStoragePath': 'receipts/receipt-1.jpg',
        'rawText': 'Total 50000',
        'status': 'pending_review',
        'merchantName': 'Warung',
        'detectedAmount': 50000,
        'detectedCurrency': 'IDR',
        'receiptDate': Timestamp.fromDate(createdAt),
        'transactionDraftId': 'draft-1',
        'confidence': 0.87,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(notification.toFirestore()['detectedType'], 'income');
      expect(notification.toDomain().detectedAmount, 50000);
      expect(receipt.toFirestore()['status'], 'pending_review');
      expect(receipt.toDomain().transactionDraftId, 'draft-1');
    });

    test('serializes and parses CSV import batches with row results', () {
      final dto = CsvImportBatchDto.fromMap({
        'id': 'batch-1',
        'fileName': 'bca.csv',
        'status': 'pending_review',
        'totalRows': 2,
        'validRows': 1,
        'invalidRows': 1,
        'duplicateRows': 0,
        'rows': [
          {
            'rowNumber': 1,
            'rawData': {'amount': '50000', 'note': 'Lunch'},
            'status': 'valid',
            'transactionDraftId': 'draft-1',
          },
          {
            'rowNumber': 2,
            'rawData': {'amount': ''},
            'status': 'invalid',
            'errorMessage': 'Missing amount',
          },
        ],
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      final map = dto.toFirestore();

      expect(map['status'], 'pending_review');
      expect(dto.toDomain().rows, hasLength(2));
      expect(dto.toDomain().rows.last.status, CsvImportRowStatus.invalid);
    });
  });

  group('enum mapping', () {
    test('throws for unknown Firestore enum values', () {
      expect(
        () => TransactionType.fromFirestore('transfer'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => NotificationLogStatus.fromFirestore('archived'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

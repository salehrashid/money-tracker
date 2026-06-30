enum AccountType {
  cash('cash'),
  bank('bank'),
  eWallet('e_wallet'),
  other('other');

  const AccountType(this.firestoreValue);

  final String firestoreValue;

  static AccountType fromFirestore(String value) {
    return switch (value) {
      'cash' => AccountType.cash,
      'bank' => AccountType.bank,
      'e_wallet' => AccountType.eWallet,
      'other' => AccountType.other,
      _ => throw FormatException('Unknown account type: $value'),
    };
  }
}

enum TransactionType {
  income('income'),
  expense('expense');

  const TransactionType(this.firestoreValue);

  final String firestoreValue;

  static TransactionType fromFirestore(String value) {
    return switch (value) {
      'income' => TransactionType.income,
      'expense' => TransactionType.expense,
      _ => throw FormatException('Unknown transaction type: $value'),
    };
  }
}

enum DetectedTransactionType {
  income('income'),
  expense('expense'),
  unknown('unknown');

  const DetectedTransactionType(this.firestoreValue);

  final String firestoreValue;

  static DetectedTransactionType fromFirestore(String value) {
    return switch (value) {
      'income' => DetectedTransactionType.income,
      'expense' => DetectedTransactionType.expense,
      'unknown' => DetectedTransactionType.unknown,
      _ => throw FormatException('Unknown detected transaction type: $value'),
    };
  }
}

enum TransactionSource {
  manual('manual'),
  ocr('ocr'),
  csv('csv'),
  mybcaNotification('mybca_notification');

  const TransactionSource(this.firestoreValue);

  final String firestoreValue;

  static TransactionSource fromFirestore(String value) {
    return switch (value) {
      'manual' => TransactionSource.manual,
      'ocr' => TransactionSource.ocr,
      'csv' => TransactionSource.csv,
      'mybca_notification' => TransactionSource.mybcaNotification,
      _ => throw FormatException('Unknown transaction source: $value'),
    };
  }
}

enum TransactionDraftType {
  ocr('ocr'),
  csv('csv'),
  mybcaNotification('mybca_notification');

  const TransactionDraftType(this.firestoreValue);

  final String firestoreValue;

  static TransactionDraftType fromFirestore(String value) {
    return switch (value) {
      'ocr' => TransactionDraftType.ocr,
      'csv' => TransactionDraftType.csv,
      'mybca_notification' => TransactionDraftType.mybcaNotification,
      _ => throw FormatException('Unknown transaction draft type: $value'),
    };
  }
}

enum TransactionDraftStatus {
  pendingReview('pending_review'),
  saved('saved'),
  ignored('ignored'),
  duplicate('duplicate'),
  invalid('invalid');

  const TransactionDraftStatus(this.firestoreValue);

  final String firestoreValue;

  static TransactionDraftStatus fromFirestore(String value) {
    return switch (value) {
      'pending_review' => TransactionDraftStatus.pendingReview,
      'saved' => TransactionDraftStatus.saved,
      'ignored' => TransactionDraftStatus.ignored,
      'duplicate' => TransactionDraftStatus.duplicate,
      'invalid' => TransactionDraftStatus.invalid,
      _ => throw FormatException('Unknown transaction draft status: $value'),
    };
  }
}

enum DebtKind {
  debt('debt'),
  receivable('receivable');

  const DebtKind(this.firestoreValue);

  final String firestoreValue;

  static DebtKind fromFirestore(String value) {
    return switch (value) {
      'debt' => DebtKind.debt,
      'receivable' => DebtKind.receivable,
      _ => throw FormatException('Unknown debt kind: $value'),
    };
  }
}

enum DebtStatus {
  open('open'),
  paid('paid'),
  cancelled('cancelled');

  const DebtStatus(this.firestoreValue);

  final String firestoreValue;

  static DebtStatus fromFirestore(String value) {
    return switch (value) {
      'open' => DebtStatus.open,
      'paid' => DebtStatus.paid,
      'cancelled' => DebtStatus.cancelled,
      _ => throw FormatException('Unknown debt status: $value'),
    };
  }
}

enum NotificationLogStatus {
  ignoredNonTransaction('ignored_non_transaction'),
  ignoredPromo('ignored_promo'),
  ignoredLowConfidence('ignored_low_confidence'),
  pendingReview('pending_review'),
  saved('saved');

  const NotificationLogStatus(this.firestoreValue);

  final String firestoreValue;

  static NotificationLogStatus fromFirestore(String value) {
    return switch (value) {
      'ignored_non_transaction' => NotificationLogStatus.ignoredNonTransaction,
      'ignored_promo' => NotificationLogStatus.ignoredPromo,
      'ignored_low_confidence' => NotificationLogStatus.ignoredLowConfidence,
      'pending_review' => NotificationLogStatus.pendingReview,
      'saved' => NotificationLogStatus.saved,
      _ => throw FormatException('Unknown notification log status: $value'),
    };
  }
}

enum ReceiptOcrStatus {
  processing('processing'),
  pendingReview('pending_review'),
  saved('saved'),
  failed('failed'),
  ignored('ignored');

  const ReceiptOcrStatus(this.firestoreValue);

  final String firestoreValue;

  static ReceiptOcrStatus fromFirestore(String value) {
    return switch (value) {
      'processing' => ReceiptOcrStatus.processing,
      'pending_review' => ReceiptOcrStatus.pendingReview,
      'saved' => ReceiptOcrStatus.saved,
      'failed' => ReceiptOcrStatus.failed,
      'ignored' => ReceiptOcrStatus.ignored,
      _ => throw FormatException('Unknown receipt OCR status: $value'),
    };
  }
}

enum CsvImportBatchStatus {
  pendingReview('pending_review'),
  imported('imported'),
  failed('failed'),
  cancelled('cancelled');

  const CsvImportBatchStatus(this.firestoreValue);

  final String firestoreValue;

  static CsvImportBatchStatus fromFirestore(String value) {
    return switch (value) {
      'pending_review' => CsvImportBatchStatus.pendingReview,
      'imported' => CsvImportBatchStatus.imported,
      'failed' => CsvImportBatchStatus.failed,
      'cancelled' => CsvImportBatchStatus.cancelled,
      _ => throw FormatException('Unknown CSV import batch status: $value'),
    };
  }
}

enum CsvImportRowStatus {
  valid('valid'),
  imported('imported'),
  duplicate('duplicate'),
  invalid('invalid'),
  skipped('skipped');

  const CsvImportRowStatus(this.firestoreValue);

  final String firestoreValue;

  static CsvImportRowStatus fromFirestore(String value) {
    return switch (value) {
      'valid' => CsvImportRowStatus.valid,
      'imported' => CsvImportRowStatus.imported,
      'duplicate' => CsvImportRowStatus.duplicate,
      'invalid' => CsvImportRowStatus.invalid,
      'skipped' => CsvImportRowStatus.skipped,
      _ => throw FormatException('Unknown CSV import row status: $value'),
    };
  }
}

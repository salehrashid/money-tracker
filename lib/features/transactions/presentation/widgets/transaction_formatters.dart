import 'package:flutter/material.dart';

import '../../../../shared/models/finance_enums.dart';

String formatIdr(double value) {
  final amount = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < amount.length; index++) {
    if (index > 0 && (amount.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(amount[index]);
  }

  return 'Rp${buffer.toString()}';
}

String formatDate(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/${local.year}';
}

String transactionTypeLabel(TransactionType type) {
  return switch (type) {
    TransactionType.income => 'Income',
    TransactionType.expense => 'Expense',
  };
}

String transactionSourceLabel(TransactionSource source) {
  return switch (source) {
    TransactionSource.manual => 'Manual',
    TransactionSource.ocr => 'OCR',
    TransactionSource.csv => 'CSV',
    TransactionSource.mybcaNotification => 'myBCA',
  };
}

IconData transactionTypeIcon(TransactionType type) {
  return switch (type) {
    TransactionType.income => Icons.add_circle_outline,
    TransactionType.expense => Icons.remove_circle_outline,
  };
}

Color transactionTypeColor(BuildContext context, TransactionType type) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (type) {
    TransactionType.income => Colors.teal,
    TransactionType.expense => colorScheme.error,
  };
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

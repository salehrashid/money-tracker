import 'package:flutter/material.dart';

import '../../../../shared/models/finance_enums.dart';

String formatDebtIdr(double value) {
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

String formatDebtDate(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/${local.year}';
}

String debtKindLabel(DebtKind kind) {
  return switch (kind) {
    DebtKind.debt => 'Debt',
    DebtKind.receivable => 'Receivable',
  };
}

String debtStatusLabel(DebtStatus status) {
  return switch (status) {
    DebtStatus.open => 'Open',
    DebtStatus.paid => 'Paid',
    DebtStatus.cancelled => 'Cancelled',
  };
}

IconData debtKindIcon(DebtKind kind) {
  return switch (kind) {
    DebtKind.debt => Icons.call_made_outlined,
    DebtKind.receivable => Icons.call_received_outlined,
  };
}

Color debtKindColor(BuildContext context, DebtKind kind) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (kind) {
    DebtKind.debt => colorScheme.error,
    DebtKind.receivable => Colors.teal,
  };
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

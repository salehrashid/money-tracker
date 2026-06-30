import '../../../../shared/models/finance_enums.dart';

class SaveTransactionCommand {
  const SaveTransactionCommand({
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.note,
    required this.transactionDate,
    this.source = TransactionSource.manual,
  });

  final TransactionType type;
  final double amount;
  final String categoryId;
  final String accountId;
  final String note;
  final DateTime transactionDate;
  final TransactionSource source;
}

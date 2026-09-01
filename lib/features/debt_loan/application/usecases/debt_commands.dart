import '../../../../shared/models/finance_enums.dart';

class SaveDebtCommand {
  const SaveDebtCommand({
    required this.kind,
    required this.personName,
    required this.amount,
    required this.status,
    required this.note,
    required this.transactionDate,
  });

  final DebtKind kind;
  final String personName;
  final double amount;
  final DebtStatus status;
  final String note;
  final DateTime transactionDate;
}

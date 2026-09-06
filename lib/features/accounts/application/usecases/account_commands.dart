import '../../../../shared/models/finance_enums.dart';

class SaveAccountCommand {
  const SaveAccountCommand({
    required this.name,
    required this.type,
    this.parentAccountId,
    this.currency = 'IDR',
    this.initialBalance = 0,
    this.sortOrder = 0,
  });

  final String name;
  final AccountType type;
  final String? parentAccountId;
  final String currency;
  final double initialBalance;
  final int sortOrder;
}

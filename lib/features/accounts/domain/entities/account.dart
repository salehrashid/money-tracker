import '../../../../shared/models/finance_enums.dart';

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    double? initialBalance,
    double? openingBalance,
    required this.isArchived,
    this.parentAccountId,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  }) : initialBalance = initialBalance ?? openingBalance ?? 0;

  final String id;
  final String name;
  final AccountType type;
  final String currency;
  final String? parentAccountId;
  final double initialBalance;
  double get openingBalance => initialBalance;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? currency,
    double? initialBalance,
    double? openingBalance,
    bool? isArchived,
    String? parentAccountId,
    bool clearParentAccountId = false,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      initialBalance: initialBalance ?? openingBalance ?? this.initialBalance,
      isArchived: isArchived ?? this.isArchived,
      parentAccountId: clearParentAccountId
          ? null
          : parentAccountId ?? this.parentAccountId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

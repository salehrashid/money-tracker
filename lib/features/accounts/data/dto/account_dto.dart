import 'package:firedart/firedart.dart';

import '../../../../core/firebase/firestore_model_converters.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/account.dart';

class AccountDto {
  const AccountDto({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.openingBalance,
    required this.isArchived,
    this.parentAccountId,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final AccountType type;
  final String currency;
  final double openingBalance;
  final bool isArchived;
  final String? parentAccountId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AccountDto.fromDomain(Account account) {
    return AccountDto(
      id: account.id,
      name: account.name,
      type: account.type,
      currency: account.currency,
      openingBalance: account.openingBalance,
      isArchived: account.isArchived,
      parentAccountId: account.parentAccountId,
      sortOrder: account.sortOrder,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    );
  }

  factory AccountDto.fromFirestore(Document snapshot) {
    return AccountDto.fromMap(snapshot.map, documentId: snapshot.id);
  }

  factory AccountDto.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return AccountDto(
      id: optionalString(data, 'id') ?? documentId ?? '',
      name: requiredString(data, 'name'),
      type: AccountType.fromFirestore(requiredString(data, 'type')),
      currency: requiredString(data, 'currency'),
      openingBalance: _balance(data),
      isArchived: data['isArchived'] is bool
          ? data['isArchived'] as bool
          : false,
      parentAccountId: optionalString(data, 'parentAccountId'),
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: requiredDateTime(data, 'createdAt'),
      updatedAt: requiredDateTime(data, 'updatedAt'),
    );
  }

  Account toDomain() {
    return Account(
      id: id,
      name: name,
      type: type,
      currency: currency,
      openingBalance: openingBalance,
      isArchived: isArchived,
      parentAccountId: parentAccountId,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'type': type.firestoreValue,
      'currency': currency,
      'openingBalance': openingBalance,
      'initialBalance': openingBalance,
      'isArchived': isArchived,
      'parentAccountId': parentAccountId,
      'sortOrder': sortOrder,
      'createdAt': timestampFromDate(createdAt),
      'updatedAt': timestampFromDate(updatedAt),
    };
  }
}

double _balance(Map<String, dynamic> data) {
  final value = data['initialBalance'] ?? data['openingBalance'] ?? 0;
  if (value is num) return value.toDouble();
  throw const FormatException('Account balance must be numeric.');
}

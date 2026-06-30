import 'package:cloud_firestore/cloud_firestore.dart';

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
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final AccountType type;
  final String currency;
  final double openingBalance;
  final bool isArchived;
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
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    );
  }

  factory AccountDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return AccountDto.fromMap(
      snapshot.data() ?? const {},
      documentId: snapshot.id,
    );
  }

  factory AccountDto.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return AccountDto(
      id: optionalString(data, 'id') ?? documentId ?? '',
      name: requiredString(data, 'name'),
      type: AccountType.fromFirestore(requiredString(data, 'type')),
      currency: requiredString(data, 'currency'),
      openingBalance: requiredDouble(data, 'openingBalance'),
      isArchived: requiredBool(data, 'isArchived'),
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
      'isArchived': isArchived,
      'createdAt': timestampFromDate(createdAt),
      'updatedAt': timestampFromDate(updatedAt),
    };
  }
}

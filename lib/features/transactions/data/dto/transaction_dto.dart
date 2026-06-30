import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_model_converters.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/transaction.dart';

class TransactionDto {
  const TransactionDto({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.categoryId,
    required this.accountId,
    required this.note,
    required this.source,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final String currency;
  final String categoryId;
  final String accountId;
  final String note;
  final TransactionSource source;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  factory TransactionDto.fromDomain(TransactionEntity transaction) {
    return TransactionDto(
      id: transaction.id,
      type: transaction.type,
      amount: transaction.amount,
      currency: transaction.currency,
      categoryId: transaction.categoryId,
      accountId: transaction.accountId,
      note: transaction.note,
      source: transaction.source,
      transactionDate: transaction.transactionDate,
      createdAt: transaction.createdAt,
      updatedAt: transaction.updatedAt,
      deletedAt: transaction.deletedAt,
    );
  }

  factory TransactionDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return TransactionDto.fromMap(
      snapshot.data() ?? const {},
      documentId: snapshot.id,
    );
  }

  factory TransactionDto.fromMap(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    return TransactionDto(
      id: optionalString(data, 'id') ?? documentId ?? '',
      type: TransactionType.fromFirestore(requiredString(data, 'type')),
      amount: requiredDouble(data, 'amount'),
      currency: requiredString(data, 'currency'),
      categoryId: requiredString(data, 'categoryId'),
      accountId: requiredString(data, 'accountId'),
      note: requiredString(data, 'note'),
      source: TransactionSource.fromFirestore(requiredString(data, 'source')),
      transactionDate: requiredDateTime(data, 'transactionDate'),
      createdAt: requiredDateTime(data, 'createdAt'),
      updatedAt: requiredDateTime(data, 'updatedAt'),
      deletedAt: optionalDateTime(data, 'deletedAt'),
    );
  }

  TransactionEntity toDomain() {
    return TransactionEntity(
      id: id,
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      accountId: accountId,
      note: note,
      source: source,
      transactionDate: transactionDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'type': type.firestoreValue,
      'amount': amount,
      'currency': currency,
      'categoryId': categoryId,
      'accountId': accountId,
      'note': note,
      'source': source.firestoreValue,
      'transactionDate': timestampFromDate(transactionDate),
      'createdAt': timestampFromDate(createdAt),
      'updatedAt': timestampFromDate(updatedAt),
      'deletedAt': deletedAt == null ? null : timestampFromDate(deletedAt!),
    };
  }
}

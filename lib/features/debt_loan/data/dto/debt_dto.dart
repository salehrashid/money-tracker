import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_model_converters.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/debt.dart';

class DebtDto {
  const DebtDto({
    required this.id,
    required this.kind,
    required this.personName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
  });

  final String id;
  final DebtKind kind;
  final String personName;
  final double amount;
  final String currency;
  final DebtStatus status;
  final DateTime? dueDate;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DebtDto.fromDomain(Debt debt) {
    return DebtDto(
      id: debt.id,
      kind: debt.kind,
      personName: debt.personName,
      amount: debt.amount,
      currency: debt.currency,
      status: debt.status,
      dueDate: debt.dueDate,
      note: debt.note,
      createdAt: debt.createdAt,
      updatedAt: debt.updatedAt,
    );
  }

  factory DebtDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return DebtDto.fromMap(
      snapshot.data() ?? const {},
      documentId: snapshot.id,
    );
  }

  factory DebtDto.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return DebtDto(
      id: optionalString(data, 'id') ?? documentId ?? '',
      kind: DebtKind.fromFirestore(requiredString(data, 'kind')),
      personName: requiredString(data, 'personName'),
      amount: requiredDouble(data, 'amount'),
      currency: requiredString(data, 'currency'),
      status: DebtStatus.fromFirestore(requiredString(data, 'status')),
      dueDate: optionalDateTime(data, 'dueDate'),
      note: requiredString(data, 'note'),
      createdAt: requiredDateTime(data, 'createdAt'),
      updatedAt: requiredDateTime(data, 'updatedAt'),
    );
  }

  Debt toDomain() {
    return Debt(
      id: id,
      kind: kind,
      personName: personName,
      amount: amount,
      currency: currency,
      status: status,
      dueDate: dueDate,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'kind': kind.firestoreValue,
      'personName': personName,
      'amount': amount,
      'currency': currency,
      'status': status.firestoreValue,
      'dueDate': dueDate == null ? null : timestampFromDate(dueDate!),
      'note': note,
      'createdAt': timestampFromDate(createdAt),
      'updatedAt': timestampFromDate(updatedAt),
    };
  }
}

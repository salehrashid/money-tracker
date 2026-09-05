import '../../../../shared/models/finance_enums.dart';

const debtTransferProofMaxBytes = 600 * 1024;

class Debt {
  const Debt({
    required this.id,
    required this.kind,
    required this.personName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.transactionDate,
    this.transferProofBase64,
  });

  final String id;
  final DebtKind kind;
  final String personName;
  final double amount;
  final String currency;
  final DebtStatus status;
  final DateTime transactionDate;
  final String note;
  final String? transferProofBase64;
  final DateTime createdAt;
  final DateTime updatedAt;

  Debt copyWith({
    String? id,
    DebtKind? kind,
    String? personName,
    double? amount,
    String? currency,
    DebtStatus? status,
    DateTime? transactionDate,
    String? note,
    String? transferProofBase64,
    bool clearTransferProof = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Debt(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      transactionDate: transactionDate ?? this.transactionDate,
      note: note ?? this.note,
      transferProofBase64: clearTransferProof
          ? null
          : transferProofBase64 ?? this.transferProofBase64,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

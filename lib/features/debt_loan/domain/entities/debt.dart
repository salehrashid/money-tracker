import '../../../../shared/models/finance_enums.dart';

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

  Debt copyWith({
    String? id,
    DebtKind? kind,
    String? personName,
    double? amount,
    String? currency,
    DebtStatus? status,
    DateTime? dueDate,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearDueDate = false,
  }) {
    return Debt(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

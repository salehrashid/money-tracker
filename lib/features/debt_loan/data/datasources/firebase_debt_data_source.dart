import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_user_collections.dart';
import '../dto/debt_dto.dart';

class FirebaseDebtDataSource {
  const FirebaseDebtDataSource(this._collections);

  final FirestoreUserCollections _collections;

  Stream<List<DebtDto>> watchDebts() {
    return _collections.debts.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(DebtDto.fromFirestore).toList(growable: false),
    );
  }

  Future<DebtDto?> fetchDebt(String debtId) async {
    final snapshot = await _collections.debts.doc(debtId).get();
    if (!snapshot.exists) {
      return null;
    }

    return DebtDto.fromFirestore(snapshot);
  }

  Future<DebtDto> saveDebt(DebtDto debt) async {
    final document = debt.id.isEmpty
        ? _collections.debts.doc()
        : _collections.debts.doc(debt.id);
    final savedDebt = debt.id.isEmpty
        ? DebtDto(
            id: document.id,
            kind: debt.kind,
            personName: debt.personName,
            amount: debt.amount,
            currency: debt.currency,
            status: debt.status,
            dueDate: debt.dueDate,
            note: debt.note,
            createdAt: debt.createdAt,
            updatedAt: debt.updatedAt,
          )
        : debt;

    await document.set({
      ...savedDebt.toFirestore(),
      if (debt.id.isEmpty) 'serverCreatedAt': FieldValue.serverTimestamp(),
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return savedDebt;
  }

  Future<void> deleteDebt(String debtId) {
    return _collections.debts.doc(debtId).delete();
  }
}

import 'package:uuid/uuid.dart';

import '../../../../core/firebase/firestore_user_collections.dart';
import '../dto/debt_dto.dart';

class FirebaseDebtDataSource {
  const FirebaseDebtDataSource(this._collections);

  final FirestoreUserCollections _collections;

  Stream<List<DebtDto>> watchDebts() async* {
    yield const [];

    final initialDocuments = await _collections.debts.get();
    yield initialDocuments.map(DebtDto.fromFirestore).toList(growable: false);

    yield* _collections.debts.stream.map(
      (documents) =>
          documents.map(DebtDto.fromFirestore).toList(growable: false),
    );
  }

  Future<DebtDto?> fetchDebt(String debtId) async {
    final document = _collections.debts.document(debtId);
    if (!await document.exists) return null;
    return DebtDto.fromFirestore(await document.get());
  }

  Future<DebtDto> saveDebt(DebtDto debt) async {
    final id = debt.id.isEmpty ? const Uuid().v4() : debt.id;
    final document = _collections.debts.document(id);
    final savedDebt = debt.id.isEmpty
        ? DebtDto(
            id: id,
            kind: debt.kind,
            personName: debt.personName,
            amount: debt.amount,
            currency: debt.currency,
            status: debt.status,
            transactionDate: debt.transactionDate,
            note: debt.note,
            createdAt: debt.createdAt,
            updatedAt: debt.updatedAt,
          )
        : debt;

    final exists = await document.exists;
    final now = DateTime.now().toUtc();
    final data = {
      ...savedDebt.toFirestore(),
      'serverUpdatedAt': now,
      if (!exists) 'serverCreatedAt': now,
    };
    if (exists) {
      await document.update(data);
    } else {
      await document.set(data);
    }
    return savedDebt;
  }

  Future<void> deleteDebt(String debtId) {
    return _collections.debts.document(debtId).delete();
  }
}

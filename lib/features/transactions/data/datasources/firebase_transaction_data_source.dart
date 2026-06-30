import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_user_collections.dart';
import '../../../../shared/models/finance_enums.dart';
import '../dto/transaction_draft_dto.dart';
import '../dto/transaction_dto.dart';

class FirebaseTransactionDataSource {
  const FirebaseTransactionDataSource(this._collections);

  final FirestoreUserCollections _collections;

  Stream<List<TransactionDto>> watchTransactions() {
    return _collections.transactions
        .where('deletedAt', isNull: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(TransactionDto.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<TransactionDraftDto>> watchPendingDrafts() {
    return _collections.transactionDrafts
        .where(
          'status',
          isEqualTo: TransactionDraftStatus.pendingReview.firestoreValue,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(TransactionDraftDto.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<TransactionDto?> fetchTransaction(String transactionId) async {
    final snapshot = await _collections.transactions.doc(transactionId).get();
    if (!snapshot.exists) {
      return null;
    }

    return TransactionDto.fromFirestore(snapshot);
  }

  Future<TransactionDraftDto?> fetchDraft(String draftId) async {
    final snapshot = await _collections.transactionDrafts.doc(draftId).get();
    if (!snapshot.exists) {
      return null;
    }

    return TransactionDraftDto.fromFirestore(snapshot);
  }

  Future<TransactionDto> saveTransaction(TransactionDto transaction) async {
    final document = transaction.id.isEmpty
        ? _collections.transactions.doc()
        : _collections.transactions.doc(transaction.id);
    final savedTransaction = transaction.id.isEmpty
        ? TransactionDto(
            id: document.id,
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
          )
        : transaction;

    await document.set(savedTransaction.toFirestore(), SetOptions(merge: true));
    return savedTransaction;
  }

  Future<TransactionDto> saveTransactionFromDraft({
    required TransactionDto transaction,
    required TransactionDraftDto draft,
  }) async {
    final transactionDocument = _collections.transactions.doc();
    final draftDocument = _collections.transactionDrafts.doc(draft.id);
    final savedTransaction = TransactionDto(
      id: transactionDocument.id,
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
    final savedDraft = draft.toDomain().copyWith(
      status: TransactionDraftStatus.saved,
      updatedAt: transaction.updatedAt,
    );

    await _collections.userDocument.firestore.runTransaction((db) async {
      db.set(transactionDocument, savedTransaction.toFirestore());
      db.set(
        draftDocument,
        TransactionDraftDto.fromDomain(savedDraft).toFirestore(),
        SetOptions(merge: true),
      );
    });

    return savedTransaction;
  }
}

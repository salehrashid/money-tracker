import 'package:firedart/firedart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/firebase/firestore_user_collections.dart';
import '../../../../shared/models/finance_enums.dart';
import '../dto/transaction_draft_dto.dart';
import '../dto/transaction_dto.dart';

class FirebaseTransactionDataSource {
  const FirebaseTransactionDataSource(this._collections);

  final FirestoreUserCollections _collections;

  Stream<List<TransactionDto>> watchTransactions() async* {
    yield const [];

    final initialDocuments = await _collections.transactions.get();
    yield _activeTransactions(initialDocuments);

    yield* _collections.transactions.stream.map(_activeTransactions);
  }

  List<TransactionDto> _activeTransactions(Iterable<Document> documents) {
    return documents
        .map(TransactionDto.fromFirestore)
        .where((transaction) => transaction.deletedAt == null)
        .toList(growable: false);
  }

  Stream<List<TransactionDraftDto>> watchPendingDrafts() async* {
    yield const [];

    final initialDocuments = await _collections.transactionDrafts.get();
    yield _pendingDrafts(initialDocuments);

    yield* _collections.transactionDrafts.stream.map(_pendingDrafts);
  }

  List<TransactionDraftDto> _pendingDrafts(Iterable<Document> documents) {
    return documents
        .map(TransactionDraftDto.fromFirestore)
        .where((draft) => draft.status == TransactionDraftStatus.pendingReview)
        .toList(growable: false);
  }

  Future<TransactionDto?> fetchTransaction(String transactionId) async {
    final document = _collections.transactions.document(transactionId);
    if (!await document.exists) return null;
    return TransactionDto.fromFirestore(await document.get());
  }

  Future<TransactionDraftDto?> fetchDraft(String draftId) async {
    final document = _collections.transactionDrafts.document(draftId);
    if (!await document.exists) return null;
    return TransactionDraftDto.fromFirestore(await document.get());
  }

  Future<TransactionDto> saveTransaction(TransactionDto transaction) async {
    final id = transaction.id.isEmpty ? const Uuid().v4() : transaction.id;
    final document = _collections.transactions.document(id);
    final savedTransaction = transaction.id.isEmpty
        ? TransactionDto(
            id: id,
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

    final exists = await document.exists;
    final now = DateTime.now().toUtc();
    final data = {
      ...savedTransaction.toFirestore(),
      'serverUpdatedAt': now,
      if (!exists) 'serverCreatedAt': now,
    };
    if (exists) {
      await document.update(data);
    } else {
      await document.set(data);
    }
    return savedTransaction;
  }

  Future<TransactionDto> saveTransactionFromDraft({
    required TransactionDto transaction,
    required TransactionDraftDto draft,
  }) async {
    final transactionId = const Uuid().v4();
    final transactionDocument = _collections.transactions.document(
      transactionId,
    );
    final draftDocument = _collections.transactionDrafts.document(draft.id);
    final savedTransaction = TransactionDto(
      id: transactionId,
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

    final now = DateTime.now().toUtc();
    await transactionDocument.set({
      ...savedTransaction.toFirestore(),
      'serverCreatedAt': now,
      'serverUpdatedAt': now,
    });
    try {
      await draftDocument.update({
        ...TransactionDraftDto.fromDomain(savedDraft).toFirestore(),
        'serverUpdatedAt': now,
      });
    } catch (_) {
      await transactionDocument.delete();
      rethrow;
    }

    return savedTransaction;
  }
}

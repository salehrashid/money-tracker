import '../../../../core/firebase/firestore_user_collections.dart';
import '../dto/account_dto.dart';

class FirebaseAccountDataSource {
  const FirebaseAccountDataSource(this._collections);

  final FirestoreUserCollections _collections;

  Stream<List<AccountDto>> watchAccounts() async* {
    yield const [];

    final initialDocuments = await _collections.accounts.get();
    yield initialDocuments
        .map(AccountDto.fromFirestore)
        .toList(growable: false);

    yield* _collections.accounts.stream.map(
      (documents) =>
          documents.map(AccountDto.fromFirestore).toList(growable: false),
    );
  }

  /// Returns true if the user has at least one account in Firestore.
  Future<bool> hasAnyAccount() async {
    final documents = await _collections.accounts.limit(1).get();
    return documents.isNotEmpty;
  }

  /// Writes [dto] as a new account document. Uses [dto.id] as the document ID.
  Future<void> createAccount(AccountDto dto) async {
    final document = _collections.accounts.document(dto.id);
    final data = {
      ...dto.toFirestore(),
      'serverUpdatedAt': DateTime.now().toUtc(),
    };
    if (await document.exists) {
      await document.update(data);
    } else {
      await document.set({...data, 'serverCreatedAt': DateTime.now().toUtc()});
    }
  }
}

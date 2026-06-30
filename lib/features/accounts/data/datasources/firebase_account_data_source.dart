import '../../../../core/firebase/firestore_user_collections.dart';
import '../dto/account_dto.dart';

class FirebaseAccountDataSource {
  const FirebaseAccountDataSource(this._collections);

  final FirestoreUserCollections _collections;

  Stream<List<AccountDto>> watchAccounts() {
    return _collections.accounts.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(AccountDto.fromFirestore).toList(growable: false),
    );
  }
}

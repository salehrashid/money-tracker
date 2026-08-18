import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Returns true if the user has at least one account in Firestore.
  Future<bool> hasAnyAccount() async {
    final snapshot = await _collections.accounts.limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  /// Writes [dto] as a new account document. Uses [dto.id] as the document ID.
  Future<void> createAccount(AccountDto dto) async {
    await _collections.accounts.doc(dto.id).set({
      ...dto.toFirestore(),
      'serverCreatedAt': FieldValue.serverTimestamp(),
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

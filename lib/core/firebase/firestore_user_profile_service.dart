import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/domain/entities/auth_user.dart';
import 'firestore_user_collections.dart';

class FirestoreUserProfileService {
  const FirestoreUserProfileService(this._collections);

  final FirestoreUserCollections _collections;

  Future<void> upsertProfile(AuthUser user) async {
    final userDocument = _collections.userDocument;
    await userDocument.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDocument);
      final data = <String, dynamic>{
        'uid': user.id,
        'email': user.email,
        'isEmailVerified': user.isEmailVerified,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSignedInAt': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      transaction.set(userDocument, data, SetOptions(merge: true));
    });
  }
}

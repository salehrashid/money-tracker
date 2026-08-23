import '../../features/auth/domain/entities/auth_user.dart';
import 'firestore_user_collections.dart';

class FirestoreUserProfileService {
  const FirestoreUserProfileService(this._collections);

  final FirestoreUserCollections _collections;

  Future<void> upsertProfile(AuthUser user) async {
    final userDocument = _collections.userDocument;
    final exists = await userDocument.exists;
    final now = DateTime.now().toUtc();
    final data = <String, dynamic>{
      'uid': user.id,
      'email': user.email,
      'isEmailVerified': user.isEmailVerified,
      'updatedAt': now,
      'lastSignedInAt': now,
      if (!exists) 'createdAt': now,
    };
    if (exists) {
      await userDocument.update(data);
    } else {
      await userDocument.set(data);
    }
  }
}

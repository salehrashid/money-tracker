import 'package:firedart/firedart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_user_collections.dart';
import 'firestore_user_profile_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<Firestore>((ref) {
  return Firestore.instance;
});

final firestoreUserCollectionsProvider =
    Provider.family<FirestoreUserCollections, String>((ref, userId) {
      return FirestoreUserCollections(
        firestore: ref.watch(firebaseFirestoreProvider),
        userId: userId,
      );
    });

final firestoreUserProfileServiceProvider =
    Provider.family<FirestoreUserProfileService, String>((ref, userId) {
      return FirestoreUserProfileService(
        ref.watch(firestoreUserCollectionsProvider(userId)),
      );
    });

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_user_collections.dart';
import 'firestore_user_profile_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
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

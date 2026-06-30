import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../data/datasources/firebase_auth_data_source.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

final firebaseAuthDataSourceProvider = Provider<FirebaseAuthDataSource>((ref) {
  return FirebaseAuthDataSource(ref.watch(firebaseAuthProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(
    dataSource: ref.watch(firebaseAuthDataSourceProvider),
  );
});

final authStateProvider = StreamProvider<Result<AuthUser?>>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

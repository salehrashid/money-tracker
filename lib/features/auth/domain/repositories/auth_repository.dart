import '../../../../core/utils/result.dart';
import '../entities/auth_user.dart';

abstract interface class AuthRepository {
  Stream<Result<AuthUser?>> authStateChanges();

  Future<Result<AuthUser>> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<Result<AuthUser>> registerWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();
}

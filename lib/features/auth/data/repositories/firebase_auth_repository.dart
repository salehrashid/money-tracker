import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_data_source.dart';

class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository({
    required FirebaseAuthDataSource dataSource,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _dataSource = dataSource,
       _errorMapper = errorMapper;

  final FirebaseAuthDataSource _dataSource;
  final FirebaseErrorMapper _errorMapper;

  @override
  Stream<Result<AuthUser?>> authStateChanges() async* {
    try {
      await for (final user in _dataSource.authStateChanges()) {
        yield Success(_mapUser(user));
      }
    } catch (error) {
      yield Failure(_errorMapper.map(error));
    }
  }

  @override
  Future<Result<AuthUser>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          code: 'empty-login-fields',
          message: 'Email and password are required.',
        ),
      );
    }

    try {
      final credential = await _dataSource.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user;

      if (user == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.authentication,
            code: 'missing-auth-user',
            message: 'Sign in failed. Please try again.',
          ),
        );
      }

      return Success(_mapUser(user)!);
    } catch (error) {
      return Failure(_errorMapper.map(error));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _dataSource.signOut();
      return const Success(null);
    } catch (error) {
      return Failure(_errorMapper.map(error));
    }
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }

    return AuthUser(
      id: user.uid,
      email: user.email,
      isEmailVerified: user.emailVerified,
    );
  }
}

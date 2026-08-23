import 'package:firedart/auth/user_gateway.dart';

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
        yield Success(user == null ? null : _mapUser(user));
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

    final validationFailure = _validateEmailPassword(
      email: normalizedEmail,
      password: password,
    );
    if (validationFailure != null) {
      return Failure(validationFailure);
    }

    try {
      final user = await _dataSource.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      return Success(_mapUser(user));
    } catch (error) {
      return Failure(_errorMapper.map(error));
    }
  }

  @override
  Future<Result<AuthUser>> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();

    final validationFailure = _validateEmailPassword(
      email: normalizedEmail,
      password: password,
    );
    if (validationFailure != null) {
      return Failure(validationFailure);
    }

    try {
      final user = await _dataSource.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      return Success(_mapUser(user));
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

  AuthUser _mapUser(User user) {
    return AuthUser(
      id: user.id,
      email: user.email,
      isEmailVerified: user.emailVerified ?? false,
    );
  }

  AppFailure? _validateEmailPassword({
    required String email,
    required String password,
  }) {
    if (email.isEmpty || password.isEmpty) {
      return const AppFailure(
        type: AppFailureType.validation,
        code: 'empty-login-fields',
        message: 'Email and password are required.',
      );
    }

    if (password.length < 6) {
      return const AppFailure(
        type: AppFailureType.validation,
        code: 'weak-password',
        message: 'Password must be at least 6 characters.',
      );
    }

    return null;
  }
}

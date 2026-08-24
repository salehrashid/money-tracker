import 'dart:async';
import 'dart:io';

import 'package:firedart/firedart.dart';
import 'package:firedart/auth/user_gateway.dart';
import 'package:http/http.dart' as http;

import 'secure_auth_token_store.dart';

class FirebaseAuthDataSource {
  const FirebaseAuthDataSource(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() async* {
    yield await _resolveCurrentUser();
    await for (final signedIn in _auth.signInState) {
      yield signedIn ? await _resolveCurrentUser() : null;
    }
  }

  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = await _auth.signIn(email, password);
    await SecureAuthTokenStore.persistUser(user);
    return user;
  }

  Future<User> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = await _auth.signUp(email, password);
    await SecureAuthTokenStore.persistUser(user);
    return user;
  }

  Future<void> signOut() async {
    _auth.signOut();
    await SecureAuthTokenStore.clearPersistedSession();
  }

  Future<User?> _resolveCurrentUser() async {
    if (!_auth.isSignedIn) return null;
    try {
      final user = await _auth.getUser();
      await SecureAuthTokenStore.persistUser(user);
      return user;
    } catch (error) {
      // Firedart must contact Identity Toolkit even when it already restored a
      // token. A transport failure must not turn that saved session into a
      // sign-out. Authentication failures are deliberately rethrown.
      if (!_isNetworkFailure(error) || !_auth.isSignedIn) rethrow;
      final cached = await SecureAuthTokenStore.readPersistedUser();
      final userId = _auth.userId;
      if (cached != null && cached.id == userId) return cached;
      return User.fromMap({
        'localId': userId,
        'email': null,
        'emailVerified': false,
      });
    }
  }
}

bool _isNetworkFailure(Object error) {
  return error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException;
}

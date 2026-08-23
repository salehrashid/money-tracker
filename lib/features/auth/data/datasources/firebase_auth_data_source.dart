import 'package:firedart/firedart.dart';
import 'package:firedart/auth/user_gateway.dart';

import 'secure_auth_token_store.dart';

class FirebaseAuthDataSource {
  const FirebaseAuthDataSource(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() async* {
    yield _auth.isSignedIn ? await _auth.getUser() : null;
    await for (final signedIn in _auth.signInState) {
      yield signedIn ? await _auth.getUser() : null;
    }
  }

  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signIn(email, password);
  }

  Future<User> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signUp(email, password);
  }

  Future<void> signOut() async {
    _auth.signOut();
    await SecureAuthTokenStore.clearPersistedSession();
  }
}

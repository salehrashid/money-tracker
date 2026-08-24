import 'dart:async';
import 'dart:convert';

import 'package:firedart/firedart.dart' as fd;
import 'package:firedart/auth/user_gateway.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureAuthTokenStore extends fd.TokenStore {
  SecureAuthTokenStore._(this._initialToken);

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'fleeca_firebase_auth_token';
  static const _userStorageKey = 'fleeca_firebase_auth_user';

  final fd.Token? _initialToken;

  static Future<SecureAuthTokenStore> create() async {
    try {
      final encodedToken = await _storage.read(key: _storageKey);
      return SecureAuthTokenStore._(_decodeToken(encodedToken));
    } catch (_) {
      return SecureAuthTokenStore._(null);
    }
  }

  static Future<void> persistUser(User user) async {
    await _storage.write(key: _userStorageKey, value: jsonEncode(user.toMap()));
  }

  static Future<User?> readPersistedUser() async {
    try {
      final encoded = await _storage.read(key: _userStorageKey);
      if (encoded == null || encoded.isEmpty) return null;
      final decoded = jsonDecode(encoded);
      return decoded is Map<String, dynamic> ? User.fromMap(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearPersistedSession() async {
    await Future.wait([
      _storage.delete(key: _storageKey),
      _storage.delete(key: _userStorageKey),
    ]);
  }

  @override
  fd.Token? read() => _initialToken;

  @override
  void write(fd.Token? token) {
    final encodedToken = token == null ? null : jsonEncode(token.toMap());
    unawaited(
      _storage
          .write(key: _storageKey, value: encodedToken)
          .catchError((Object _) {}),
    );
  }

  @override
  void delete() {
    unawaited(_storage.delete(key: _storageKey).catchError((Object _) {}));
  }

  static fd.Token? _decodeToken(String? encodedToken) {
    if (encodedToken == null || encodedToken.isEmpty) return null;
    try {
      final decoded = jsonDecode(encodedToken);
      return decoded is Map<String, dynamic> ? fd.Token.fromMap(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}

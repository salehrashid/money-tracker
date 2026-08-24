import 'dart:io';

import 'package:firedart/firedart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:money_tracker/features/auth/data/datasources/firebase_auth_data_source.dart';

void main() {
  test('restores the token user while the user lookup is offline', () async {
    final auth = FirebaseAuth(
      'test-api-key',
      _StoredToken(),
      httpClient: _OfflineClient(),
    );
    final dataSource = FirebaseAuthDataSource(auth);

    final user = await dataSource.authStateChanges().first;

    expect(auth.isSignedIn, isTrue);
    expect(user?.id, 'cached-user-id');
  });
}

class _StoredToken extends TokenStore {
  @override
  Token? read() => Token.fromMap({
    'userId': 'cached-user-id',
    'idToken': 'cached-id-token',
    'refreshToken': 'cached-refresh-token',
    'expiry': DateTime.now()
        .toUtc()
        .add(const Duration(hours: 1))
        .toIso8601String(),
  });

  @override
  void write(Token? token) {}

  @override
  void delete() {}
}

class _OfflineClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw const SocketException('No internet connection');
  }
}

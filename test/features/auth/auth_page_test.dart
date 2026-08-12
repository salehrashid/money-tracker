import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/errors/app_failure.dart';
import 'package:money_tracker/core/utils/result.dart';
import 'package:money_tracker/features/auth/domain/entities/auth_user.dart';
import 'package:money_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:money_tracker/features/auth/presentation/pages/auth_page.dart';
import 'package:money_tracker/features/auth/presentation/providers/auth_providers.dart';

void main() {
  group('AuthPage', () {
    testWidgets('shows sign-in validation errors for invalid input', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();

      await tester.pumpAuthPage(repository);
      await tester.tap(find.text('Sign in').last);
      await tester.pump();

      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
      expect(repository.signInCalls, 0);
    });

    testWidgets(
      'shows registration validation errors for mismatched password',
      (tester) async {
        final repository = _FakeAuthRepository();

        await tester.pumpAuthPage(repository);
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'user@test.dev',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
        await tester.enterText(find.byType(TextFormField).at(2), 'secret2');
        await tester.tap(find.text('Create account'));
        await tester.pump();

        expect(find.text('Passwords do not match.'), findsOneWidget);
        expect(repository.registerCalls, 0);
      },
    );

    testWidgets('shows repository failure message when sign in fails', (
      tester,
    ) async {
      final repository = _FakeAuthRepository(
        signInResult: const Failure(
          AppFailure(
            type: AppFailureType.authentication,
            message: 'Invalid email or password.',
          ),
        ),
      );

      await tester.pumpAuthPage(repository);
      await tester.enterText(find.byType(TextFormField).at(0), 'user@test.dev');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();

      expect(repository.signInCalls, 1);
      expect(repository.lastEmail, 'user@test.dev');
      expect(find.text('Invalid email or password.'), findsOneWidget);
    });
  });
}

extension on WidgetTester {
  Future<void> pumpAuthPage(AuthRepository repository) {
    return pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AuthPage()),
      ),
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({Result<AuthUser>? signInResult})
    : signInResult =
          signInResult ??
          const Success(
            AuthUser(
              id: 'user-1',
              email: 'user@test.dev',
              isEmailVerified: true,
            ),
          );

  final Result<AuthUser> signInResult;
  int signInCalls = 0;
  int registerCalls = 0;
  String? lastEmail;

  @override
  Stream<Result<AuthUser?>> authStateChanges() {
    return const Stream.empty();
  }

  @override
  Future<Result<AuthUser>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalls += 1;
    lastEmail = email;
    return signInResult;
  }

  @override
  Future<Result<AuthUser>> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    registerCalls += 1;
    return const Success(
      AuthUser(id: 'user-1', email: 'user@test.dev', isEmailVerified: false),
    );
  }

  @override
  Future<Result<void>> signOut() async {
    return const Success(null);
  }
}

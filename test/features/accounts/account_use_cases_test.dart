import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/errors/app_failure.dart';
import 'package:money_tracker/core/utils/result.dart';
import 'package:money_tracker/features/accounts/application/usecases/account_use_cases.dart';
import 'package:money_tracker/features/accounts/application/usecases/ensure_default_account_use_case.dart';
import 'package:money_tracker/features/accounts/domain/entities/account.dart';
import 'package:money_tracker/features/accounts/domain/repositories/account_repository.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

void main() {
  group('WatchAccountsUseCase', () {
    test('returns accounts from the repository stream', () async {
      final account = _account(id: 'cash');
      final repository = _FakeAccountRepository(accounts: [account]);
      final useCase = WatchAccountsUseCase(repository);

      final result = await useCase.execute().first;

      expect(result, isA<Success<List<Account>>>());
      expect((result as Success<List<Account>>).value.single.id, 'cash');
    });
  });

  group('EnsureDefaultAccountUseCase', () {
    test('creates an IDR cash account when the user has no accounts', () async {
      final repository = _FakeAccountRepository();
      final useCase = EnsureDefaultAccountUseCase(repository);

      await useCase.execute('user-1');

      expect(repository.createdAccounts, hasLength(1));
      final account = repository.createdAccounts.single;
      expect(account.id, 'user-1_cash_default');
      expect(account.name, 'Cash');
      expect(account.type, AccountType.cash);
      expect(account.currency, 'IDR');
      expect(account.openingBalance, 0);
      expect(account.isArchived, isFalse);
    });

    test('does not create a default account when one already exists', () async {
      final repository = _FakeAccountRepository(
        accounts: [_account(id: 'cash')],
      );
      final useCase = EnsureDefaultAccountUseCase(repository);

      await useCase.execute('user-1');

      expect(repository.createdAccounts, isEmpty);
    });

    test(
      'does not create a default account when checking accounts fails',
      () async {
        final repository = _FakeAccountRepository(
          hasAnyAccountResult: const Failure(
            AppFailure(
              type: AppFailureType.authorization,
              message: 'Permission denied.',
            ),
          ),
        );
        final useCase = EnsureDefaultAccountUseCase(repository);

        await useCase.execute('user-1');

        expect(repository.createdAccounts, isEmpty);
      },
    );
  });
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository({
    List<Account>? accounts,
    Result<bool>? hasAnyAccountResult,
  }) : accounts = [...?accounts],
       hasAnyAccountResult =
           hasAnyAccountResult ??
           Success(accounts != null && accounts.isNotEmpty);

  final List<Account> accounts;
  final Result<bool> hasAnyAccountResult;
  final List<Account> createdAccounts = [];

  @override
  Stream<Result<List<Account>>> watchAccounts() {
    return Stream.value(Success(accounts));
  }

  @override
  Future<Result<bool>> hasAnyAccount() async {
    return hasAnyAccountResult;
  }

  @override
  Future<Result<void>> createAccount(Account account) async {
    createdAccounts.add(account);
    accounts.add(account);
    return const Success(null);
  }
}

Account _account({required String id}) {
  final now = DateTime.utc(2026);
  return Account(
    id: id,
    name: 'Cash',
    type: AccountType.cash,
    currency: 'IDR',
    openingBalance: 0,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

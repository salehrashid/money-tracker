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
    test(
      'creates IDR cash and rekening accounts when the user has no accounts',
      () async {
        final repository = _FakeAccountRepository();
        final useCase = EnsureDefaultAccountUseCase(repository);

        await useCase.execute('user-1');

        expect(repository.createdAccounts, hasLength(2));

        final cashAccount = repository.createdAccounts[0];
        expect(cashAccount.id, 'user-1_cash_default');
        expect(cashAccount.name, 'Cash');
        expect(cashAccount.type, AccountType.cash);
        expect(cashAccount.currency, 'IDR');
        expect(cashAccount.openingBalance, 0);
        expect(cashAccount.isArchived, isFalse);

        final rekeningAccount = repository.createdAccounts[1];
        expect(rekeningAccount.id, 'user-1_rekening_default');
        expect(rekeningAccount.name, 'Rekening');
        expect(rekeningAccount.type, AccountType.bank);
        expect(rekeningAccount.currency, 'IDR');
        expect(rekeningAccount.openingBalance, 0);
        expect(rekeningAccount.isArchived, isFalse);
      },
    );

    test(
      'creates only rekening when the existing cash default exists',
      () async {
        final repository = _FakeAccountRepository(
          accounts: [_account(id: 'user-1_cash_default')],
        );
        final useCase = EnsureDefaultAccountUseCase(repository);

        await useCase.execute('user-1');

        expect(repository.createdAccounts, hasLength(1));
        final account = repository.createdAccounts.single;
        expect(account.id, 'user-1_rekening_default');
        expect(account.name, 'Rekening');
        expect(account.type, AccountType.bank);
      },
    );

    test('does not create default accounts when both already exist', () async {
      final repository = _FakeAccountRepository(
        accounts: [
          _account(id: 'user-1_cash_default'),
          _account(
            id: 'user-1_rekening_default',
            name: 'Rekening',
            type: AccountType.bank,
          ),
        ],
      );
      final useCase = EnsureDefaultAccountUseCase(repository);

      await useCase.execute('user-1');

      expect(repository.createdAccounts, isEmpty);
    });

    test(
      'does not create default accounts when checking accounts fails',
      () async {
        final repository = _FakeAccountRepository(
          accountsResult: const Failure(
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
    Result<List<Account>>? accountsResult,
  }) : accounts = [...?accounts],
       accountsResult = accountsResult ?? Success([...?accounts]);

  final List<Account> accounts;
  final Result<List<Account>> accountsResult;
  final List<Account> createdAccounts = [];

  @override
  Stream<Result<List<Account>>> watchAccounts() {
    return Stream.value(accountsResult);
  }

  @override
  Future<Result<bool>> hasAnyAccount() async {
    return Success(accounts.isNotEmpty);
  }

  @override
  Future<Result<void>> createAccount(Account account) async {
    createdAccounts.add(account);
    accounts.add(account);
    return const Success(null);
  }
}

Account _account({
  required String id,
  String name = 'Cash',
  AccountType type = AccountType.cash,
}) {
  final now = DateTime.utc(2026);
  return Account(
    id: id,
    name: name,
    type: type,
    currency: 'IDR',
    openingBalance: 0,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

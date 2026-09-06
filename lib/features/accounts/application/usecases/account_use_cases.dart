import '../../../../core/utils/result.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../../../core/errors/app_failure.dart';
import 'account_commands.dart';

class WatchAccountsUseCase {
  const WatchAccountsUseCase(this._repository);

  final AccountRepository _repository;

  Stream<Result<List<Account>>> execute() {
    return _repository.watchAccounts();
  }
}

class CreateAccountUseCase {
  const CreateAccountUseCase(this._repository);
  final MutableAccountRepository _repository;

  Future<Result<void>> execute(SaveAccountCommand command) async {
    final failure = await _validate(_repository, command);
    if (failure != null) return Failure(failure);
    final now = DateTime.now().toUtc();
    return _repository.createAccount(
      Account(
        id: '',
        name: command.name.trim(),
        type: command.type,
        parentAccountId: _parent(command.parentAccountId),
        currency: command.currency.trim().toUpperCase(),
        initialBalance: command.initialBalance,
        isArchived: false,
        sortOrder: command.sortOrder,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

class UpdateAccountUseCase {
  const UpdateAccountUseCase(this._repository);
  final MutableAccountRepository _repository;

  Future<Result<Account>> execute({
    required Account account,
    required SaveAccountCommand command,
  }) async {
    final failure = await _validate(_repository, command, account: account);
    if (failure != null) return Failure(failure);
    return _repository.updateAccount(
      account.copyWith(
        name: command.name.trim(),
        type: command.type,
        parentAccountId: _parent(command.parentAccountId),
        clearParentAccountId: _parent(command.parentAccountId) == null,
        currency: command.currency.trim().toUpperCase(),
        initialBalance: command.initialBalance,
        sortOrder: command.sortOrder,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}

class SetAccountArchivedUseCase {
  const SetAccountArchivedUseCase(this._repository);
  final MutableAccountRepository _repository;
  Future<Result<Account>> execute({
    required String accountId,
    required bool isArchived,
  }) => _repository.setArchived(accountId: accountId, isArchived: isArchived);
}

class DeleteAccountUseCase {
  const DeleteAccountUseCase(this._repository);
  final MutableAccountRepository _repository;

  Future<Result<void>> execute({
    required String accountId,
    required bool isReferenced,
  }) async {
    final accountsResult = await _repository.fetchAccounts();
    if (accountsResult case Failure<List<Account>>(:final failure))
      return Failure(failure);
    final accounts = (accountsResult as Success<List<Account>>).value;
    if (accounts.any((item) => item.parentAccountId == accountId)) {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          code: 'account-has-children',
          message: 'Move or remove this account’s pockets first.',
        ),
      );
    }
    if (isReferenced) {
      final result = await _repository.setArchived(
        accountId: accountId,
        isArchived: true,
      );
      return result.when(
        success: (_) => const Success(null),
        failure: Failure.new,
      );
    }
    return _repository.deleteAccount(accountId);
  }
}

String? _parent(String? value) {
  final result = value?.trim();
  return result == null || result.isEmpty ? null : result;
}

Future<AppFailure?> _validate(
  MutableAccountRepository repository,
  SaveAccountCommand command, {
  Account? account,
}) async {
  if (command.name.trim().isEmpty)
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'empty-account-name',
      message: 'Enter an account name.',
    );
  if (command.name.trim().length > 48)
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'account-name-too-long',
      message: 'Account name must be 48 characters or fewer.',
    );
  if (command.currency.trim().isEmpty)
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'empty-account-currency',
      message: 'Enter a currency.',
    );
  final parentId = _parent(command.parentAccountId);
  if (parentId == null) return null;
  if (parentId == account?.id)
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'account-self-parent',
      message: 'An account cannot be its own parent.',
    );
  final result = await repository.fetchAccounts();
  if (result case Failure<List<Account>>(:final failure)) return failure;
  final accounts = (result as Success<List<Account>>).value;
  final parent = accounts.where((item) => item.id == parentId).firstOrNull;
  if (parent == null || parent.parentAccountId != null || parent.isArchived)
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'invalid-account-parent',
      message: 'Choose an active top-level account.',
    );
  if (account != null &&
      accounts.any((item) => item.parentAccountId == account.id))
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'account-has-children',
      message: 'Move this account’s pockets before making it a sub-account.',
    );
  return null;
}

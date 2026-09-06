import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/offline/sync_coordinator.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/firebase_account_data_source.dart';
import 'package:uuid/uuid.dart';

class FirebaseAccountRepository implements MutableAccountRepository {
  FirebaseAccountRepository({
    required FirebaseAccountDataSource dataSource,
    required LocalFirstCollection<Account> local,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _errorMapper = errorMapper,
       _local = local;

  final FirebaseErrorMapper _errorMapper;
  final LocalFirstCollection<Account> _local;

  @override
  Stream<Result<List<Account>>> watchAccounts() async* {
    await for (final accounts in _local.watch()) {
      accounts.sort(_sortAccounts);
      yield Success(accounts);
    }
  }

  @override
  Future<Result<bool>> hasAnyAccount() async {
    try {
      return Success(_local.current.isNotEmpty);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<List<Account>>> fetchAccounts() async {
    try {
      final accounts = _local.current..sort(_sortAccounts);
      return Success(accounts);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<void>> createAccount(Account account) async {
    try {
      final duplicate = _duplicateFailure(account);
      if (duplicate != null) return Failure(duplicate);
      final saved = account.id.isEmpty
          ? account.copyWith(id: const Uuid().v4())
          : account;
      await _local.save(saved, isCreate: true);
      return const Success(null);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<Account>> updateAccount(Account account) async {
    try {
      if (!_local.current.any((item) => item.id == account.id)) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'account-not-found',
            message: 'Account not found.',
          ),
        );
      }
      final duplicate = _duplicateFailure(account);
      if (duplicate != null) return Failure(duplicate);
      await _local.save(account, isCreate: false);
      return Success(account);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<Account>> setArchived({
    required String accountId,
    required bool isArchived,
  }) async {
    final current = _local.current
        .where((item) => item.id == accountId)
        .firstOrNull;
    if (current == null) {
      return const Failure(
        AppFailure(
          type: AppFailureType.notFound,
          code: 'account-not-found',
          message: 'Account not found.',
        ),
      );
    }
    return updateAccount(
      current.copyWith(
        isArchived: isArchived,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<Result<void>> deleteAccount(String accountId) async {
    try {
      final current = _local.current
          .where((item) => item.id == accountId)
          .firstOrNull;
      if (current == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'account-not-found',
            message: 'Account not found.',
          ),
        );
      }
      await _local.delete(current);
      return const Success(null);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  AppFailure? _duplicateFailure(Account account) {
    final name = account.name.trim().toLowerCase();
    if (_local.current.any(
      (item) => item.id != account.id && item.name.trim().toLowerCase() == name,
    )) {
      return const AppFailure(
        type: AppFailureType.validation,
        code: 'duplicate-account',
        message: 'An account with this name already exists.',
      );
    }
    return null;
  }

  AppFailure _mapError(Object error) {
    if (error is FormatException) {
      return AppFailure(
        type: AppFailureType.validation,
        code: 'invalid-account-data',
        message: 'Account data is invalid. Please try again.',
        details: error,
      );
    }

    return _errorMapper.map(error);
  }
}

int _sortAccounts(Account first, Account second) {
  final archiveCompare = first.isArchived.toString().compareTo(
    second.isArchived.toString(),
  );
  if (archiveCompare != 0) {
    return archiveCompare;
  }

  final orderCompare = first.sortOrder.compareTo(second.sortOrder);
  if (orderCompare != 0) return orderCompare;

  return first.name.toLowerCase().compareTo(second.name.toLowerCase());
}

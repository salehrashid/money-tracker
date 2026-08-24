import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/offline/sync_coordinator.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/firebase_account_data_source.dart';

class FirebaseAccountRepository implements AccountRepository {
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
  Future<Result<void>> createAccount(Account account) async {
    try {
      await _local.save(account, isCreate: true);
      return const Success(null);
    } catch (error) {
      return Failure(_mapError(error));
    }
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

  return first.name.toLowerCase().compareTo(second.name.toLowerCase());
}

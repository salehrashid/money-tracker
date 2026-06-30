import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/firebase_account_data_source.dart';

class FirebaseAccountRepository implements AccountRepository {
  const FirebaseAccountRepository({
    required FirebaseAccountDataSource dataSource,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _dataSource = dataSource,
       _errorMapper = errorMapper;

  final FirebaseAccountDataSource _dataSource;
  final FirebaseErrorMapper _errorMapper;

  @override
  Stream<Result<List<Account>>> watchAccounts() async* {
    try {
      await for (final dtos in _dataSource.watchAccounts()) {
        final accounts = dtos.map((dto) => dto.toDomain()).toList()
          ..sort(_sortAccounts);
        yield Success(accounts);
      }
    } catch (error) {
      yield Failure(_mapError(error));
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

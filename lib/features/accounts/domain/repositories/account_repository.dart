import '../../../../core/utils/result.dart';
import '../entities/account.dart';

abstract interface class AccountRepository {
  Stream<Result<List<Account>>> watchAccounts();

  /// Returns true if the user already has at least one financial account.
  Future<Result<bool>> hasAnyAccount();

  /// Persists [account] to the data store. Idempotent when the document already exists.
  Future<Result<void>> createAccount(Account account);
}

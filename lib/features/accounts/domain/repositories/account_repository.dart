import '../../../../core/utils/result.dart';
import '../entities/account.dart';

abstract interface class AccountRepository {
  Stream<Result<List<Account>>> watchAccounts();
}

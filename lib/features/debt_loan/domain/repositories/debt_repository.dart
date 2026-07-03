import '../../../../core/utils/result.dart';
import '../entities/debt.dart';

abstract interface class DebtRepository {
  Stream<Result<List<Debt>>> watchDebts();

  Future<Result<Debt>> createDebt(Debt debt);

  Future<Result<Debt>> updateDebt(Debt debt);

  Future<Result<void>> deleteDebt(String debtId);
}

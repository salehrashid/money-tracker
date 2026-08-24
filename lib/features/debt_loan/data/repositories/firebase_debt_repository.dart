import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/offline/sync_coordinator.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';
import '../datasources/firebase_debt_data_source.dart';
import 'package:uuid/uuid.dart';

class FirebaseDebtRepository implements DebtRepository {
  FirebaseDebtRepository({
    required FirebaseDebtDataSource dataSource,
    required LocalFirstCollection<Debt> local,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _errorMapper = errorMapper,
       _local = local;

  final FirebaseErrorMapper _errorMapper;
  final LocalFirstCollection<Debt> _local;

  @override
  Stream<Result<List<Debt>>> watchDebts() async* {
    await for (final debts in _local.watch()) {
      debts.sort(_sortDebts);
      yield Success(debts);
    }
  }

  @override
  Future<Result<Debt>> createDebt(Debt debt) async {
    try {
      final saved = debt.copyWith(id: const Uuid().v4());
      await _local.save(saved, isCreate: true);
      return Success(saved);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<Debt>> updateDebt(Debt debt) async {
    try {
      final current = _local.current
          .where((item) => item.id == debt.id)
          .firstOrNull;
      if (current == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'debt-not-found',
            message: 'Debt record not found.',
          ),
        );
      }

      await _local.save(debt, isCreate: false);
      return Success(debt);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<void>> deleteDebt(String debtId) async {
    try {
      final current = _local.current
          .where((item) => item.id == debtId)
          .firstOrNull;
      if (current == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'debt-not-found',
            message: 'Debt record not found.',
          ),
        );
      }

      await _local.delete(current);
      return const Success(null);
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  AppFailure _mapError(Object error) {
    if (error is FormatException) {
      return AppFailure(
        type: AppFailureType.validation,
        code: 'invalid-debt-data',
        message: 'Saved debt data is invalid. Please try again.',
        details: error,
      );
    }

    return _errorMapper.map(error);
  }
}

int _sortDebts(Debt first, Debt second) {
  final statusCompare = _statusSort(first).compareTo(_statusSort(second));
  if (statusCompare != 0) {
    return statusCompare;
  }

  final firstDueDate = first.dueDate;
  final secondDueDate = second.dueDate;
  if (firstDueDate != null && secondDueDate != null) {
    final dueDateCompare = firstDueDate.compareTo(secondDueDate);
    if (dueDateCompare != 0) {
      return dueDateCompare;
    }
  } else if (firstDueDate != null) {
    return -1;
  } else if (secondDueDate != null) {
    return 1;
  }

  return second.updatedAt.compareTo(first.updatedAt);
}

int _statusSort(Debt debt) {
  return switch (debt.status) {
    DebtStatus.open => 0,
    DebtStatus.paid => 1,
    DebtStatus.cancelled => 2,
  };
}

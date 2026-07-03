import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';
import '../datasources/firebase_debt_data_source.dart';
import '../dto/debt_dto.dart';

class FirebaseDebtRepository implements DebtRepository {
  const FirebaseDebtRepository({
    required FirebaseDebtDataSource dataSource,
    FirebaseErrorMapper errorMapper = const FirebaseErrorMapper(),
  }) : _dataSource = dataSource,
       _errorMapper = errorMapper;

  final FirebaseDebtDataSource _dataSource;
  final FirebaseErrorMapper _errorMapper;

  @override
  Stream<Result<List<Debt>>> watchDebts() async* {
    try {
      await for (final dtos in _dataSource.watchDebts()) {
        final debts = dtos.map((dto) => dto.toDomain()).toList()
          ..sort(_sortDebts);
        yield Success(debts);
      }
    } catch (error) {
      yield Failure(_mapError(error));
    }
  }

  @override
  Future<Result<Debt>> createDebt(Debt debt) async {
    try {
      final saved = await _dataSource.saveDebt(DebtDto.fromDomain(debt));
      return Success(saved.toDomain());
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<Debt>> updateDebt(Debt debt) async {
    try {
      final current = await _dataSource.fetchDebt(debt.id);
      if (current == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'debt-not-found',
            message: 'Debt record not found.',
          ),
        );
      }

      final saved = await _dataSource.saveDebt(DebtDto.fromDomain(debt));
      return Success(saved.toDomain());
    } catch (error) {
      return Failure(_mapError(error));
    }
  }

  @override
  Future<Result<void>> deleteDebt(String debtId) async {
    try {
      final current = await _dataSource.fetchDebt(debtId);
      if (current == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.notFound,
            code: 'debt-not-found',
            message: 'Debt record not found.',
          ),
        );
      }

      await _dataSource.deleteDebt(debtId);
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

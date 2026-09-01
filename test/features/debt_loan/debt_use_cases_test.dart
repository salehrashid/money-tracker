import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/debt_loan/data/dto/debt_dto.dart';
import 'package:money_tracker/core/errors/app_failure.dart';
import 'package:money_tracker/core/utils/result.dart';
import 'package:money_tracker/features/debt_loan/application/usecases/debt_commands.dart';
import 'package:money_tracker/features/debt_loan/application/usecases/debt_use_cases.dart';
import 'package:money_tracker/features/debt_loan/domain/entities/debt.dart';
import 'package:money_tracker/features/debt_loan/domain/repositories/debt_repository.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

void main() {
  group('DebtDto', () {
    test('parses a blank note from Firestore data', () {
      final createdAt = DateTime.utc(2026, 1, 2);
      final updatedAt = DateTime.utc(2026, 1, 3);

      final dto = DebtDto.fromMap({
        'id': 'debt-1',
        'kind': 'debt',
        'personName': 'Ari',
        'amount': 100000,
        'currency': 'IDR',
        'status': 'open',
        'transactionDate': DateTime.utc(2026, 1, 1),
        'note': '',
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      });

      expect(dto.note, '');
    });
  });

  group('CreateDebtUseCase', () {
    test('returns validation failure for an empty person name', () async {
      final repository = _FakeDebtRepository();
      final useCase = CreateDebtUseCase(repository);

      final result = await useCase.execute(
        SaveDebtCommand(
          kind: DebtKind.debt,
          personName: ' ',
          amount: 100000,
          status: DebtStatus.open,
          note: '',
          transactionDate: DateTime.utc(2026, 1, 1),
        ),
      );

      expect(result, isA<Failure<Debt>>());
      expect(repository.debts, isEmpty);
    });

    test('creates an IDR receivable with trimmed text values', () async {
      final repository = _FakeDebtRepository();
      final useCase = CreateDebtUseCase(repository);

      final result = await useCase.execute(
        SaveDebtCommand(
          kind: DebtKind.receivable,
          personName: '  Ari  ',
          amount: 75000,
          status: DebtStatus.open,
          note: '  Dinner split  ',
          transactionDate: DateTime.utc(2026, 1, 1),
        ),
      );

      final debt = (result as Success<Debt>).value;
      expect(debt.personName, 'Ari');
      expect(debt.currency, 'IDR');
      expect(debt.note, 'Dinner split');
      expect(repository.debts.single.kind, DebtKind.receivable);
    });
  });

  group('SetDebtStatusUseCase', () {
    test('updates a debt record status', () async {
      final debt = _debt(id: 'debt-1');
      final repository = _FakeDebtRepository([debt]);
      final useCase = SetDebtStatusUseCase(repository);

      final result = await useCase.execute(debt: debt, status: DebtStatus.paid);

      expect(result, isA<Success<Debt>>());
      expect(repository.debts.single.status, DebtStatus.paid);
    });
  });
}

class _FakeDebtRepository implements DebtRepository {
  _FakeDebtRepository([List<Debt>? debts]) : debts = [...?debts];

  final List<Debt> debts;

  @override
  Stream<Result<List<Debt>>> watchDebts() {
    return Stream.value(Success(debts));
  }

  @override
  Future<Result<Debt>> createDebt(Debt debt) async {
    final saved = debt.copyWith(
      id: debt.id.isEmpty ? 'debt-${debts.length + 1}' : debt.id,
    );
    debts.add(saved);
    return Success(saved);
  }

  @override
  Future<Result<Debt>> updateDebt(Debt debt) async {
    final index = debts.indexWhere((item) => item.id == debt.id);
    if (index == -1) {
      return const Failure(
        AppFailure(
          type: AppFailureType.notFound,
          message: 'Debt record not found.',
        ),
      );
    }
    debts[index] = debt;
    return Success(debt);
  }

  @override
  Future<Result<void>> deleteDebt(String debtId) async {
    debts.removeWhere((debt) => debt.id == debtId);
    return const Success(null);
  }
}

Debt _debt({required String id}) {
  final now = DateTime.utc(2026);
  return Debt(
    id: id,
    kind: DebtKind.debt,
    personName: 'Ari',
    amount: 100000,
    currency: 'IDR',
    status: DebtStatus.open,
    transactionDate: now,
    note: '',
    createdAt: now,
    updatedAt: now,
  );
}

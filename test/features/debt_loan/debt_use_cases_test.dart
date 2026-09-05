import 'dart:convert';
import 'dart:typed_data';

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
      expect(dto.transferProofBase64, isNull);
    });

    test('reads an empty legacy transfer proof as absent', () {
      final data = DebtDto.fromDomain(_debt(id: 'debt-1')).toFirestore();
      data['transferProofBase64'] = '';

      expect(DebtDto.fromMap(data).transferProofBase64, isNull);
    });

    test('roundtrips a transfer proof through Firestore and domain', () {
      final original = _debt(id: 'debt-1', transferProofBase64: _transferProof);

      final restored = DebtDto.fromMap(
        DebtDto.fromDomain(original).toFirestore(),
      ).toDomain();

      expect(restored.transferProofBase64, _transferProof);
      expect(restored.id, original.id);
    });

    test('serializes an explicit null when the transfer proof is removed', () {
      final debt = _debt(id: 'debt-1', transferProofBase64: _transferProof);
      final data = DebtDto.fromDomain(
        debt.copyWith(clearTransferProof: true),
      ).toFirestore();

      expect(data.containsKey('transferProofBase64'), isTrue);
      expect(data['transferProofBase64'], isNull);
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
      expect(debt.transferProofBase64, isNull);
      expect(repository.debts.single.kind, DebtKind.receivable);
    });

    test('preserves a transfer proof when assigning the new debt id', () async {
      final repository = _FakeDebtRepository();

      final result = await CreateDebtUseCase(
        repository,
      ).execute(_command(transferProofBase64: _transferProof));

      final debt = (result as Success<Debt>).value;
      expect(debt.id, 'debt-1');
      expect(debt.transferProofBase64, _transferProof);
    });

    test('accepts a transfer proof at the encoded size limit', () async {
      final repository = _FakeDebtRepository();
      final proof = base64Encode(Uint8List(debtTransferProofMaxBytes));

      final result = await CreateDebtUseCase(
        repository,
      ).execute(_command(transferProofBase64: proof));

      expect(result, isA<Success<Debt>>());
      expect(repository.debts.single.transferProofBase64, proof);
    });
  });

  group('UpdateDebtUseCase', () {
    test('adds, replaces, and removes an optional transfer proof', () async {
      final original = _debt(id: 'debt-1');
      final repository = _FakeDebtRepository([original]);
      final useCase = UpdateDebtUseCase(repository);
      final replacement = base64Encode([1, 2, 3, 4]);

      final added = await useCase.execute(
        debt: original,
        command: _command(transferProofBase64: _transferProof),
      );
      expect(
        (added as Success<Debt>).value.transferProofBase64,
        _transferProof,
      );

      final replaced = await useCase.execute(
        debt: added.value,
        command: _command(transferProofBase64: replacement),
      );
      expect(
        (replaced as Success<Debt>).value.transferProofBase64,
        replacement,
      );

      final removed = await useCase.execute(
        debt: replaced.value,
        command: _command(),
      );
      expect((removed as Success<Debt>).value.transferProofBase64, isNull);
      expect(repository.debts.single.transferProofBase64, isNull);
    });
  });

  group('Transfer proof validation', () {
    for (final invalidProof in <String, String>{
      'malformed': 'not valid base64!',
      'oversized': base64Encode(Uint8List(debtTransferProofMaxBytes + 1)),
    }.entries) {
      test('rejects ${invalidProof.key} transfer proof on create', () async {
        final repository = _FakeDebtRepository();

        final result = await CreateDebtUseCase(
          repository,
        ).execute(_command(transferProofBase64: invalidProof.value));

        expect(
          (result as Failure<Debt>).failure.type,
          AppFailureType.validation,
        );
        expect(repository.debts, isEmpty);
      });

      test('rejects ${invalidProof.key} transfer proof on update', () async {
        final original = _debt(
          id: 'debt-1',
          transferProofBase64: _transferProof,
        );
        final repository = _FakeDebtRepository([original]);

        final result = await UpdateDebtUseCase(repository).execute(
          debt: original,
          command: _command(transferProofBase64: invalidProof.value),
        );

        expect(
          (result as Failure<Debt>).failure.type,
          AppFailureType.validation,
        );
        expect(repository.debts.single.transferProofBase64, _transferProof);
      });
    }
  });

  group('SetDebtStatusUseCase', () {
    test('updates a debt record status', () async {
      final debt = _debt(id: 'debt-1', transferProofBase64: _transferProof);
      final repository = _FakeDebtRepository([debt]);
      final useCase = SetDebtStatusUseCase(repository);

      final result = await useCase.execute(debt: debt, status: DebtStatus.paid);

      expect(result, isA<Success<Debt>>());
      expect(repository.debts.single.status, DebtStatus.paid);
      expect(repository.debts.single.transferProofBase64, _transferProof);
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

const _transferProof =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aRZkAAAAASUVORK5CYII=';

SaveDebtCommand _command({String? transferProofBase64}) {
  return SaveDebtCommand(
    kind: DebtKind.debt,
    personName: 'Ari',
    amount: 100000,
    status: DebtStatus.open,
    note: '',
    transactionDate: DateTime.utc(2026, 1, 1),
    transferProofBase64: transferProofBase64,
  );
}

Debt _debt({required String id, String? transferProofBase64}) {
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
    transferProofBase64: transferProofBase64,
    createdAt: now,
    updatedAt: now,
  );
}

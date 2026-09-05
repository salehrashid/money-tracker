import 'dart:convert';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';
import 'debt_commands.dart';

class WatchDebtsUseCase {
  const WatchDebtsUseCase(this._repository);

  final DebtRepository _repository;

  Stream<Result<List<Debt>>> execute() {
    return _repository.watchDebts();
  }
}

class CreateDebtUseCase {
  const CreateDebtUseCase(this._repository);

  final DebtRepository _repository;

  Future<Result<Debt>> execute(SaveDebtCommand command) {
    final failure = _validate(command);
    if (failure != null) {
      return Future.value(Failure(failure));
    }

    final now = DateTime.now().toUtc();
    return _repository.createDebt(
      Debt(
        id: '',
        kind: command.kind,
        personName: command.personName.trim(),
        amount: command.amount,
        currency: 'IDR',
        status: command.status,
        transactionDate: command.transactionDate.toUtc(),
        note: command.note.trim(),
        transferProofBase64: _transferProofOrNull(command.transferProofBase64),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

class UpdateDebtUseCase {
  const UpdateDebtUseCase(this._repository);

  final DebtRepository _repository;

  Future<Result<Debt>> execute({
    required Debt debt,
    required SaveDebtCommand command,
  }) {
    final failure = _validate(command);
    if (failure != null) {
      return Future.value(Failure(failure));
    }

    return _repository.updateDebt(
      debt.copyWith(
        kind: command.kind,
        personName: command.personName.trim(),
        amount: command.amount,
        currency: 'IDR',
        status: command.status,
        transactionDate: command.transactionDate.toUtc(),
        note: command.note.trim(),
        transferProofBase64: _transferProofOrNull(command.transferProofBase64),
        clearTransferProof:
            _transferProofOrNull(command.transferProofBase64) == null,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}

class SetDebtStatusUseCase {
  const SetDebtStatusUseCase(this._repository);

  final DebtRepository _repository;

  Future<Result<Debt>> execute({
    required Debt debt,
    required DebtStatus status,
  }) {
    if (debt.id.trim().isEmpty) {
      return Future.value(
        const Failure(
          AppFailure(
            type: AppFailureType.validation,
            code: 'missing-debt-id',
            message: 'Choose a debt record first.',
          ),
        ),
      );
    }

    return _repository.updateDebt(
      debt.copyWith(status: status, updatedAt: DateTime.now().toUtc()),
    );
  }
}

class DeleteDebtUseCase {
  const DeleteDebtUseCase(this._repository);

  final DebtRepository _repository;

  Future<Result<void>> execute(String debtId) {
    if (debtId.trim().isEmpty) {
      return Future.value(
        const Failure(
          AppFailure(
            type: AppFailureType.validation,
            code: 'missing-debt-id',
            message: 'Choose a debt record first.',
          ),
        ),
      );
    }

    return _repository.deleteDebt(debtId);
  }
}

AppFailure? _validate(SaveDebtCommand command) {
  final personName = command.personName.trim();
  final note = command.note.trim();

  if (personName.isEmpty) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'empty-debt-person',
      message: 'Enter the person name.',
    );
  }
  if (personName.length > 72) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'debt-person-too-long',
      message: 'Person name must be 72 characters or fewer.',
    );
  }
  if (command.amount <= 0) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'invalid-debt-amount',
      message: 'Enter an amount greater than zero.',
    );
  }
  if (note.length > 160) {
    return const AppFailure(
      type: AppFailureType.validation,
      code: 'debt-note-too-long',
      message: 'Note must be 160 characters or fewer.',
    );
  }

  final transferProof = _transferProofOrNull(command.transferProofBase64);
  if (transferProof != null) {
    const maxEncodedLength = ((debtTransferProofMaxBytes + 2) ~/ 3) * 4;
    const tooLargeFailure = AppFailure(
      type: AppFailureType.validation,
      code: 'debt-transfer-proof-too-large',
      message: 'Choose a smaller transfer proof photo.',
    );
    if (transferProof.length > maxEncodedLength) {
      return tooLargeFailure;
    }
    try {
      final bytes = base64Decode(transferProof);
      if (bytes.length > debtTransferProofMaxBytes) {
        return tooLargeFailure;
      }
    } on FormatException {
      return const AppFailure(
        type: AppFailureType.validation,
        code: 'invalid-debt-transfer-proof',
        message: 'Choose a valid transfer proof photo.',
      );
    }
  }

  return null;
}

String? _transferProofOrNull(String? value) {
  return value == null || value.isEmpty ? null : value;
}

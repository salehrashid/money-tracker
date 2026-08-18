import 'package:flutter/foundation.dart';

import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';

/// Ensures every authenticated user has at least one financial account.
///
/// This use case is idempotent: calling it multiple times is safe and will
/// never create duplicate accounts. The default account is a Cash account with
/// an opening balance of 0 in IDR.
class EnsureDefaultAccountUseCase {
  const EnsureDefaultAccountUseCase(this._repository);

  final AccountRepository _repository;

  Future<void> execute(String uid) async {
    _log('Current UID: $uid');
    _log('Checking default account...');

    final hasAccountResult = await _repository.hasAnyAccount();

    switch (hasAccountResult) {
      case Failure(:final failure):
        _log('Firestore error: ${failure.message}');
        return;

      case Success(:final value):
        if (value) {
          _log('Default account already exists.');
          return;
        }
    }

    _log('Creating default account...');

    final now = DateTime.now().toUtc();
    final defaultAccount = Account(
      id: '${uid}_cash_default',
      name: 'Cash',
      type: AccountType.cash,
      currency: 'IDR',
      openingBalance: 0,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    final createResult = await _repository.createAccount(defaultAccount);

    switch (createResult) {
      case Success():
        _log('Default account created successfully.');
      case Failure(:final failure):
        _log('Firestore error: ${failure.message}');
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[DefaultAccount] $message');
    }
  }
}

import 'package:flutter/foundation.dart';

import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';

/// Ensures every authenticated user has at least the default financial accounts.
///
/// This use case is idempotent: calling it multiple times is safe and will
/// never create duplicate accounts. Two default accounts are created:
/// a Cash account and a Rekening (bank) account, both with an opening balance
/// of 0 in IDR.
class EnsureDefaultAccountUseCase {
  const EnsureDefaultAccountUseCase(this._repository);

  final AccountRepository _repository;

  Future<void> execute(String uid) async {
    _log('Current UID: $uid');
    _log('Checking default accounts...');

    final accountsResult = await _repository.watchAccounts().first;

    switch (accountsResult) {
      case Failure(:final failure):
        _log('Firestore error: ${failure.message}');
        return;

      case Success(:final value):
        final defaultAccounts = _buildDefaultAccounts(uid);
        final existingAccountIds = value.map((account) => account.id).toSet();
        final missingDefaultAccounts = defaultAccounts
            .where((account) => !existingAccountIds.contains(account.id))
            .toList(growable: false);

        if (missingDefaultAccounts.isEmpty) {
          _log('Default accounts already exist.');
          return;
        }

        _log('Creating missing default accounts...');

        for (final account in missingDefaultAccounts) {
          final createResult = await _repository.createAccount(account);
          switch (createResult) {
            case Success():
              _log('Default account "${account.name}" created successfully.');
            case Failure(:final failure):
              _log(
                'Firestore error creating "${account.name}": ${failure.message}',
              );
          }
        }
    }
  }

  List<Account> _buildDefaultAccounts(String uid) {
    final now = DateTime.now().toUtc();
    return [
      Account(
        id: '${uid}_cash_default',
        name: 'Cash',
        type: AccountType.cash,
        currency: 'IDR',
        openingBalance: 0,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      ),
      Account(
        id: '${uid}_rekening_default',
        name: 'Rekening',
        type: AccountType.bank,
        currency: 'IDR',
        openingBalance: 0,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[DefaultAccount] $message');
    }
  }
}

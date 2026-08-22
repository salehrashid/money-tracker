import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/accounts/domain/entities/account.dart';
import 'package:money_tracker/features/categories/domain/entities/category.dart';
import 'package:money_tracker/features/notification_reader/domain/entities/detected_transaction.dart';
import 'package:money_tracker/features/transactions/application/usecases/transaction_commands.dart';
import 'package:money_tracker/features/transactions/presentation/widgets/transaction_form_dialog.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

void main() {
  testWidgets('selects Rekening IDR for a detected myBCA transaction', (
    tester,
  ) async {
    SaveTransactionCommand? savedCommand;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                savedCommand = await showDialog<SaveTransactionCommand>(
                  context: context,
                  builder: (_) => TransactionFormDialog(
                    categories: [_category()],
                    accounts: [
                      _account(
                        id: 'cash',
                        name: 'Cash',
                        type: AccountType.cash,
                      ),
                      _account(
                        id: 'rekening',
                        name: 'Rekening',
                        type: AccountType.bank,
                      ),
                    ],
                    detectedTransaction: DetectedTransaction(
                      type: TransactionType.expense,
                      amount: 25000,
                      originalText: 'Transaksi Rp25.000',
                      detectedAt: DateTime(2026, 8, 23),
                      sourcePackage: 'com.bca.mybca.omni.android',
                      source: 'myBCA',
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedCommand?.accountId, 'rekening');
  });

  testWidgets(
    'keeps the first active account fallback when Rekening is absent',
    (tester) async {
      SaveTransactionCommand? savedCommand;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  savedCommand = await showDialog<SaveTransactionCommand>(
                    context: context,
                    builder: (_) => TransactionFormDialog(
                      categories: [_category()],
                      accounts: [
                        _account(
                          id: 'cash',
                          name: 'Cash',
                          type: AccountType.cash,
                        ),
                      ],
                      detectedTransaction: DetectedTransaction(
                        type: TransactionType.expense,
                        amount: 25000,
                        originalText: 'Transaksi Rp25.000',
                        detectedAt: DateTime(2026, 8, 23),
                        sourcePackage: 'com.bca.mybca.omni.android',
                        source: 'myBCA',
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedCommand?.accountId, 'cash');
    },
  );
}

Account _account({
  required String id,
  required String name,
  required AccountType type,
}) {
  final now = DateTime(2026, 8, 23);
  return Account(
    id: id,
    name: name,
    type: type,
    currency: 'IDR',
    openingBalance: 0,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

Category _category() {
  final now = DateTime(2026, 8, 23);
  return Category(
    id: 'food',
    name: 'Food',
    type: TransactionType.expense,
    icon: 'restaurant',
    color: '#000000',
    isDefault: true,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

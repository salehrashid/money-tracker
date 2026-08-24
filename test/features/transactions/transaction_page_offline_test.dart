import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/errors/app_failure.dart';
import 'package:money_tracker/core/offline/offline_providers.dart';
import 'package:money_tracker/core/offline/sync_status.dart';
import 'package:money_tracker/core/utils/result.dart';
import 'package:money_tracker/features/accounts/domain/entities/account.dart';
import 'package:money_tracker/features/accounts/presentation/providers/account_providers.dart';
import 'package:money_tracker/features/auth/domain/entities/auth_user.dart';
import 'package:money_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:money_tracker/features/categories/domain/entities/category.dart';
import 'package:money_tracker/features/categories/presentation/providers/category_providers.dart';
import 'package:money_tracker/features/transactions/domain/entities/transaction.dart';
import 'package:money_tracker/features/transactions/domain/entities/transaction_draft.dart';
import 'package:money_tracker/features/transactions/presentation/pages/transaction_page.dart';
import 'package:money_tracker/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:money_tracker/shared/models/finance_enums.dart';

void main() {
  testWidgets(
    'cached transactions and CRUD actions remain available when draft refresh fails',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.utc(2026, 8, 23);
      final transaction = TransactionEntity(
        id: 'transaction-1',
        type: TransactionType.expense,
        amount: 42000,
        currency: 'IDR',
        categoryId: 'food',
        accountId: 'cash',
        note: 'Offline lunch',
        source: TransactionSource.manual,
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final category = Category(
        id: 'food',
        name: 'Food',
        type: TransactionType.expense,
        icon: 'restaurant',
        color: '#2E7D32',
        isDefault: true,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );
      final account = Account(
        id: 'cash',
        name: 'Cash',
        type: AccountType.cash,
        currency: 'IDR',
        openingBalance: 0,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(
                const Success(
                  AuthUser(
                    id: 'user-1',
                    email: 'user@example.com',
                    isEmailVerified: true,
                  ),
                ),
              ),
            ),
            transactionListProvider(
              'user-1',
            ).overrideWith((ref) => Stream.value(Success([transaction]))),
            pendingTransactionDraftListProvider('user-1').overrideWith(
              (ref) => Stream.value(
                const Failure<List<TransactionDraft>>(
                  AppFailure(
                    type: AppFailureType.network,
                    code: 'unavailable',
                    message: 'Network connection failed.',
                  ),
                ),
              ),
            ),
            categoryListProvider(
              'user-1',
            ).overrideWith((ref) => Stream.value(Success([category]))),
            accountListProvider(
              'user-1',
            ).overrideWith((ref) => Stream.value(Success([account]))),
            remoteSyncStateProvider(
              'user-1',
            ).overrideWith((ref) => Stream.value(RemoteSyncState.offline)),
          ],
          child: const MaterialApp(home: TransactionPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline lunch'), findsOneWidget);
      expect(find.text('Unable to load transactions'), findsNothing);
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);

      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNotNull,
      );
      final editButton = find.ancestor(
        of: find.byTooltip('Edit'),
        matching: find.byType(IconButton),
      );
      final deleteButton = find.ancestor(
        of: find.byTooltip('Delete'),
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(editButton).onPressed, isNotNull);
      expect(tester.widget<IconButton>(deleteButton).onPressed, isNotNull);
    },
  );
}

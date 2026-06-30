import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../application/usecases/transaction_filter.dart';
import '../../application/usecases/transaction_use_cases.dart';
import '../../data/datasources/firebase_transaction_data_source.dart';
import '../../data/repositories/firebase_transaction_repository.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_draft.dart';
import '../../domain/repositories/transaction_repository.dart';

final transactionDataSourceProvider =
    Provider.family<FirebaseTransactionDataSource, String>((ref, userId) {
      return FirebaseTransactionDataSource(
        ref.watch(firestoreUserCollectionsProvider(userId)),
      );
    });

final transactionRepositoryProvider =
    Provider.family<TransactionRepository, String>((ref, userId) {
      return FirebaseTransactionRepository(
        dataSource: ref.watch(transactionDataSourceProvider(userId)),
      );
    });

final watchTransactionsUseCaseProvider =
    Provider.family<WatchTransactionsUseCase, String>((ref, userId) {
      return WatchTransactionsUseCase(
        ref.watch(transactionRepositoryProvider(userId)),
      );
    });

final watchPendingTransactionDraftsUseCaseProvider =
    Provider.family<WatchPendingTransactionDraftsUseCase, String>((
      ref,
      userId,
    ) {
      return WatchPendingTransactionDraftsUseCase(
        ref.watch(transactionRepositoryProvider(userId)),
      );
    });

final createTransactionUseCaseProvider =
    Provider.family<CreateTransactionUseCase, String>((ref, userId) {
      return CreateTransactionUseCase(
        ref.watch(transactionRepositoryProvider(userId)),
      );
    });

final updateTransactionUseCaseProvider =
    Provider.family<UpdateTransactionUseCase, String>((ref, userId) {
      return UpdateTransactionUseCase(
        ref.watch(transactionRepositoryProvider(userId)),
      );
    });

final deleteTransactionUseCaseProvider =
    Provider.family<DeleteTransactionUseCase, String>((ref, userId) {
      return DeleteTransactionUseCase(
        ref.watch(transactionRepositoryProvider(userId)),
      );
    });

final saveTransactionDraftUseCaseProvider =
    Provider.family<SaveTransactionDraftUseCase, String>((ref, userId) {
      return SaveTransactionDraftUseCase(
        ref.watch(transactionRepositoryProvider(userId)),
      );
    });

final applyTransactionFiltersUseCaseProvider =
    Provider<ApplyTransactionFiltersUseCase>((ref) {
      return const ApplyTransactionFiltersUseCase();
    });

final transactionListProvider =
    StreamProvider.family<Result<List<TransactionEntity>>, String>((
      ref,
      userId,
    ) {
      return ref.watch(watchTransactionsUseCaseProvider(userId)).execute();
    });

final pendingTransactionDraftListProvider =
    StreamProvider.family<Result<List<TransactionDraft>>, String>((
      ref,
      userId,
    ) {
      return ref
          .watch(watchPendingTransactionDraftsUseCaseProvider(userId))
          .execute();
    });

final transactionOperationStateProvider =
    NotifierProvider.autoDispose<
      TransactionOperationNotifier,
      AsyncValue<void>
    >(TransactionOperationNotifier.new);

final transactionFilterProvider =
    NotifierProvider.autoDispose<
      TransactionFilterNotifier,
      TransactionFilterCriteria
    >(TransactionFilterNotifier.new);

class TransactionOperationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  void setLoading() {
    state = const AsyncLoading();
  }

  void setSuccess() {
    state = const AsyncData(null);
  }

  void setFailure(Object error, StackTrace stackTrace) {
    state = AsyncError(error, stackTrace);
  }
}

class TransactionFilterNotifier extends Notifier<TransactionFilterCriteria> {
  @override
  TransactionFilterCriteria build() {
    return const TransactionFilterCriteria();
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void setType(TransactionType? value) {
    state = state.copyWith(type: value, clearType: value == null);
  }

  void setCategoryId(String? value) {
    state = state.copyWith(categoryId: value, clearCategoryId: value == null);
  }

  void setAccountId(String? value) {
    state = state.copyWith(accountId: value, clearAccountId: value == null);
  }

  void setStartDate(DateTime? value) {
    state = state.copyWith(startDate: value, clearStartDate: value == null);
  }

  void setEndDate(DateTime? value) {
    state = state.copyWith(endDate: value, clearEndDate: value == null);
  }

  void setMinAmount(double? value) {
    state = state.copyWith(minAmount: value, clearMinAmount: value == null);
  }

  void setMaxAmount(double? value) {
    state = state.copyWith(maxAmount: value, clearMaxAmount: value == null);
  }

  void clear() {
    state = const TransactionFilterCriteria();
  }
}

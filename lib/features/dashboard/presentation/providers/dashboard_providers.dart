import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../application/usecases/build_dashboard_overview_use_case.dart';
import '../../domain/entities/dashboard_overview.dart';

final buildDashboardOverviewUseCaseProvider =
    Provider<BuildDashboardOverviewUseCase>((ref) {
      return const BuildDashboardOverviewUseCase();
    });

final dashboardOverviewProvider =
    Provider.family<AsyncValue<Result<DashboardOverview>>, String>((
      ref,
      userId,
    ) {
      final transactionsState = ref.watch(transactionListProvider(userId));
      final accountsState = ref.watch(accountListProvider(userId));
      final categoriesState = ref.watch(categoryListProvider(userId));
      final states = [transactionsState, accountsState, categoriesState];

      if (states.any((state) => state.isLoading)) {
        return const AsyncLoading();
      }

      for (final state in states) {
        if (state.hasError) {
          return AsyncError(
            state.error!,
            state.stackTrace ?? StackTrace.current,
          );
        }
      }

      final transactionsResult = transactionsState.value;
      final accountsResult = accountsState.value;
      final categoriesResult = categoriesState.value;
      if (transactionsResult == null ||
          accountsResult == null ||
          categoriesResult == null) {
        return const AsyncLoading();
      }

      final failure = _firstFailure([
        transactionsResult,
        accountsResult,
        categoriesResult,
      ]);
      if (failure != null) {
        return AsyncData(Failure(failure));
      }

      final overview = ref
          .watch(buildDashboardOverviewUseCaseProvider)
          .execute(
            accounts: (accountsResult as Success<List<Account>>).value,
            categories: (categoriesResult as Success<List<Category>>).value,
            transactions:
                (transactionsResult as Success<List<TransactionEntity>>).value,
            now: DateTime.now(),
          );

      return AsyncData(Success(overview));
    });

AppFailure? _firstFailure(List<Result<Object>> results) {
  for (final result in results) {
    if (result case Failure<Object>(:final failure)) {
      return failure;
    }
  }
  return null;
}

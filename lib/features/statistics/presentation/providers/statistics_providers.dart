import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../application/usecases/build_statistics_overview_use_case.dart';
import '../../domain/entities/statistics_overview.dart';

enum StatisticsPeriod { week, month, year, custom }

class StatisticsPeriodSelection {
  const StatisticsPeriodSelection({
    this.period = StatisticsPeriod.month,
    this.customRange,
  });

  final StatisticsPeriod period;
  final DateTimeRange? customRange;
}

class StatisticsPeriodNotifier extends Notifier<StatisticsPeriodSelection> {
  @override
  StatisticsPeriodSelection build() => const StatisticsPeriodSelection();

  void select(StatisticsPeriod period, {DateTimeRange? customRange}) {
    state = StatisticsPeriodSelection(period: period, customRange: customRange);
  }
}

final statisticsPeriodProvider =
    NotifierProvider.autoDispose<
      StatisticsPeriodNotifier,
      StatisticsPeriodSelection
    >(StatisticsPeriodNotifier.new);

final buildStatisticsOverviewUseCaseProvider =
    Provider<BuildStatisticsOverviewUseCase>((ref) {
      return const BuildStatisticsOverviewUseCase();
    });

final statisticsOverviewProvider =
    Provider.family<AsyncValue<Result<StatisticsOverview>>, String>((
      ref,
      userId,
    ) {
      final transactionsState = ref.watch(transactionListProvider(userId));
      final accountsState = ref.watch(accountListProvider(userId));
      final categoriesState = ref.watch(categoryListProvider(userId));
      final period = ref.watch(statisticsPeriodProvider);
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
          .watch(buildStatisticsOverviewUseCaseProvider)
          .execute(
            accounts: (accountsResult as Success<List<Account>>).value,
            categories: (categoriesResult as Success<List<Category>>).value,
            transactions: _filterByPeriod(
              (transactionsResult as Success<List<TransactionEntity>>).value,
              period,
              DateTime.now(),
            ),
            now: DateTime.now(),
          );

      return AsyncData(Success(overview));
    });

List<TransactionEntity> _filterByPeriod(
  List<TransactionEntity> transactions,
  StatisticsPeriodSelection selection,
  DateTime now,
) {
  final localNow = now.toLocal();
  final start = switch (selection.period) {
    StatisticsPeriod.week => DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
    ).subtract(const Duration(days: 6)),
    StatisticsPeriod.month => DateTime(localNow.year, localNow.month),
    StatisticsPeriod.year => DateTime(localNow.year),
    StatisticsPeriod.custom => selection.customRange?.start,
  };
  final end = selection.period == StatisticsPeriod.custom
      ? selection.customRange?.end.add(const Duration(days: 1))
      : null;
  if (start == null) {
    return transactions;
  }
  return transactions
      .where((transaction) {
        final date = transaction.transactionDate.toLocal();
        return !date.isBefore(start) && (end == null || date.isBefore(end));
      })
      .toList(growable: false);
}

AppFailure? _firstFailure(List<Result<Object>> results) {
  for (final result in results) {
    if (result case Failure<Object>(:final failure)) {
      return failure;
    }
  }
  return null;
}

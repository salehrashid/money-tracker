import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/financial_cycle/financial_cycle_service.dart';
import '../../../../core/financial_cycle/financial_period.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../settings/presentation/providers/financial_settings_providers.dart';
import '../../application/usecases/build_statistics_overview_use_case.dart';
import '../../domain/entities/statistics_overview.dart';

enum StatisticsPeriod { financialCycle, week, month, year, custom }

class StatisticsPeriodSelection {
  const StatisticsPeriodSelection({
    this.period = StatisticsPeriod.financialCycle,
    this.customRange,
    this.financialCycleOffset = 0,
  });

  final StatisticsPeriod period;
  final DateTimeRange? customRange;
  final int financialCycleOffset;
}

class StatisticsPeriodNotifier extends Notifier<StatisticsPeriodSelection> {
  @override
  StatisticsPeriodSelection build() => const StatisticsPeriodSelection();

  void select(
    StatisticsPeriod period, {
    DateTimeRange? customRange,
    int financialCycleOffset = 0,
  }) {
    state = StatisticsPeriodSelection(
      period: period,
      customRange: customRange,
      financialCycleOffset: financialCycleOffset,
    );
  }

  void navigateFinancialCycle(int delta) {
    if (state.period != StatisticsPeriod.financialCycle) return;
    final next = state.financialCycleOffset + delta;
    if (next <= 0) {
      state = StatisticsPeriodSelection(
        period: StatisticsPeriod.financialCycle,
        financialCycleOffset: next,
      );
    }
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
      final cycleDayState = ref.watch(financialCycleDayProvider(userId));
      final states = [transactionsState, accountsState, categoriesState];

      if (states.any((state) => state.isLoading)) {
        return const AsyncLoading();
      }
      if (cycleDayState.isLoading) return const AsyncLoading();

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
      final cycleDay = cycleDayState.value ?? 1;
      final now = DateTime.now();
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
              now,
              cycleDay,
            ),
            now: now,
            financialCycleDay: cycleDay,
            useFinancialCycles:
                period.period == StatisticsPeriod.financialCycle,
          );

      return AsyncData(Success(overview));
    });

List<TransactionEntity> _filterByPeriod(
  List<TransactionEntity> transactions,
  StatisticsPeriodSelection selection,
  DateTime now,
  int financialCycleDay,
) {
  final localNow = now.toLocal();
  final start = switch (selection.period) {
    StatisticsPeriod.financialCycle =>
      const FinancialCycleService()
          .periodByOffset(
            date: now,
            cycleDay: financialCycleDay,
            offset: selection.financialCycleOffset,
          )
          .start,
    StatisticsPeriod.week => DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
    ).subtract(const Duration(days: 6)),
    StatisticsPeriod.month => DateTime(localNow.year, localNow.month),
    StatisticsPeriod.year => DateTime(localNow.year),
    StatisticsPeriod.custom => selection.customRange?.start,
  };
  final end = switch (selection.period) {
    StatisticsPeriod.financialCycle =>
      const FinancialCycleService()
          .periodByOffset(
            date: now,
            cycleDay: financialCycleDay,
            offset: selection.financialCycleOffset,
          )
          .nextStart,
    StatisticsPeriod.custom => selection.customRange?.end.add(
      const Duration(days: 1),
    ),
    _ => null,
  };
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

class FinancialHistoryEntry {
  const FinancialHistoryEntry({
    required this.period,
    required this.income,
    required this.expense,
  });

  final FinancialPeriod period;
  final double income;
  final double expense;

  double get net => income - expense;
}

final financialHistoryProvider =
    Provider.family<List<FinancialHistoryEntry>, String>((ref, userId) {
      final transactions = ref.watch(transactionListProvider(userId)).value;
      final accounts = ref.watch(accountListProvider(userId)).value;
      final day = ref.watch(financialCycleDayProvider(userId)).value ?? 1;
      if (transactions == null || accounts == null) return const [];
      if (transactions case Failure<List<TransactionEntity>>()) {
        return const [];
      }
      if (accounts case Failure<List<Account>>()) return const [];
      final accountById = {
        for (final account in (accounts as Success<List<Account>>).value)
          account.id: account,
      };
      final active = (transactions as Success<List<TransactionEntity>>).value
          .where((item) => !item.isDeleted)
          .where((item) => accountById[item.accountId]?.isArchived != true);
      final service = const FinancialCycleService();
      final now = DateTime.now();
      return [
        for (var offset = 0; offset >= -5; offset--)
          _historyEntry(
            active,
            service.periodByOffset(date: now, cycleDay: day, offset: offset),
          ),
      ];
    });

FinancialHistoryEntry _historyEntry(
  Iterable<TransactionEntity> transactions,
  FinancialPeriod period,
) {
  var income = 0.0;
  var expense = 0.0;
  for (final transaction in transactions) {
    if (!period.contains(transaction.transactionDate)) continue;
    if (transaction.type == TransactionType.income) {
      income += transaction.amount;
    } else {
      expense += transaction.amount;
    }
  }
  return FinancialHistoryEntry(
    period: period,
    income: income,
    expense: expense,
  );
}

AppFailure? _firstFailure(List<Result<Object>> results) {
  for (final result in results) {
    if (result case Failure<Object>(:final failure)) {
      return failure;
    }
  }
  return null;
}

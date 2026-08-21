import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';

import '../../../../shared/models/finance_enums.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../transactions/presentation/widgets/transaction_formatters.dart';
import '../../domain/entities/statistics_overview.dart';
import '../providers/statistics_providers.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return AppScaffold(
      body: Column(
        children: [
          const AppPageHeader(
            title: 'Statistics',
            subtitle: 'Understand your financial habits.',
          ),
          Expanded(
            child: authState.when(
              loading: () => const _CenteredProgress(),
              error: (_, _) => const AppEmptyState(
                icon: Icons.error_outline,
                title: 'Unable to check sign-in status',
                description: 'Please restart the app and try again.',
              ),
              data: (result) => result.when(
                failure: (failure) => AppEmptyState(
                  icon: Icons.error_outline,
                  title: 'Unable to check sign-in status',
                  description: failure.message,
                ),
                success: (user) {
                  if (user == null) {
                    return const AppEmptyState(
                      icon: Icons.lock_outline,
                      title: 'Sign in required',
                      description: 'Sign in to view your statistics.',
                    );
                  }

                  return _StatisticsContent(userId: user.id);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsContent extends ConsumerWidget {
  const _StatisticsContent({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statisticsState = ref.watch(statisticsOverviewProvider(userId));

    return statisticsState.when(
      loading: () => const _CenteredProgress(),
      error: (_, _) => const AppEmptyState(
        icon: Icons.error_outline,
        title: 'Unable to load statistics',
        description: 'Please check your connection and try again.',
      ),
      data: (result) => result.when(
        failure: (failure) => AppEmptyState(
          icon: Icons.error_outline,
          title: 'Unable to load statistics',
          description: failure.message,
        ),
        success: (overview) {
          if (overview.isEmpty) {
            return const AppEmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'No statistics yet',
              description: 'Add income and expense transactions to see your analytics.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(statisticsOverviewProvider(userId));
            },
            child: _StatisticsBody(overview: overview),
          );
        },
      ),
    );
  }
}

class _StatisticsBody extends StatelessWidget {
  const _StatisticsBody({required this.overview});

  final StatisticsOverview overview;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryGrid(overview: overview, isWide: isWide),
                    const SizedBox(height: 16),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _MonthlyTrendCard(
                              trends: overview.monthlyTrends,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _SourceBreakdownCard(
                              items: overview.sourceBreakdown,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _MonthlyTrendCard(trends: overview.monthlyTrends),
                      const SizedBox(height: 16),
                      _SourceBreakdownCard(items: overview.sourceBreakdown),
                    ],
                    const SizedBox(height: 16),
                    _CategoryBreakdownCard(items: overview.categoryBreakdown),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.overview, required this.isWide});

  final StatisticsOverview overview;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard(
        title: 'Total income',
        value: formatIdr(overview.totalIncome),
        icon: Icons.trending_up,
        tone: _SummaryTone.positive,
      ),
      _SummaryCard(
        title: 'Total expense',
        value: formatIdr(overview.totalExpense),
        icon: Icons.trending_down,
        tone: _SummaryTone.negative,
      ),
      _SummaryCard(
        title: 'Net cash flow',
        value: formatIdr(overview.netCashFlow),
        icon: Icons.swap_vert,
        tone: overview.netCashFlow >= 0
            ? _SummaryTone.positive
            : _SummaryTone.negative,
      ),
      _SummaryCard(
        title: 'Monthly average',
        value:
            '${formatIdr(overview.averageMonthlyIncome)} / ${formatIdr(overview.averageMonthlyExpense)}',
        icon: Icons.calendar_month_outlined,
      ),
    ];

    return GridView.count(
      crossAxisCount: isWide ? 4 : 2,
      childAspectRatio: isWide ? 1.65 : 1.18,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.tone = _SummaryTone.neutral,
  });

  final String title;
  final String value;
  final IconData icon;
  final _SummaryTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _SummaryTone.positive => AppColors.income,
      _SummaryTone.negative => AppColors.expense,
      _SummaryTone.neutral => AppColors.primary,
    };
    final bgColor = switch (tone) {
      _SummaryTone.positive => AppColors.incomeLight,
      _SummaryTone.negative => AppColors.expenseLight,
      _SummaryTone.neutral => AppColors.primaryLight,
    };

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: bgColor,
                foregroundColor: color,
                radius: 18,
                child: Icon(icon, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const Spacer(),
          Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyTrendCard extends StatelessWidget {
  const _MonthlyTrendCard({required this.trends});

  final List<StatisticsMonthlyTrend> trends;

  @override
  Widget build(BuildContext context) {
    final maxAmount = trends.fold<double>(
      0,
      (value, trend) =>
          [value, trend.income, trend.expense].reduce((a, b) => a > b ? a : b),
    );

    return _SectionCard(
      title: 'Monthly trends',
      child: trends.every((trend) => trend.income == 0 && trend.expense == 0)
          ? const _InlineEmptyState(
              icon: Icons.show_chart,
              message: 'No transactions in the last six months.',
            )
          : Column(
              children: trends
                  .map(
                    (trend) =>
                        _MonthlyTrendRow(trend: trend, maxAmount: maxAmount),
                  )
                  .toList(),
            ),
    );
  }
}

class _MonthlyTrendRow extends StatelessWidget {
  const _MonthlyTrendRow({required this.trend, required this.maxAmount});

  final StatisticsMonthlyTrend trend;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _monthLabel(trend.month, trend.year),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                formatIdr(trend.netCashFlow),
                style: TextStyle(
                  color: trend.netCashFlow >= 0
                      ? Colors.teal
                      : colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TrendBar(
            label: 'Income',
            value: trend.income,
            maxAmount: maxAmount,
            color: Colors.teal,
          ),
          const SizedBox(height: 6),
          _TrendBar(
            label: 'Expense',
            value: trend.expense,
            maxAmount: maxAmount,
            color: colorScheme.error,
          ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.label,
    required this.value,
    required this.maxAmount,
    required this.color,
  });

  final String label;
  final double value;
  final double maxAmount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = maxAmount == 0 ? 0.0 : value / maxAmount;

    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.clamp(0, 1),
              color: color,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(
            formatIdr(value),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _SourceBreakdownCard extends StatelessWidget {
  const _SourceBreakdownCard({required this.items});

  final List<StatisticsSourceBreakdown> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Transaction sources',
      child: items.isEmpty
          ? const _InlineEmptyState(
              icon: Icons.hub_outlined,
              message: 'No source activity yet.',
            )
          : Column(
              children: items
                  .map(
                    (item) => _ShareBar(
                      title: transactionSourceLabel(item.source),
                      subtitle: '${item.transactionCount} transactions',
                      amount: item.amount,
                      share: item.share,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.items});

  final List<StatisticsCategoryBreakdown> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Category distribution',
      child: items.isEmpty
          ? const _InlineEmptyState(
              icon: Icons.pie_chart_outline,
              message: 'No category activity yet.',
            )
          : Column(
              children: items
                  .take(10)
                  .map(
                    (item) => _ShareBar(
                      title: item.categoryName,
                      subtitle:
                          '${transactionTypeLabel(item.type)} - ${item.transactionCount} transactions',
                      amount: item.amount,
                      share: item.share,
                      tone: item.type == TransactionType.income
                          ? _SummaryTone.positive
                          : _SummaryTone.negative,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.share,
    this.tone = _SummaryTone.neutral,
  });

  final String title;
  final String subtitle;
  final double amount;
  final double share;
  final _SummaryTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      _SummaryTone.positive => Colors.teal,
      _SummaryTone.negative => colorScheme.error,
      _SummaryTone.neutral => colorScheme.primary,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(formatIdr(amount)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: share.clamp(0, 1),
              color: color,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}



class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

enum _SummaryTone { positive, negative, neutral }

String _monthLabel(int month, int year) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${names[month - 1]} $year';
}

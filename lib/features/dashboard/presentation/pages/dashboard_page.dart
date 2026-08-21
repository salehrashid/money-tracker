import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/finance_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/dashboard_overview.dart';
import '../providers/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key, this.onAddTransaction});

  final VoidCallback? onAddTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return AppScaffold(
      body: Column(
        children: [
          const AppPageHeader(
            title: 'Dashboard',
            subtitle: 'Your financial overview',
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
                      description: 'Sign in to view your dashboard.',
                    );
                  }

                  return _DashboardContent(
                    userId: user.id,
                    onAddTransaction: onAddTransaction,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({
    required this.userId,
    this.onAddTransaction,
  });

  final String userId;
  final VoidCallback? onAddTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewState = ref.watch(dashboardOverviewProvider(userId));

    return overviewState.when(
      loading: () => const _CenteredProgress(),
      error: (_, _) => const AppEmptyState(
        icon: Icons.error_outline,
        title: 'Unable to load dashboard',
        description: 'Please check your connection and try again.',
      ),
      data: (result) => result.when(
        failure: (failure) => AppEmptyState(
          icon: Icons.error_outline,
          title: 'Unable to load dashboard',
          description: failure.message,
        ),
        success: (overview) {
          if (overview.isEmpty) {
            return AppEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No transactions yet',
              description: 'Add your first income or expense transaction to start tracking your finances.',
              actionLabel: 'Add Transaction',
              onAction: onAddTransaction,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardOverviewProvider(userId));
            },
            child: _DashboardBody(overview: overview),
          );
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.overview});

  final DashboardOverview overview;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 840;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryGrid(overview: overview, isWide: isWide),
                const SizedBox(height: 24),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ExpenseBreakdownCard(
                          items: overview.expenseBreakdown,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _RecentTransactionsCard(
                          transactions: overview.recentTransactions,
                        ),
                      ),
                    ],
                  )
                else ...[
                  _ExpenseBreakdownCard(items: overview.expenseBreakdown),
                  const SizedBox(height: 24),
                  _RecentTransactionsCard(
                    transactions: overview.recentTransactions,
                  ),
                ],
                const SizedBox(height: 48), // Bottom padding
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.overview, required this.isWide});

  final DashboardOverview overview;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard(
        title: 'Total Balance',
        value: _formatIdr(overview.totalBalance),
        icon: Icons.account_balance_wallet,
        tone: _SummaryTone.neutral,
      ),
      _SummaryCard(
        title: 'Income',
        value: _formatIdr(overview.monthlyIncome),
        icon: Icons.arrow_downward,
        tone: _SummaryTone.positive,
      ),
      _SummaryCard(
        title: 'Expense',
        value: _formatIdr(overview.monthlyExpense),
        icon: Icons.arrow_upward,
        tone: _SummaryTone.negative,
      ),
      _SummaryCard(
        title: 'Cash Flow',
        value: _formatIdr(overview.netCashFlow),
        icon: Icons.swap_vert,
        tone: overview.netCashFlow >= 0
            ? _SummaryTone.positive
            : _SummaryTone.negative,
      ),
    ];

    return GridView.count(
      crossAxisCount: isWide ? 4 : 2,
      childAspectRatio: isWide ? 1.4 : 1.3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
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

class _ExpenseBreakdownCard extends StatelessWidget {
  const _ExpenseBreakdownCard({required this.items});

  final List<DashboardExpenseBreakdown> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly expense by category',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No expenses recorded this month.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...items.map((item) => _ExpenseBar(item: item)),
        ],
      ),
    );
  }
}

class _ExpenseBar extends StatelessWidget {
  const _ExpenseBar({required this.item});

  final DashboardExpenseBreakdown item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatIdr(item.amount),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: item.share.clamp(0, 1),
                    backgroundColor: AppColors.divider,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.expense),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                child: Text(
                  '${(item.share * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({required this.transactions});

  final List<DashboardRecentTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent transactions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () {
                  // This should theoretically change tab to transactions
                },
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No transactions recorded yet.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...transactions.map(
              (transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RecentTransactionTile(transaction: transaction),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({required this.transaction});

  final DashboardRecentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;
    final bgColor = isIncome ? AppColors.incomeLight : AppColors.expenseLight;
    final amountPrefix = isIncome ? '+' : '';

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: bgColor,
          foregroundColor: color,
          radius: 20,
          child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [transaction.categoryName, transaction.accountName].where((e) => e.isNotEmpty).join(' • '),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(transaction.transactionDate),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$amountPrefix${_formatIdr(transaction.amount)}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Manual', // Mocking source badge for now
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
              ),
            ),
          ],
        ),
      ],
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

enum _SummaryTone { neutral, positive, negative }

String _formatIdr(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < amount.length; index++) {
    if (index > 0 && (amount.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(amount[index]);
  }

  return '${sign}Rp${buffer.toString()}';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/${local.year}';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

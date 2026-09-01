import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/finance_enums.dart';
import '../../../../core/financial_cycle/financial_period.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notification_reader/presentation/pages/mybca_notifications_page.dart';
import '../../../notification_reader/presentation/providers/notification_listener_providers.dart';
import '../../domain/entities/dashboard_overview.dart';
import '../providers/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key, this.onAddTransaction});

  /// Optional callback invoked when the user taps 'Add Transaction' from the
  /// empty state. Typically used by the parent shell to switch to the
  /// Transactions tab.
  final VoidCallback? onAddTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    final unreadCount = authState.maybeWhen(
      data: (result) => result.when(
        success: (user) => user == null
            ? 0
            : ref.watch(unreadNotificationCountProvider(user.id)),
        failure: (_) => 0,
      ),
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppTopBar(
        title: 'Dashboard',
        subtitle: 'Your financial overview',
        actions: [_NotificationBell(unreadCount: unreadCount)],
      ),
      body: authState.when(
        loading: () => const _CenteredProgress(),
        error: (_, _) => const _MessageState(
          icon: Icons.error_outline,
          title: 'Unable to check sign-in status',
          message: 'Please restart the app and try again.',
        ),
        data: (result) => result.when(
          failure: (failure) => _MessageState(
            icon: Icons.error_outline,
            title: 'Unable to check sign-in status',
            message: failure.message,
          ),
          success: (user) {
            if (user == null) {
              return const _MessageState(
                icon: Icons.lock_outline,
                title: 'Sign in required',
                message: 'Sign in to view your dashboard.',
              );
            }

            return _DashboardContent(
              userId: user.id,
              onAddTransaction: onAddTransaction,
            );
          },
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final label = unreadCount > 99 ? '99+' : unreadCount.toString();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(label),
        child: IconButton(
          tooltip: 'MyBCA notifications',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MyBcaNotificationsPage(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.userId, this.onAddTransaction});

  final String userId;
  final VoidCallback? onAddTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewState = ref.watch(dashboardOverviewProvider(userId));

    return overviewState.when(
      loading: () => const _CenteredProgress(),
      error: (_, _) => const _MessageState(
        icon: Icons.error_outline,
        title: 'Unable to load dashboard',
        message: 'Please check your connection and try again.',
      ),
      data: (result) => result.when(
        failure: (failure) => _MessageState(
          icon: Icons.error_outline,
          title: 'Unable to load dashboard',
          message: failure.message,
        ),
        success: (overview) {
          if (overview.isEmpty) {
            return _NoTransactionsState(onAddTransaction: onAddTransaction);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardOverviewProvider(userId));
            },
            child: _DashboardBody(
              overview: overview,
              onViewTransactions: onAddTransaction,
            ),
          );
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.overview,
    required this.onViewTransactions,
  });

  final DashboardOverview overview;
  final VoidCallback? onViewTransactions;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 840;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryGrid(overview: overview, isWide: isWide),
                    if (overview.period != null) ...[
                      const SizedBox(height: 12),
                      _CurrentPeriodBanner(period: overview.period!),
                    ],
                    const SizedBox(height: 16),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ExpenseBreakdownCard(
                              items: overview.expenseBreakdown,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _RecentTransactionsCard(
                              transactions: overview.recentTransactions,
                              onViewAll: onViewTransactions,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _ExpenseBreakdownCard(items: overview.expenseBreakdown),
                      const SizedBox(height: 16),
                      _RecentTransactionsCard(
                        transactions: overview.recentTransactions,
                        onViewAll: onViewTransactions,
                      ),
                    ],
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

  final DashboardOverview overview;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard(
        title: 'Total balance',
        value: _formatIdr(overview.totalBalance),
        icon: Icons.account_balance_wallet_outlined,
      ),
      _SummaryCard(
        title: 'Monthly income',
        value: _formatIdr(overview.monthlyIncome),
        icon: Icons.trending_up,
        tone: _SummaryTone.positive,
      ),
      _SummaryCard(
        title: 'Monthly expense',
        value: _formatIdr(overview.monthlyExpense),
        icon: Icons.trending_down,
        tone: _SummaryTone.negative,
      ),
      _SummaryCard(
        title: 'Net cash flow',
        value: _formatIdr(overview.netCashFlow),
        icon: Icons.swap_vert,
        tone: overview.netCashFlow >= 0
            ? _SummaryTone.positive
            : _SummaryTone.negative,
      ),
    ];

    return GridView.count(
      crossAxisCount: isWide ? 4 : 2,
      childAspectRatio: isWide ? 1.55 : 1.22,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }
}

class _CurrentPeriodBanner extends StatelessWidget {
  const _CurrentPeriodBanner({required this.period});

  final FinancialPeriod period;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.calendar_month_outlined),
        title: const Text('Current financial period'),
        subtitle: Text(_formatPeriod(period)),
      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      _SummaryTone.positive => AppColors.income,
      _SummaryTone.negative => colorScheme.error,
      _SummaryTone.neutral => colorScheme.primary,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseBreakdownCard extends StatelessWidget {
  const _ExpenseBreakdownCard({required this.items});

  final List<DashboardExpenseBreakdown> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly expense by category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const _InlineEmptyState(
                icon: Icons.pie_chart_outline,
                message: 'No expenses recorded this month.',
              )
            else
              ...items.map((item) => _ExpenseBar(item: item)),
          ],
        ),
      ),
    );
  }
}

class _ExpenseBar extends StatelessWidget {
  const _ExpenseBar({required this.item});

  final DashboardExpenseBreakdown item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(_formatIdr(item.amount)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: item.share.clamp(0, 1),
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({
    required this.transactions,
    required this.onViewAll,
  });

  final List<DashboardRecentTransaction> transactions;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent transactions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(onPressed: onViewAll, child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 8),
            if (transactions.isEmpty)
              const _InlineEmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'No transactions recorded yet.',
              )
            else
              ...transactions.map(
                (transaction) =>
                    _RecentTransactionTile(transaction: transaction),
              ),
          ],
        ),
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
    final color = isIncome
        ? AppColors.income
        : Theme.of(context).colorScheme.error;
    final amountPrefix = isIncome ? '+' : '-';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        foregroundColor: color,
        child: Icon(isIncome ? Icons.add : Icons.remove),
      ),
      title: Text(
        '$amountPrefix${_formatIdr(transaction.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          transaction.categoryName,
          transaction.accountName,
          _formatDate(transaction.transactionDate),
          ?transaction.note.isNotEmpty ? transaction.note : null,
        ].join(' - '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Onboarding empty state shown when the user has a default Cash account but
/// no transactions yet.
class _NoTransactionsState extends StatelessWidget {
  const _NoTransactionsState({this.onAddTransaction});

  final VoidCallback? onAddTransaction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No transactions yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first income or expense transaction to start tracking your finances.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddTransaction,
              icon: const Icon(Icons.add),
              label: const Text('Add Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress();

  @override
  Widget build(BuildContext context) {
    return const AppLoadingState();
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

String _formatPeriod(FinancialPeriod period) {
  return '${_shortDate(period.start)} - ${_shortDate(period.end)}';
}

String _shortDate(DateTime value) {
  const months = [
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
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

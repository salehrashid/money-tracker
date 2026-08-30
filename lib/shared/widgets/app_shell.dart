import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/pages/account_page.dart';
import '../../features/categories/presentation/pages/category_management_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/debt_loan/presentation/pages/debt_loan_page.dart';
import '../../features/notification_reader/presentation/providers/notification_listener_providers.dart';
import '../../features/statistics/presentation/pages/statistics_page.dart';
import '../../features/transactions/presentation/pages/transaction_page.dart';
import '../theme/app_theme.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _accountIndex = 5;
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationDetectionControllerProvider);
    final pendingDetectedTransaction = ref.watch(
      pendingDetectedTransactionProvider,
    );

    ref.listen(pendingDetectedTransactionProvider, (previous, next) {
      if (next != null && _selectedIndex != 1) {
        setState(() => _selectedIndex = 1);
      }
    });

    final page = switch (_selectedIndex) {
      0 => DashboardPage(onAddTransaction: () => _select(1)),
      1 => TransactionPage(
        initialDetectedTransaction: pendingDetectedTransaction,
      ),
      2 => const StatisticsPage(),
      3 => const DebtLoanPage(),
      4 => const CategoryManagementPage(),
      _accountIndex => const AccountPage(),
      _ => DashboardPage(onAddTransaction: () => _select(1)),
    };

    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.desktop) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopSidebar(
              selectedIndex: _selectedIndex,
              extended: width >= 1240,
              onSelected: _select,
              onAccountSelected: () => _select(_accountIndex),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      );
    }

    return Scaffold(
      body: page,
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          height: 72,
          labelBehavior:
              width < 380 || MediaQuery.textScalerOf(context).scale(14) > 16
              ? NavigationDestinationLabelBehavior.onlyShowSelected
              : NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _selectedIndex < 5 ? _selectedIndex : 0,
          onDestinationSelected: _select,
          destinations: _destinations
              .map(
                (item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                  tooltip: item.tooltip,
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  void _select(int index) => setState(() => _selectedIndex = index);
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
    required this.onAccountSelected,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;
  final VoidCallback onAccountSelected;

  @override
  Widget build(BuildContext context) {
    final width = extended ? 240.0 : 88.0;
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            children: [
              _Brand(extended: extended),
              const SizedBox(height: AppSpacing.xl),
              for (var index = 0; index < _destinations.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _SidebarDestination(
                    item: _destinations[index],
                    selected: selectedIndex == index,
                    extended: extended,
                    onTap: () => onSelected(index),
                  ),
                ),
              const Spacer(),
              const Divider(),
              const SizedBox(height: AppSpacing.xs),
              _SidebarDestination(
                item: const _Destination(
                  label: 'Account',
                  tooltip: 'Account and settings',
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                ),
                selected: selectedIndex == 5,
                extended: extended,
                onTap: onAccountSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Fleeca money management',
      child: Row(
        mainAxisAlignment: extended
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Image.asset('app-icon.png', fit: BoxFit.contain),
          ),
          if (extended) ...[
            const SizedBox(width: AppSpacing.sm),
            Text('Fleeca', style: Theme.of(context).textTheme.titleLarge),
          ],
        ],
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final _Destination item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.primaryDark
        : AppColors.textSecondary;
    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      hoverColor: AppColors.surfaceVariant,
      focusColor: AppColors.primaryLight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 0),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Row(
          mainAxisAlignment: extended
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Icon(selected ? item.selectedIcon : item.icon, color: foreground),
            if (extended) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Tooltip(message: item.tooltip, child: child);
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String tooltip;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination(
    label: 'Dashboard',
    tooltip: 'Financial overview',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
  ),
  _Destination(
    label: 'Transactions',
    tooltip: 'Income and expenses',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
  _Destination(
    label: 'Statistics',
    tooltip: 'Financial analytics',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart_rounded,
  ),
  _Destination(
    label: 'Debt',
    tooltip: 'Debt and receivables',
    icon: Icons.handshake_outlined,
    selectedIcon: Icons.handshake_rounded,
  ),
  _Destination(
    label: 'Categories',
    tooltip: 'Income and expense categories',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category_rounded,
  ),
];

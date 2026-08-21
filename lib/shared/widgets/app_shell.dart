import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/pages/account_page.dart';
import '../../features/categories/presentation/pages/category_management_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/debt_loan/presentation/pages/debt_loan_page.dart';
import '../../features/notification_reader/presentation/pages/notification_debug_page.dart';
import '../../features/notification_reader/presentation/providers/notification_listener_providers.dart';
import '../../features/statistics/presentation/pages/statistics_page.dart';
import '../../features/transactions/presentation/pages/transaction_page.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  var _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

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

    final isWide = MediaQuery.sizeOf(context).width >= 720;
    
    // Auto-collapse sidebar on smaller desktop windows
    if (isWide && MediaQuery.sizeOf(context).width < 900) {
      _isSidebarCollapsed = true;
    } else if (isWide && MediaQuery.sizeOf(context).width >= 900) {
      _isSidebarCollapsed = false;
    }

    final page = switch (_selectedIndex) {
      0 => DashboardPage(
        onAddTransaction: () => setState(() => _selectedIndex = 1),
      ),
      1 => TransactionPage(
        initialDetectedTransaction: pendingDetectedTransaction,
      ),
      2 => const StatisticsPage(),
      3 => const DebtLoanPage(),
      4 => const CategoryManagementPage(),
      5 when kDebugMode => const NotificationDebugPage(),
      6 => const AccountPage(),
      _ => DashboardPage(
        onAddTransaction: () => setState(() => _selectedIndex = 1),
      ),
    };

    final destinations = [
      const _NavDestination('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
      const _NavDestination('Transactions', Icons.receipt_long_outlined, Icons.receipt_long),
      const _NavDestination('Statistics', Icons.bar_chart_outlined, Icons.bar_chart),
      const _NavDestination('Debt', Icons.handshake_outlined, Icons.handshake),
      const _NavDestination('Categories', Icons.category_outlined, Icons.category),
    ];

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            Material(
              color: AppColors.surface,
              elevation: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isSidebarCollapsed ? 80 : 250,
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    if (_isSidebarCollapsed)
                      const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 32)
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 32),
                            const SizedBox(width: 12),
                            Text('Fleeca', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: ListView.builder(
                        itemCount: destinations.length,
                        itemBuilder: (context, index) {
                          final dest = destinations[index];
                          final isSelected = _selectedIndex == index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => _selectedIndex = index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: isSelected ? AppColors.primaryLight : Colors.transparent,
                                ),
                                child: _isSidebarCollapsed
                                    ? Tooltip(
                                        message: dest.label,
                                        child: Icon(isSelected ? dest.selectedIcon : dest.icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                                      )
                                    : Row(
                                        children: [
                                          const SizedBox(width: 16),
                                          Icon(isSelected ? dest.selectedIcon : dest.icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                                          const SizedBox(width: 16),
                                          Text(
                                            dest.label,
                                            style: TextStyle(
                                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                        onPressed: () {}, // Settings placeholder
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: page),
          ],
        ),
      );
    }

    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: destinations.map((d) {
          return NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          );
        }).toList(),
      ),
    );
  }
}

class _NavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _NavDestination(this.label, this.icon, this.selectedIcon);
}

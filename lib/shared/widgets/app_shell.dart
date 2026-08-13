import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      // 5 => const CsvImportPage(),
      5 when kDebugMode => const NotificationDebugPage(),
      6 => const AccountPage(),
      _ => DashboardPage(
        onAddTransaction: () => setState(() => _selectedIndex = 1),
      ),
    };

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              labelType: NavigationRailLabelType.all,
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: Text('Transactions'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('Statistics'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.handshake_outlined),
                  selectedIcon: Icon(Icons.handshake),
                  label: Text('Debt'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category),
                  label: Text('Categories'),
                ),
                // if (kDebugMode)
                //   const NavigationRailDestination(
                //     icon: Icon(Icons.bug_report_outlined),
                //     selectedIcon: Icon(Icons.bug_report),
                //     label: Text('Notify Debug'),
                //   ),
                // NavigationRailDestination(
                //   icon: Icon(Icons.upload_file_outlined),
                //   selectedIcon: Icon(Icons.upload_file),
                //   label: Text('Import CSV'),
                // ),
                // NavigationRailDestination(
                //   icon: Icon(Icons.account_circle_outlined),
                //   selectedIcon: Icon(Icons.account_circle),
                //   label: Text('Account'),
                // ),
              ],
            ),
            const VerticalDivider(width: 1),
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
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistics',
          ),
          const NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake),
            label: 'Debt',
          ),
          const NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categories',
          ),
          // if (kDebugMode)
          //   const NavigationDestination(
          //     icon: Icon(Icons.bug_report_outlined),
          //     selectedIcon: Icon(Icons.bug_report),
          //     label: 'Notify Debug',
          //   ),
          // NavigationDestination(
          //   icon: Icon(Icons.upload_file_outlined),
          //   selectedIcon: Icon(Icons.upload_file),
          //   label: 'Import CSV',
          // ),
          // NavigationDestination(
          //   icon: Icon(Icons.account_circle_outlined),
          //   selectedIcon: Icon(Icons.account_circle),
          //   label: 'Account',
          // ),
        ],
      ),
    );
  }
}

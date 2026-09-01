import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';

import '../../features/auth/presentation/pages/account_page.dart';
import '../../features/categories/presentation/pages/category_management_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/debt_loan/presentation/pages/debt_loan_page.dart';
import '../../features/notification_reader/presentation/providers/notification_listener_providers.dart';
import '../../features/settings/presentation/pages/financial_cycle_page.dart';
import '../../features/statistics/presentation/pages/statistics_page.dart';
import '../../features/transactions/presentation/pages/transaction_page.dart';
import 'app_page.dart';
import '../theme/app_theme.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _accountIndex = 5;
  static const _financialCycleIndex = 6;
  late final PageController _pageController;
  final _mobileScaffoldKey = GlobalKey<ScaffoldState>();
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationDetectionControllerProvider);
    final pendingDetectedTransaction = ref.watch(
      pendingDetectedTransactionProvider,
    );

    ref.listen(pendingDetectedTransactionProvider, (previous, next) {
      if (next != null && _selectedIndex != 1) {
        _select(1);
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
      _financialCycleIndex => const FinancialCyclePage(),
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
              onFinancialCycleSelected: () => _select(_financialCycleIndex),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      );
    }

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedIndex != 0) {
          _select(0);
        }
      },
      child: Scaffold(
        key: _mobileScaffoldKey,
        drawerEnableOpenDragGesture: true,
        drawer: _MobileNavigationDrawer(
          onAccountSelected: () => _openAccountPage(context),
          onFinancialCycleSelected: () => _openFinancialCyclePage(context),
        ),
        body: AppDrawerScope(
          openDrawer: () => _mobileScaffoldKey.currentState?.openDrawer(),
          goToDashboard: () => _select(0),
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _KeepAlivePage(
                    child: DashboardPage(onAddTransaction: () => _select(1)),
                  ),
                  _KeepAlivePage(
                    child: TransactionPage(
                      initialDetectedTransaction: pendingDetectedTransaction,
                    ),
                  ),
                  const _KeepAlivePage(child: StatisticsPage()),
                  const _KeepAlivePage(child: DebtLoanPage()),
                  const _KeepAlivePage(child: CategoryManagementPage()),
                ],
              ),
              Positioned(
                left: 0,
                top: 88,
                bottom: 0,
                width: 28,
                child: _DrawerEdgeSwipeRegion(onOpenDrawer: _openDrawer),
              ),
              Positioned(
                right: 0,
                top: 88,
                bottom: 0,
                width: 28,
                child: _DrawerEdgeSwipeRegion(onOpenDrawer: _openDrawer),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _selectedIndex >= _accountIndex
            ? null
            : SafeArea(
                top: false,
                child: CurvedNavigationBar(
                  index: _selectedIndex,
                  height: 70,
                  color: AppColors.primaryDark,
                  buttonBackgroundColor: AppColors.primary,
                  backgroundColor: AppColors.background,
                  animationCurve: Curves.easeOutCubic,
                  animationDuration: Duration(milliseconds: 500),
                  onTap: _select,
                  items: [
                    for (var index = 0; index < _destinations.length; index++)
                      CurvedNavigationBarItem(
                        child: Tooltip(
                          message: _destinations[index].tooltip,
                          child: Icon(
                            _selectedIndex == index
                                ? _destinations[index].selectedIcon
                                : _destinations[index].icon,
                            size: 25,
                            color: Colors.white,
                          ),
                        ),
                        label: _destinations[index].label,
                        labelStyle: TextStyle(
                          color: _selectedIndex == index
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 12,
                          fontWeight: _selectedIndex == index
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  void _openAccountPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountPage(
          onBackToDashboard: () {
            Navigator.of(context).pop();
            _select(0);
          },
        ),
      ),
    );
  }

  void _openDrawer() {
    _mobileScaffoldKey.currentState?.openDrawer();
  }

  void _openFinancialCyclePage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FinancialCyclePage(
          onBackToDashboard: () {
            Navigator.of(context).pop();
            _select(0);
          },
        ),
      ),
    );
  }

  void _select(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() => _selectedIndex = index);

    if (index <= _financialCycleIndex && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onPageChanged(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }
}

class _DrawerEdgeSwipeRegion extends StatefulWidget {
  const _DrawerEdgeSwipeRegion({required this.onOpenDrawer});

  final VoidCallback onOpenDrawer;

  @override
  State<_DrawerEdgeSwipeRegion> createState() => _DrawerEdgeSwipeRegionState();
}

class _DrawerEdgeSwipeRegionState extends State<_DrawerEdgeSwipeRegion> {
  double _distance = 0;
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _distance = 0;
        _opened = false;
      },
      onHorizontalDragUpdate: (details) {
        if (_opened || details.delta.dx == 0) return;
        _distance += details.delta.dx.abs();
        if (_distance >= 12) {
          _opened = true;
          widget.onOpenDrawer();
        }
      },
      onHorizontalDragEnd: (_) {
        _distance = 0;
        _opened = false;
      },
      onHorizontalDragCancel: () {
        _distance = 0;
        _opened = false;
      },
      child: const SizedBox.expand(),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
    required this.onAccountSelected,
    required this.onFinancialCycleSelected,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;
  final VoidCallback onAccountSelected;
  final VoidCallback onFinancialCycleSelected;

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
                item: _accountDestination,
                selected: selectedIndex == 5,
                extended: extended,
                onTap: onAccountSelected,
              ),
              const SizedBox(height: AppSpacing.xs),
              _SidebarDestination(
                item: _financialCycleDestination,
                selected: selectedIndex == 6,
                extended: extended,
                onTap: onFinancialCycleSelected,
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

const _accountDestination = _Destination(
  label: 'Account',
  tooltip: 'Account',
  icon: Icons.settings_outlined,
  selectedIcon: Icons.settings,
);

const _financialCycleDestination = _Destination(
  label: 'Financial Cycle',
  tooltip: 'Financial Cycle',
  icon: Icons.payments_outlined,
  selectedIcon: Icons.payments,
);

class _MobileNavigationDrawer extends StatelessWidget {
  const _MobileNavigationDrawer({
    required this.onAccountSelected,
    required this.onFinancialCycleSelected,
  });

  final VoidCallback onAccountSelected;
  final VoidCallback onFinancialCycleSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Text(
                'Fleeca',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(_accountDestination.icon),
              title: const Text('Account'),
              subtitle: const Text('Profile'),
              onTap: () {
                Navigator.of(context).pop();
                onAccountSelected();
              },
            ),
            ListTile(
              leading: Icon(_financialCycleDestination.icon),
              title: const Text('Financial Cycle'),
              subtitle: const Text('Payday-based financial periods'),
              onTap: () {
                Navigator.of(context).pop();
                onFinancialCycleSelected();
              },
            ),
          ],
        ),
      ),
    );
  }
}

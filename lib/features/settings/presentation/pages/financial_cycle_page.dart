import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/financial_cycle/financial_cycle_service.dart';
import '../../../../core/financial_cycle/financial_period.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/financial_settings_providers.dart';

class FinancialCyclePage extends ConsumerWidget {
  const FinancialCyclePage({this.onBackToDashboard, super.key});

  final VoidCallback? onBackToDashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return PopScope(
      canPop: onBackToDashboard == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBackToDashboard?.call();
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: 'Financial Cycle',
          subtitle: 'Configure your monthly financial period',
          showBackButton: onBackToDashboard != null,
          onBackPressed: onBackToDashboard,
        ),
        body: authState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _MessageState(
            icon: Icons.error_outline,
            title: 'Unable to load financial cycle',
            message: 'Please restart the app and try again.',
          ),
          data: (result) => result.when(
            failure: (failure) => _MessageState(
              icon: Icons.error_outline,
              title: 'Unable to load financial cycle',
              message: failure.message,
            ),
            success: (user) => user == null
                ? const _MessageState(
                    icon: Icons.lock_outline,
                    title: 'Signed out',
                    message: 'Sign in to configure your financial cycle.',
                  )
                : _FinancialCycleContent(userId: user.id),
          ),
        ),
      ),
    );
  }
}

class _FinancialCycleContent extends ConsumerStatefulWidget {
  const _FinancialCycleContent({required this.userId});

  final String userId;

  @override
  ConsumerState<_FinancialCycleContent> createState() =>
      _FinancialCycleContentState();
}

class _FinancialCycleContentState
    extends ConsumerState<_FinancialCycleContent> {
  var _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(financialCycleDayProvider(widget.userId)).value ?? 1;
    final period = const FinancialCycleService().currentPeriod(cycleDay: day);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'How financial cycles work',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Choose the day your monthly financial period starts. '
                    'For example, day 10 creates periods from the 10th '
                    'through the 9th of the following month. Dashboard, '
                    'Statistics, and History use these periods for summaries.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Your transaction data is not changed. If a month has '
                    'fewer days than your chosen day, the last day of that '
                    'month is used.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Financial Cycle Day',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      DropdownButton<int>(
                        value: day,
                        onChanged: _isSaving ? null : _save,
                        items: [
                          for (var value = 1; value <= 31; value++)
                            DropdownMenuItem(
                              value: value,
                              child: Text('$value'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Your monthly financial period starts on day $day.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Current period: ${_formatPeriod(period)}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  if (_isSaving) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(int? value) async {
    if (value == null) return;
    setState(() => _isSaving = true);
    final result = await ref.read(saveFinancialSettingsProvider(widget.userId))(
      value,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result case Failure(:final failure)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

String _formatPeriod(FinancialPeriod period) {
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
  String date(DateTime value) =>
      '${value.day} ${months[value.month - 1]} ${value.year}';
  return '${date(period.start)} - ${date(period.end)}';
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
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

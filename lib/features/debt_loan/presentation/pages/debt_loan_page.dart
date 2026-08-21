import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../application/usecases/debt_commands.dart';
import '../../domain/entities/debt.dart';
import '../providers/debt_providers.dart';
import '../widgets/debt_form_dialog.dart';
import '../widgets/debt_formatters.dart';

final _debtKindFilterProvider =
    NotifierProvider.autoDispose<_DebtKindFilterNotifier, DebtKind?>(
      _DebtKindFilterNotifier.new,
    );

final _debtStatusFilterProvider =
    NotifierProvider.autoDispose<_DebtStatusFilterNotifier, DebtStatus?>(
      _DebtStatusFilterNotifier.new,
    );

class _DebtKindFilterNotifier extends Notifier<DebtKind?> {
  @override
  DebtKind? build() {
    return null;
  }

  void set(DebtKind? value) {
    state = value;
  }
}

class _DebtStatusFilterNotifier extends Notifier<DebtStatus?> {
  @override
  DebtStatus? build() {
    return DebtStatus.open;
  }

  void set(DebtStatus? value) {
    state = value;
  }
}

class DebtLoanPage extends ConsumerWidget {
  const DebtLoanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return AppScaffold(
      body: Column(
        children: [
          const AppPageHeader(
            title: 'Debt & Receivables',
            subtitle: 'Track money you owe or are owed.',
          ),
          Expanded(
            child: authState.when(
              loading: () => const _CenteredProgress(),
              error: (_, _) => const AppEmptyState(
                icon: Icons.error_outline,
                title: 'Unable to check sign-in status',
                description: 'Please restart the app and try again.',
              ),
              data: (result) {
                return result.when(
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
                        description: 'Sign in to manage debts and receivables.',
                      );
                    }

                    return _DebtContent(userId: user.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtContent extends ConsumerWidget {
  const _DebtContent({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtState = ref.watch(debtListProvider(userId));
    final operationState = ref.watch(debtOperationStateProvider);
    final selectedKind = ref.watch(_debtKindFilterProvider);
    final selectedStatus = ref.watch(_debtStatusFilterProvider);

    ref.listen<AsyncValue<void>>(debtOperationStateProvider, (previous, next) {
      if (next case AsyncError(:final error)) {
        final message = error is AppFailure
            ? error.message
            : 'Something went wrong. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    });
    ref.listen<AsyncValue<Result<List<Debt>>>>(debtListProvider(userId), (
      previous,
      next,
    ) {
      final operationState = ref.read(debtOperationStateProvider);
      if (!operationState.isLoading || !next.hasValue) {
        return;
      }

      next.value?.when(
        success: (_) =>
            ref.read(debtOperationStateProvider.notifier).setSuccess(),
        failure: (_) {},
      );
    });

    return Stack(
      children: [
        debtState.when(
          loading: () => const _CenteredProgress(),
          error: (_, _) => const AppEmptyState(
            icon: Icons.error_outline,
            title: 'Unable to load records',
            description: 'Please try again.',
          ),
          data: (result) {
            return result.when(
              failure: (failure) => AppEmptyState(
                icon: Icons.error_outline,
                title: 'Unable to load records',
                description: failure.message,
              ),
              success: (debts) {
                final filtered = debts
                    .where((debt) {
                      final matchesKind =
                          selectedKind == null || debt.kind == selectedKind;
                      final matchesStatus =
                          selectedStatus == null || debt.status == selectedStatus;
                      return matchesKind && matchesStatus;
                    })
                    .toList(growable: false);

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(debtListProvider(userId)),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: _DebtHeader(
                                debts: debts,
                                selectedKind: selectedKind,
                                selectedStatus: selectedStatus,
                                onKindChanged: (value) => ref
                                    .read(_debtKindFilterProvider.notifier)
                                    .set(value),
                                onStatusChanged: (value) => ref
                                    .read(_debtStatusFilterProvider.notifier)
                                    .set(value),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (operationState.isLoading)
                        const SliverToBoxAdapter(
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (debts.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyDebts(
                            onCreate: operationState.isLoading
                                ? null
                                : () => _showCreateDialog(context, ref, userId),
                          ),
                        )
                      else if (filtered.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: AppEmptyState(
                            icon: Icons.filter_alt_off,
                            title: 'No matching records',
                            description: 'Adjust the filters to see more records.',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          sliver: SliverList.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final debt = filtered[index];
                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 980,
                                  ),
                                  child: _DebtTile(
                                    debt: debt,
                                    isBusy: operationState.isLoading,
                                    onEdit: () => _showEditDialog(
                                      context,
                                      ref,
                                      userId,
                                      debt,
                                    ),
                                    onStatusChanged: (status) =>
                                        _setStatus(ref, userId, debt, status),
                                    onDelete: () => _confirmDelete(
                                      context,
                                      ref,
                                      userId,
                                      debt,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            onPressed: operationState.isLoading
                ? null
                : () => _showCreateDialog(context, ref, userId),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final command = await showDialog<SaveDebtCommand>(
      context: context,
      builder: (_) => const DebtFormDialog(),
    );
    if (command == null || !context.mounted) {
      return;
    }

    await _runOperation(
      ref,
      () => ref.read(createDebtUseCaseProvider(userId)).execute(command),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    Debt debt,
  ) async {
    final command = await showDialog<SaveDebtCommand>(
      context: context,
      builder: (_) => DebtFormDialog(debt: debt),
    );
    if (command == null || !context.mounted) {
      return;
    }

    await _runOperation(
      ref,
      () => ref
          .read(updateDebtUseCaseProvider(userId))
          .execute(debt: debt, command: command),
    );
  }

  Future<void> _setStatus(
    WidgetRef ref,
    String userId,
    Debt debt,
    DebtStatus status,
  ) async {
    await _runOperation(
      ref,
      () => ref
          .read(setDebtStatusUseCaseProvider(userId))
          .execute(debt: debt, status: status),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String userId,
    Debt debt,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text('Delete the record for ${debt.personName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await _runOperation(
      ref,
      () => ref.read(deleteDebtUseCaseProvider(userId)).execute(debt.id),
    );
  }

  Future<void> _runOperation<T>(
    WidgetRef ref,
    Future<Result<T>> Function() action,
  ) async {
    final notifier = ref.read(debtOperationStateProvider.notifier);
    notifier.setLoading();
    try {
      final result = await action().timeout(const Duration(seconds: 12));
      result.when(
        success: (_) => notifier.setSuccess(),
        failure: (failure) => notifier.setFailure(failure, StackTrace.current),
      );
    } on TimeoutException {
      notifier.setSuccess();
    } catch (error, stackTrace) {
      notifier.setFailure(error, stackTrace);
    }
  }
}

class _DebtHeader extends StatelessWidget {
  const _DebtHeader({
    required this.debts,
    required this.selectedKind,
    required this.selectedStatus,
    required this.onKindChanged,
    required this.onStatusChanged,
  });

  final List<Debt> debts;
  final DebtKind? selectedKind;
  final DebtStatus? selectedStatus;
  final ValueChanged<DebtKind?> onKindChanged;
  final ValueChanged<DebtStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final openDebts = debts.where((debt) => debt.status == DebtStatus.open);
    final debtTotal = openDebts
        .where((debt) => debt.kind == DebtKind.debt)
        .fold<double>(0, (total, debt) => total + debt.amount);
    final receivableTotal = openDebts
        .where((debt) => debt.kind == DebtKind.receivable)
        .fold<double>(0, (total, debt) => total + debt.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SummaryChip(
              icon: Icons.call_made_outlined,
              label: 'Open debt',
              value: formatDebtIdr(debtTotal),
            ),
            _SummaryChip(
              icon: Icons.call_received_outlined,
              label: 'Open receivable',
              value: formatDebtIdr(receivableTotal),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<DebtKind?>(
              segments: const [
                ButtonSegment(value: null, label: Text('All')),
                ButtonSegment(
                  value: DebtKind.debt,
                  icon: Icon(Icons.call_made_outlined),
                  label: Text('Debt'),
                ),
                ButtonSegment(
                  value: DebtKind.receivable,
                  icon: Icon(Icons.call_received_outlined),
                  label: Text('Receivable'),
                ),
              ],
              selected: {selectedKind},
              onSelectionChanged: (values) => onKindChanged(values.first),
            ),
            SegmentedButton<DebtStatus?>(
              segments: const [
                ButtonSegment(value: null, label: Text('All')),
                ButtonSegment(
                  value: DebtStatus.open,
                  icon: Icon(Icons.radio_button_checked),
                  label: Text('Open'),
                ),
                ButtonSegment(
                  value: DebtStatus.paid,
                  icon: Icon(Icons.check_circle_outline),
                  label: Text('Paid'),
                ),
                ButtonSegment(
                  value: DebtStatus.cancelled,
                  icon: Icon(Icons.cancel_outlined),
                  label: Text('Cancelled'),
                ),
              ],
              selected: {selectedStatus},
              onSelectionChanged: (values) => onStatusChanged(values.first),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({
    required this.debt,
    required this.isBusy,
    required this.onEdit,
    required this.onStatusChanged,
    required this.onDelete,
  });

  final Debt debt;
  final bool isBusy;
  final VoidCallback onEdit;
  final ValueChanged<DebtStatus> onStatusChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDebt = debt.kind == DebtKind.debt;
    final color = isDebt ? AppColors.expense : AppColors.income;
    final bgColor = isDebt ? AppColors.expenseLight : AppColors.incomeLight;
    final isOverdue = _isOverdue(debt);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: bgColor,
            foregroundColor: color,
            radius: 20,
            child: Icon(debtKindIcon(debt.kind), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debt.personName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      debtStatusLabel(debt.status),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                    ),
                    if (debt.dueDate != null)
                      Text(
                        'Due ${formatDebtDate(debt.dueDate!)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isOverdue ? AppColors.expense : AppColors.textSecondary,
                              fontWeight: isOverdue ? FontWeight.bold : null,
                            ),
                      ),
                  ],
                ),
                if (debt.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    debt.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  formatDebtIdr(debt.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 168),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 0,
              runSpacing: 0,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: isBusy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                ),
                if (debt.status == DebtStatus.open)
                  IconButton(
                    tooltip: 'Mark paid',
                    onPressed: isBusy
                        ? null
                        : () => onStatusChanged(DebtStatus.paid),
                    icon: const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 20),
                  )
                else
                  IconButton(
                    tooltip: 'Reopen',
                    onPressed: isBusy
                        ? null
                        : () => onStatusChanged(DebtStatus.open),
                    icon: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 20),
                  ),
                IconButton(
                  tooltip: 'Cancel',
                  onPressed: isBusy || debt.status == DebtStatus.cancelled
                      ? null
                      : () => onStatusChanged(DebtStatus.cancelled),
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.textSecondary, size: 20),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: isBusy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppColors.expense, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDebts extends StatelessWidget {
  const _EmptyDebts({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.handshake_outlined,
      title: 'No debt records yet',
      description: 'Track money you borrowed or money someone owes you.',
      actionLabel: 'Add record',
      onAction: onCreate,
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

bool _isOverdue(Debt debt) {
  final dueDate = debt.dueDate;
  if (dueDate == null || debt.status != DebtStatus.open) {
    return false;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final localDueDate = dueDate.toLocal();
  final dueDay = DateTime(
    localDueDate.year,
    localDueDate.month,
    localDueDate.day,
  );
  return dueDay.isBefore(today);
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_page.dart';
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

    return authState.when(
      loading: () => const _CenteredProgress(),
      error: (_, _) => const _MessageState(
        icon: Icons.error_outline,
        title: 'Unable to check sign-in status',
        message: 'Please restart the app and try again.',
      ),
      data: (result) {
        return result.when(
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
                message: 'Sign in to manage debts and receivables.',
              );
            }

            return _DebtContent(userId: user.id);
          },
        );
      },
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
      if (previous?.isLoading == true && next.hasValue) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Debt records updated')));
      }
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

    return Scaffold(
      appBar: AppTopBar(
        title: 'Debt & Receivables',
        subtitle: 'Track money you owe and money owed to you.',
        actions: [
          IconButton(
            tooltip: 'Add debt record',
            onPressed: operationState.isLoading
                ? null
                : () => _showCreateDialog(context, ref, userId),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: debtState.when(
        loading: () => const _CenteredProgress(),
        error: (_, _) => const _MessageState(
          icon: Icons.error_outline,
          title: 'Unable to load records',
          message: 'Please try again.',
        ),
        data: (result) {
          return result.when(
            failure: (failure) => _MessageState(
              icon: Icons.error_outline,
              title: 'Unable to load records',
              message: failure.message,
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
                        child: _MessageState(
                          icon: Icons.filter_alt_off,
                          title: 'No matching records',
                          message: 'Adjust the filters to see more records.',
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
                                      _confirmStatusChange(
                                        context,
                                        ref,
                                        userId,
                                        debt,
                                        status,
                                      ),
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
      floatingActionButton: AppBreakpoints.isDesktop(context)
          ? null
          : FloatingActionButton.extended(
              onPressed: operationState.isLoading
                  ? null
                  : () => _showCreateDialog(context, ref, userId),
              icon: const Icon(Icons.add),
              label: const Text('Record'),
            ),
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

  Future<void> _confirmStatusChange(
    BuildContext context,
    WidgetRef ref,
    String userId,
    Debt debt,
    DebtStatus status,
  ) async {
    final action = switch (status) {
      DebtStatus.paid => 'mark this record as paid',
      DebtStatus.cancelled => 'cancel this record',
      DebtStatus.open => 'reopen this record',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          status == DebtStatus.cancelled
              ? Icons.warning_amber_rounded
              : Icons.check_circle_outline,
        ),
        title: const Text('Update record status?'),
        content: Text(
          'Are you sure you want to $action for ${debt.personName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _setStatus(ref, userId, debt, status);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String userId,
    Debt debt,
  ) async {
    final confirmed = await showAppDeleteConfirmation(
      context: context,
      title: 'Delete record?',
      message: 'The record for ${debt.personName} will be permanently deleted.',
    );

    if (!confirmed || !context.mounted) {
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
        Row(
          children: [
            Expanded(
              child: _SummaryChip(
                icon: Icons.call_made_outlined,
                label: 'Open debt',
                value: formatDebtIdr(debtTotal),
                color: AppColors.expense,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SummaryChip(
                icon: Icons.call_received_outlined,
                label: 'Open receivable',
                value: formatDebtIdr(receivableTotal),
                color: AppColors.income,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<DebtKind?>(
              expandedInsets: EdgeInsets.zero,
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
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<DebtStatus?>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: null, label: Text('All')),
                ButtonSegment(value: DebtStatus.open, label: Text('Open')),
                ButtonSegment(value: DebtStatus.paid, label: Text('Paid')),
                ButtonSegment(
                  value: DebtStatus.cancelled,
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
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final kindColor = debtKindColor(context, debt.kind);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: kindColor.withValues(alpha: 0.16),
              foregroundColor: kindColor,
              child: Icon(debtKindIcon(debt.kind)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    debt.personName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(debtKindLabel(debt.kind)),
                      Text(debtStatusLabel(debt.status)),
                      if (debt.dueDate != null)
                        Text(
                          'Due ${formatDebtDate(debt.dueDate!)}',
                          style: TextStyle(
                            color: _isOverdue(debt)
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (debt.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      debt.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    formatDebtIdr(debt.amount),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (AppBreakpoints.isMobile(context))
              PopupMenuButton<_DebtAction>(
                tooltip: 'Record actions',
                onSelected: (action) {
                  switch (action) {
                    case _DebtAction.edit:
                      onEdit();
                    case _DebtAction.togglePaid:
                      onStatusChanged(
                        debt.status == DebtStatus.open
                            ? DebtStatus.paid
                            : DebtStatus.open,
                      );
                    case _DebtAction.cancel:
                      onStatusChanged(DebtStatus.cancelled);
                    case _DebtAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _DebtAction.edit,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _DebtAction.togglePaid,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        debt.status == DebtStatus.open
                            ? Icons.check_circle_outline
                            : Icons.refresh,
                      ),
                      title: Text(
                        debt.status == DebtStatus.open ? 'Mark paid' : 'Reopen',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: _DebtAction.cancel,
                    enabled: debt.status != DebtStatus.cancelled,
                    child: const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.cancel_outlined),
                      title: Text('Cancel record'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: _DebtAction.delete,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 168),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: isBusy ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    if (debt.status == DebtStatus.open)
                      IconButton(
                        tooltip: 'Mark paid',
                        onPressed: isBusy
                            ? null
                            : () => onStatusChanged(DebtStatus.paid),
                        icon: const Icon(Icons.check_circle_outline),
                      )
                    else
                      IconButton(
                        tooltip: 'Reopen',
                        onPressed: isBusy
                            ? null
                            : () => onStatusChanged(DebtStatus.open),
                        icon: const Icon(Icons.refresh),
                      ),
                    IconButton(
                      tooltip: 'Cancel',
                      onPressed: isBusy || debt.status == DebtStatus.cancelled
                          ? null
                          : () => onStatusChanged(DebtStatus.cancelled),
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: isBusy ? null : onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _DebtAction { edit, togglePaid, cancel, delete }

class _EmptyDebts extends StatelessWidget {
  const _EmptyDebts({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.handshake_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No debt records yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Track money you borrowed or money someone owes you.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Add record'),
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

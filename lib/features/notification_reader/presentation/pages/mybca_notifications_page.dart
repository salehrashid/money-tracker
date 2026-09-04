import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../../../shared/undo_delete/pending_delete_controller.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/widgets/undo_delete_snackbar.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../transactions/application/usecases/transaction_commands.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/widgets/transaction_form_dialog.dart';
import '../../../transactions/presentation/widgets/transaction_formatters.dart';
import '../../domain/entities/detected_transaction.dart';
import '../../domain/entities/notification_log.dart';
import '../providers/notification_listener_providers.dart';

final _notificationFilterProvider =
    NotifierProvider.autoDispose<
      _NotificationFilterNotifier,
      _NotificationFilter
    >(_NotificationFilterNotifier.new);

final _selectedNotificationIdsProvider =
    NotifierProvider.autoDispose<_SelectedNotificationsNotifier, Set<String>>(
      _SelectedNotificationsNotifier.new,
    );

final _notificationOperationProvider =
    NotifierProvider.autoDispose<
      _NotificationOperationNotifier,
      AsyncValue<void>
    >(_NotificationOperationNotifier.new);

class MyBcaNotificationsPage extends ConsumerWidget {
  const MyBcaNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(body: AppLoadingState()),
      error: (_, _) => const Scaffold(
        body: AppMessageState(
          icon: Icons.error_outline,
          title: 'Unable to check sign-in status',
          message: 'Please restart the app and try again.',
        ),
      ),
      data: (result) => result.when(
        failure: (failure) => Scaffold(
          body: AppMessageState(
            icon: Icons.error_outline,
            title: 'Unable to check sign-in status',
            message: failure.message,
          ),
        ),
        success: (user) {
          if (user == null) {
            return const Scaffold(
              body: AppMessageState(
                icon: Icons.lock_outline,
                title: 'Sign in required',
                message: 'Sign in to view MyBCA notifications.',
              ),
            );
          }

          return _NotificationContent(userId: user.id);
        },
      ),
    );
  }
}

class _NotificationContent extends ConsumerWidget {
  const _NotificationContent({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsState = ref.watch(notificationLogListProvider(userId));
    final selectedIds = ref.watch(_selectedNotificationIdsProvider);
    final operationState = ref.watch(_notificationOperationProvider);
    final pendingDeletions = ref.watch(pendingDeleteControllerProvider);

    ref.listen<AsyncValue<void>>(_notificationOperationProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        final message = error is AppFailure
            ? error.message
            : 'Something went wrong. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    });

    final isSelecting = selectedIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          isSelecting
              ? '${selectedIds.length} selected'
              : 'MyBCA Notifications',
        ),
        actions: [
          if (isSelecting)
            IconButton(
              tooltip: 'Delete selected',
              onPressed: operationState.isLoading
                  ? null
                  : () => _deleteSelected(context, ref, userId, selectedIds),
              icon: const Icon(Icons.delete_outline),
            )
          else ...[
            IconButton(
              tooltip: 'Mark all as read',
              onPressed: operationState.isLoading
                  ? null
                  : () => _runOperation(
                      ref,
                      () => ref
                          .read(markAllNotificationsReadUseCaseProvider(userId))
                          .execute(),
                    ),
              icon: const Icon(Icons.done_all),
            ),
            PopupMenuButton<_BulkAction>(
              tooltip: 'More actions',
              onSelected: (action) {
                switch (action) {
                  case _BulkAction.deleteRead:
                    _deleteRead(context, ref, userId);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _BulkAction.deleteRead,
                  child: Text('Delete read'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: logsState.when(
        loading: () => const AppLoadingState(),
        error: (_, _) => const AppMessageState(
          icon: Icons.error_outline,
          title: 'Unable to load notifications',
          message: 'Please check your connection and try again.',
        ),
        data: (result) => result.when(
          failure: (failure) => AppMessageState(
            icon: Icons.error_outline,
            title: 'Unable to load notifications',
            message: failure.message,
          ),
          success: (allLogs) {
            final logs = allLogs
                .where(
                  (log) => !pendingDeletions.values.any(
                    (pending) => pending.itemKeys.contains(
                      pendingDeleteItemKey('notification', userId, log.id),
                    ),
                  ),
                )
                .toList(growable: false);
            return _NotificationBody(
              userId: userId,
              logs: logs,
              selectedIds: selectedIds,
              isBusy: operationState.isLoading,
              onRefresh: () async {
                ref.invalidate(notificationLogListProvider(userId));
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteSelected(
    BuildContext context,
    WidgetRef ref,
    String userId,
    Set<String> selectedIds,
  ) async {
    final confirmed = await showAppDeleteConfirmation(
      context: context,
      title: 'Delete selected notifications?',
      message: 'Created transactions will stay in your account.',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    final logs = await _currentLogs(ref, userId);
    if (!context.mounted || logs == null) {
      return;
    }
    final ids = Set<String>.of(selectedIds);
    final snapshots = logs.where((log) => ids.contains(log.id)).toList();
    _scheduleNotificationDelete(
      context: context,
      ref: ref,
      userId: userId,
      logs: snapshots,
    );
    ref.read(_selectedNotificationIdsProvider.notifier).clear();
  }

  Future<void> _deleteRead(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final confirmed = await showAppDeleteConfirmation(
      context: context,
      title: 'Delete read notifications?',
      message: 'Created transactions will stay in your account.',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    final logs = await _currentLogs(ref, userId);
    if (!context.mounted || logs == null) {
      return;
    }
    _scheduleNotificationDelete(
      context: context,
      ref: ref,
      userId: userId,
      logs: logs.where((log) => log.isRead).toList(growable: false),
    );
  }

  Future<List<NotificationLog>?> _currentLogs(
    WidgetRef ref,
    String userId,
  ) async {
    try {
      final result = await ref.read(notificationLogListProvider(userId).future);
      return result.when(
        success: (logs) {
          final pending = ref.read(pendingDeleteControllerProvider);
          return logs
              .where(
                (log) => !pending.values.any(
                  (deletion) => deletion.itemKeys.contains(
                    pendingDeleteItemKey('notification', userId, log.id),
                  ),
                ),
              )
              .toList(growable: false);
        },
        failure: (failure) {
          ref
              .read(_notificationOperationProvider.notifier)
              .setFailure(failure, StackTrace.current);
          return null;
        },
      );
    } catch (error, stackTrace) {
      ref
          .read(_notificationOperationProvider.notifier)
          .setFailure(error, stackTrace);
      return null;
    }
  }

  void _scheduleNotificationDelete({
    required BuildContext context,
    required WidgetRef ref,
    required String userId,
    required List<NotificationLog> logs,
  }) {
    if (logs.isEmpty) {
      return;
    }
    final ids = logs.map((log) => log.id).toSet();
    final itemKeys = ids
        .map((id) => pendingDeleteItemKey('notification', userId, id))
        .toSet();
    final useCase = ref.read(deleteNotificationsUseCaseProvider(userId));
    scheduleUndoDelete<NotificationLog>(
      context: context,
      ref: ref,
      operationKey:
          'notifications:$userId:${DateTime.now().microsecondsSinceEpoch}',
      itemKeys: itemKeys,
      items: logs,
      message: logs.length == 1
          ? 'Notification deleted'
          : '${logs.length} notifications deleted',
      failureMessage: 'Could not delete notifications. Please try again.',
      commitDelete: () => useCase.execute(ids),
    );
  }
}

class _NotificationBody extends ConsumerWidget {
  const _NotificationBody({
    required this.userId,
    required this.logs,
    required this.selectedIds,
    required this.isBusy,
    required this.onRefresh,
  });

  final String userId;
  final List<NotificationLog> logs;
  final Set<String> selectedIds;
  final bool isBusy;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_notificationFilterProvider);
    final filtered = logs.where(filter.matches).toList(growable: false);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          if (isBusy)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _FilterBar(
                    selected: filter,
                    logs: logs,
                    onSelected: (value) => ref
                        .read(_notificationFilterProvider.notifier)
                        .set(value),
                  ),
                ),
              ),
            ),
          ),
          if (logs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppMessageState(
                icon: Icons.notifications_none,
                title: 'No MyBCA notifications',
                message: 'New MyBCA notifications will appear here.',
                contained: false,
              ),
            )
          else if (filtered.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppMessageState(
                icon: Icons.filter_alt_off,
                title: 'No matching notifications',
                message: 'Adjust the filter to see more notifications.',
                contained: false,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final log = filtered[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: _NotificationTile(
                        log: log,
                        isSelected: selectedIds.contains(log.id),
                        isSelecting: selectedIds.isNotEmpty,
                        isBusy: isBusy,
                        onTap: () => _openLog(context, ref, log),
                        onLongPress: () => ref
                            .read(_selectedNotificationIdsProvider.notifier)
                            .toggle(log.id),
                        onSelectionChanged: (_) => ref
                            .read(_selectedNotificationIdsProvider.notifier)
                            .toggle(log.id),
                        onDelete: () => _deleteOne(context, ref, log),
                        onIgnore: () => _runOperation(
                          ref,
                          () => ref
                              .read(ignoreNotificationUseCaseProvider(userId))
                              .execute(log.id),
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
  }

  Future<void> _openLog(
    BuildContext context,
    WidgetRef ref,
    NotificationLog log,
  ) async {
    if (selectedIds.isNotEmpty) {
      ref.read(_selectedNotificationIdsProvider.notifier).toggle(log.id);
      return;
    }

    if (!log.isRead) {
      await _runOperation(
        ref,
        () => ref
            .read(markNotificationReadUseCaseProvider(userId))
            .execute(log.id),
      );
    }

    if (!log.isDetected || log.status != NotificationLogStatus.pendingReview) {
      return;
    }

    final screenData = await _loadTransactionDependencies(ref);
    if (!context.mounted || screenData == null) {
      return;
    }

    final command = await showDialog<SaveTransactionCommand>(
      context: context,
      builder: (_) => TransactionFormDialog(
        categories: screenData.categories,
        accounts: screenData.accounts,
        detectedTransaction: _detectedTransactionFor(log),
      ),
    );
    if (command == null || !context.mounted) {
      return;
    }

    final result = await _runOperation<TransactionEntity>(
      ref,
      () => ref.read(createTransactionUseCaseProvider(userId)).execute(command),
    );
    if (result is Success<TransactionEntity>) {
      await _runOperation(
        ref,
        () => ref
            .read(markNotificationProcessedUseCaseProvider(userId))
            .execute(logId: log.id, transactionId: result.value.id),
      );
    }
  }

  Future<_TransactionDependencies?> _loadTransactionDependencies(
    WidgetRef ref,
  ) async {
    try {
      final categoriesResult = await ref.read(
        categoryListProvider(userId).future,
      );
      final accountsResult = await ref.read(accountListProvider(userId).future);
      return switch ((categoriesResult, accountsResult)) {
        (
          Success<List<Category>>(value: final categories),
          Success<List<Account>>(value: final accounts),
        ) =>
          _TransactionDependencies(categories: categories, accounts: accounts),
        (Failure<List<Category>>(:final failure), _) ||
        (_, Failure<List<Account>>(:final failure)) => throw failure,
      };
    } catch (error, stackTrace) {
      ref
          .read(_notificationOperationProvider.notifier)
          .setFailure(error, stackTrace);
      return null;
    }
  }

  Future<void> _deleteOne(
    BuildContext context,
    WidgetRef ref,
    NotificationLog log,
  ) async {
    final confirmed = await showAppDeleteConfirmation(
      context: context,
      title: 'Delete notification?',
      message: 'Created transactions will stay in your account.',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    final itemKey = pendingDeleteItemKey('notification', userId, log.id);
    final useCase = ref.read(deleteNotificationUseCaseProvider(userId));
    scheduleUndoDelete<NotificationLog>(
      context: context,
      ref: ref,
      operationKey: itemKey,
      itemKeys: {itemKey},
      items: [log],
      message: 'Notification deleted',
      failureMessage: 'Could not delete notification. Please try again.',
      commitDelete: () => useCase.execute(log.id),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.logs,
    required this.onSelected,
  });

  final _NotificationFilter selected;
  final List<NotificationLog> logs;
  final ValueChanged<_NotificationFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _NotificationFilter.values
          .map((filter) {
            final count = logs.where(filter.matches).length;
            return FilterChip(
              selected: selected == filter,
              onSelected: (_) => onSelected(filter),
              label: Text('${filter.label} $count'),
            );
          })
          .toList(growable: false),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.log,
    required this.isSelected,
    required this.isSelecting,
    required this.isBusy,
    required this.onTap,
    required this.onLongPress,
    required this.onSelectionChanged,
    required this.onDelete,
    required this.onIgnore,
  });

  final NotificationLog log;
  final bool isSelected;
  final bool isSelecting;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool?> onSelectionChanged;
  final VoidCallback onDelete;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, log);
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: log.isRead ? colorScheme.surface : colorScheme.primaryContainer,
      child: ListTile(
        onTap: isBusy ? null : onTap,
        onLongPress: isBusy ? null : onLongPress,
        leading: isSelecting
            ? Checkbox(
                value: isSelected,
                onChanged: isBusy ? null : onSelectionChanged,
              )
            : Icon(_statusIcon(log), color: color),
        title: Row(
          children: [
            Expanded(
              child: Text(
                log.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: log.isRead ? FontWeight.w600 : FontWeight.w800,
                ),
              ),
            ),
            if (!log.isRead) const SizedBox(width: 8),
            if (!log.isRead)
              Icon(Icons.circle, size: 9, color: colorScheme.primary),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log.body, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MetaChip(
                    icon: Icons.schedule,
                    label: formatDate(log.receivedAt),
                  ),
                  _MetaChip(icon: _statusIcon(log), label: _statusLabel(log)),
                  if (log.detectedAmount != null)
                    _MetaChip(
                      icon: transactionTypeIcon(_transactionTypeFor(log)),
                      label: formatIdr(log.detectedAmount!),
                    ),
                ],
              ),
            ],
          ),
        ),
        trailing: isSelecting
            ? null
            : PopupMenuButton<_RowAction>(
                tooltip: 'Notification actions',
                enabled: !isBusy,
                onSelected: (action) {
                  switch (action) {
                    case _RowAction.ignore:
                      onIgnore();
                      break;
                    case _RowAction.delete:
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (log.status == NotificationLogStatus.pendingReview)
                    const PopupMenuItem(
                      value: _RowAction.ignore,
                      child: Text('Ignore'),
                    ),
                  const PopupMenuItem(
                    value: _RowAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TransactionDependencies {
  const _TransactionDependencies({
    required this.categories,
    required this.accounts,
  });

  final List<Category> categories;
  final List<Account> accounts;
}

class _NotificationFilterNotifier extends Notifier<_NotificationFilter> {
  @override
  _NotificationFilter build() => _NotificationFilter.all;

  void set(_NotificationFilter filter) {
    state = filter;
  }
}

class _SelectedNotificationsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
      return;
    }

    state = {...state, id};
  }

  void clear() {
    state = {};
  }
}

class _NotificationOperationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  void setLoading() {
    state = const AsyncLoading();
  }

  void setSuccess() {
    state = const AsyncData(null);
  }

  void setFailure(Object error, StackTrace stackTrace) {
    state = AsyncError(error, stackTrace);
  }
}

enum _NotificationFilter {
  all('All'),
  unread('Unread'),
  detected('Detected');

  const _NotificationFilter(this.label);

  final String label;

  bool matches(NotificationLog log) {
    return switch (this) {
      _NotificationFilter.all => true,
      _NotificationFilter.unread => !log.isRead,
      _NotificationFilter.detected => log.isDetected,
    };
  }
}

enum _BulkAction { deleteRead }

enum _RowAction { ignore, delete }

Future<Result<T>?> _runOperation<T>(
  WidgetRef ref,
  Future<Result<T>> Function() action,
) async {
  final notifier = ref.read(_notificationOperationProvider.notifier);
  notifier.setLoading();
  try {
    final result = await action();
    result.when(
      success: (_) => notifier.setSuccess(),
      failure: (failure) => notifier.setFailure(failure, StackTrace.current),
    );
    return result;
  } catch (error, stackTrace) {
    notifier.setFailure(error, stackTrace);
    return null;
  }
}

DetectedTransaction _detectedTransactionFor(NotificationLog log) {
  return DetectedTransaction(
    type: _transactionTypeFor(log),
    amount: log.detectedAmount ?? 0,
    description: log.body,
    originalText: [log.title, log.body].join('\n'),
    detectedAt: log.receivedAt,
    sourcePackage: log.packageName,
    source: log.appName,
  );
}

TransactionType _transactionTypeFor(NotificationLog log) {
  return switch (log.detectedType) {
    DetectedTransactionType.income => TransactionType.income,
    DetectedTransactionType.expense => TransactionType.expense,
    DetectedTransactionType.unknown => TransactionType.expense,
  };
}

IconData _statusIcon(NotificationLog log) {
  return switch (log.status) {
    NotificationLogStatus.pendingReview => Icons.fact_check_outlined,
    NotificationLogStatus.saved => Icons.check_circle_outline,
    NotificationLogStatus.ignoredNonTransaction ||
    NotificationLogStatus.ignoredPromo ||
    NotificationLogStatus.ignoredLowConfidence => Icons.block,
  };
}

Color _statusColor(BuildContext context, NotificationLog log) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (log.status) {
    NotificationLogStatus.pendingReview => colorScheme.tertiary,
    NotificationLogStatus.saved => colorScheme.primary,
    NotificationLogStatus.ignoredNonTransaction ||
    NotificationLogStatus.ignoredPromo ||
    NotificationLogStatus.ignoredLowConfidence => Theme.of(
      context,
    ).colorScheme.onSurfaceVariant,
  };
}

String _statusLabel(NotificationLog log) {
  return switch (log.status) {
    NotificationLogStatus.pendingReview => 'Detected',
    NotificationLogStatus.saved => 'Processed',
    NotificationLogStatus.ignoredNonTransaction ||
    NotificationLogStatus.ignoredPromo ||
    NotificationLogStatus.ignoredLowConfidence => 'Ignored',
  };
}

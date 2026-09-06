import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/undo_delete/pending_delete_controller.dart';
import '../../../../shared/widgets/undo_delete_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/usecases/account_commands.dart';
import '../../domain/entities/account.dart';
import '../providers/account_providers.dart';
import '../widgets/account_form_dialog.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';

final _showArchivedAccountsProvider =
    NotifierProvider.autoDispose<_ShowArchivedAccountsNotifier, bool>(
      _ShowArchivedAccountsNotifier.new,
    );

class _ShowArchivedAccountsNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

class AccountManagementPage extends ConsumerWidget {
  const AccountManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Unable to load accounts.'))),
      data: (result) => result.when(
        failure: (failure) =>
            Scaffold(body: Center(child: Text(failure.message))),
        success: (user) => user == null
            ? const Scaffold(
                body: Center(child: Text('Sign in to manage accounts.')),
              )
            : _Content(userId: user.id),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountListProvider(userId));
    final operation = ref.watch(accountOperationStateProvider);
    final showArchived = ref.watch(_showArchivedAccountsProvider);
    final pendingDeletions = ref.watch(pendingDeleteControllerProvider);
    final transactions = ref.watch(transactionListProvider(userId)).value;
    final Set<String>? referencedIds =
        transactions is Success<List<TransactionEntity>>
        ? transactions.value
              .map((item) => item.accountId)
              .whereType<String>()
              .toSet()
        : null;
    ref.listen(accountOperationStateProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        final message = error is AppFailure
            ? error.message
            : 'Could not update the account.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
    return Scaffold(
      appBar: AppTopBar(
        title: 'Accounts',
        subtitle: 'Choose where money comes from and goes.',
        actions: [
          IconButton(
            tooltip: 'Add account',
            onPressed: operation.isLoading
                ? null
                : () => _edit(context, ref, const []),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: operation.isLoading
            ? null
            : () => state.value?.when(
                success: (items) => _edit(context, ref, items),
                failure: (_) {},
              ),
        icon: const Icon(Icons.add),
        label: const Text('Account'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Unable to load accounts.')),
        data: (result) => result.when(
          failure: (failure) => Center(child: Text(failure.message)),
          success: (accounts) {
            final visible = accounts
                .where((account) {
                  final pending = pendingDeletions.values.any(
                    (operation) => operation.itemKeys.contains(
                      pendingDeleteItemKey('account', userId, account.id),
                    ),
                  );
                  return !pending && account.isArchived == showArchived;
                })
                .toList(growable: false);
            return _list(
              context,
              ref,
              visible,
              accounts,
              referencedIds,
              showArchived,
            );
          },
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<Account> accounts,
    List<Account> allAccounts,
    Set<String>? referencedIds,
    bool showArchived,
  ) {
    if (accounts.isEmpty) {
      return Column(
        children: [
          _archiveFilter(ref, showArchived),
          Expanded(
            child: Center(
              child: Text(
                showArchived
                    ? 'No archived accounts.'
                    : 'No active accounts yet. Add your first account.',
              ),
            ),
          ),
        ],
      );
    }
    final roots = accounts
        .where((item) => item.parentAccountId == null)
        .toList();
    return Column(
      children: [
        _archiveFilter(ref, showArchived),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              for (final type in AccountType.values)
                if (roots.any((item) => item.type == type)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                    child: Text(
                      accountTypeLabel(type).toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (final root in roots.where(
                          (item) => item.type == type,
                        )) ...[
                          _tile(context, ref, allAccounts, root, referencedIds),
                          for (final child in accounts.where(
                            (item) => item.parentAccountId == root.id,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: _tile(
                                context,
                                ref,
                                allAccounts,
                                child,
                                referencedIds,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _archiveFilter(WidgetRef ref, bool showArchived) => Padding(
    padding: const EdgeInsets.all(16),
    child: SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          icon: Icon(Icons.wallet_outlined),
          label: Text('Active'),
        ),
        ButtonSegment(
          value: true,
          icon: Icon(Icons.archive_outlined),
          label: Text('Archived'),
        ),
      ],
      selected: {showArchived},
      showSelectedIcon: false,
      onSelectionChanged: (values) =>
          ref.read(_showArchivedAccountsProvider.notifier).set(values.first),
    ),
  );

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    List<Account> accounts,
    Account account,
    Set<String>? referencedIds,
  ) => ListTile(
    dense: true,
    leading: Icon(
      account.parentAccountId == null
          ? Icons.account_balance_wallet_outlined
          : Icons.subdirectory_arrow_right,
    ),
    title: Text(account.name),
    subtitle: Text(
      '${account.currency} • ${accountTypeLabel(account.type)}${account.isArchived ? ' • Archived' : ''}',
    ),
    trailing: PopupMenuButton<String>(
      onSelected: (action) {
        if (action == 'edit') _edit(context, ref, accounts, account);
        if (action == 'archive') _archive(ref, account);
        if (action == 'delete')
          _delete(
            context,
            ref,
            account,
            referencedIds == null || referencedIds.contains(account.id),
          );
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(
          value: 'archive',
          child: Text(account.isArchived ? 'Restore' : 'Archive'),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Delete',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    ),
  );

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    List<Account> accounts, [
    Account? account,
  ]) async {
    final command = await showDialog<SaveAccountCommand>(
      context: context,
      builder: (_) => AccountFormDialog(accounts: accounts, account: account),
    );
    if (command == null) return;
    await _run(
      ref,
      () => account == null
          ? ref.read(createAccountUseCaseProvider(userId)).execute(command)
          : ref
                .read(updateAccountUseCaseProvider(userId))
                .execute(account: account, command: command),
    );
  }

  Future<void> _archive(WidgetRef ref, Account account) => _run(
    ref,
    () => ref
        .read(setAccountArchivedUseCaseProvider(userId))
        .execute(accountId: account.id, isArchived: !account.isArchived),
  );
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Account account,
    bool referenced,
  ) async {
    if (referenced) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Archive account?'),
          content: const Text(
            'This account is used by transactions, so it will be archived and kept in history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (confirmed == true) await _archive(ref, account);
      return;
    }
    final confirmed = await showAppDeleteConfirmation(
      context: context,
      title: 'Delete account?',
      message: '${account.name} will be permanently deleted.',
    );
    if (!confirmed || !context.mounted) return;
    final itemKey = pendingDeleteItemKey('account', userId, account.id);
    scheduleUndoDelete<Account>(
      context: context,
      ref: ref,
      operationKey: itemKey,
      itemKeys: {itemKey},
      items: [account],
      message: '${account.name} deleted',
      failureMessage: 'Could not delete account. Please try again.',
      commitDelete: () => ref
          .read(deleteAccountUseCaseProvider(userId))
          .execute(accountId: account.id, isReferenced: false),
    );
  }

  Future<void> _run<T>(
    WidgetRef ref,
    Future<Result<T>> Function() action,
  ) async {
    final notifier = ref.read(accountOperationStateProvider.notifier);
    notifier.setLoading();
    final result = await action();
    result.when(
      success: (_) => notifier.setSuccess(),
      failure: (failure) => notifier.setFailure(failure, StackTrace.current),
    );
  }
}

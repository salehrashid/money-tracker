import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../features/accounts/domain/entities/account.dart';
import '../../../../features/accounts/presentation/providers/account_providers.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/categories/domain/entities/category.dart';
import '../../../../features/categories/presentation/providers/category_providers.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../application/usecases/transaction_commands.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_draft.dart';
import '../providers/transaction_providers.dart';
import '../widgets/transaction_form_dialog.dart';
import '../widgets/transaction_formatters.dart';

class TransactionPage extends ConsumerWidget {
  const TransactionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _PageScaffold(body: _CenteredProgress()),
      error: (_, _) => const _PageScaffold(
        body: _MessageState(
          icon: Icons.error_outline,
          title: 'Unable to check sign-in status',
          message: 'Please restart the app and try again.',
        ),
      ),
      data: (result) {
        return result.when(
          failure: (failure) => _PageScaffold(
            body: _MessageState(
              icon: Icons.error_outline,
              title: 'Unable to check sign-in status',
              message: failure.message,
            ),
          ),
          success: (user) {
            if (user == null) {
              return const _PageScaffold(
                body: _MessageState(
                  icon: Icons.lock_outline,
                  title: 'Sign in required',
                  message: 'Sign in to manage your transactions.',
                ),
              );
            }

            return _TransactionContent(userId: user.id);
          },
        );
      },
    );
  }
}

class _TransactionContent extends ConsumerWidget {
  const _TransactionContent({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsState = ref.watch(transactionListProvider(userId));
    final draftsState = ref.watch(pendingTransactionDraftListProvider(userId));
    final categoriesState = ref.watch(categoryListProvider(userId));
    final accountsState = ref.watch(accountListProvider(userId));
    final operationState = ref.watch(transactionOperationStateProvider);

    ref.listen<AsyncValue<void>>(transactionOperationStateProvider, (
      previous,
      next,
    ) {
      if (next case AsyncError(:final error)) {
        final message = error is AppFailure
            ? error.message
            : 'Something went wrong. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    });

    final loaded = _LoadedData.fromStates(
      userId: userId,
      transactionsState: transactionsState,
      draftsState: draftsState,
      categoriesState: categoriesState,
      accountsState: accountsState,
    );
    final canCreate =
        loaded.data != null &&
        loaded.data!.categories.isNotEmpty &&
        loaded.data!.accounts.isNotEmpty;

    return _PageScaffold(
      action: IconButton(
        tooltip: 'Add transaction',
        onPressed: operationState.isLoading || !canCreate
            ? null
            : () => _showCreateDialog(context, ref, loaded.data!),
        icon: const Icon(Icons.add),
      ),
      floatingActionButton: loaded.data == null
          ? null
          : FloatingActionButton.extended(
              onPressed: operationState.isLoading || !canCreate
                  ? null
                  : () => _showCreateDialog(context, ref, loaded.data!),
              icon: const Icon(Icons.add),
              label: const Text('Transaction'),
            ),
      body: switch (loaded) {
        _LoadedData(isLoading: true) => const _CenteredProgress(),
        _LoadedData(failure: final failure?) => _MessageState(
          icon: Icons.error_outline,
          title: 'Unable to load transactions',
          message: failure.message,
        ),
        _LoadedData(data: final data?) => _TransactionBody(
          data: data,
          isBusy: operationState.isLoading,
          onRefresh: () async {
            ref.invalidate(transactionListProvider(userId));
            ref.invalidate(pendingTransactionDraftListProvider(userId));
            ref.invalidate(categoryListProvider(userId));
            ref.invalidate(accountListProvider(userId));
          },
          onCreate: () => _showCreateDialog(context, ref, data),
          onEdit: (transaction) =>
              _showEditDialog(context, ref, data, transaction),
          onDelete: (transaction) =>
              _confirmDelete(context, ref, data.userId, transaction),
          onSaveDraft: (draft) => _showDraftDialog(context, ref, data, draft),
        ),
        _ => const _MessageState(
          icon: Icons.error_outline,
          title: 'Unable to load transactions',
          message: 'Please try again.',
        ),
      },
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
    _TransactionScreenData data,
  ) async {
    final command = await showDialog<SaveTransactionCommand>(
      context: context,
      builder: (_) => TransactionFormDialog(
        categories: data.categories,
        accounts: data.accounts,
      ),
    );
    if (command == null || !context.mounted) {
      return;
    }

    await _runOperation(
      ref,
      () => ref
          .read(createTransactionUseCaseProvider(data.userId))
          .execute(command),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    _TransactionScreenData data,
    TransactionEntity transaction,
  ) async {
    final command = await showDialog<SaveTransactionCommand>(
      context: context,
      builder: (_) => TransactionFormDialog(
        categories: data.categories,
        accounts: data.accounts,
        transaction: transaction,
      ),
    );
    if (command == null || !context.mounted) {
      return;
    }

    await _runOperation(
      ref,
      () => ref
          .read(updateTransactionUseCaseProvider(data.userId))
          .execute(transaction: transaction, command: command),
    );
  }

  Future<void> _showDraftDialog(
    BuildContext context,
    WidgetRef ref,
    _TransactionScreenData data,
    TransactionDraft draft,
  ) async {
    final command = await showDialog<SaveTransactionCommand>(
      context: context,
      builder: (_) => TransactionFormDialog(
        categories: data.categories,
        accounts: data.accounts,
        draft: draft,
      ),
    );
    if (command == null || !context.mounted) {
      return;
    }

    await _runOperation(
      ref,
      () => ref
          .read(saveTransactionDraftUseCaseProvider(data.userId))
          .execute(draft: draft, command: command),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String userId,
    TransactionEntity transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          'Delete ${formatIdr(transaction.amount)} from ${formatDate(transaction.transactionDate)}?',
        ),
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
      () => ref
          .read(deleteTransactionUseCaseProvider(userId))
          .execute(transaction.id),
    );
  }

  Future<void> _runOperation<T>(
    WidgetRef ref,
    Future<Result<T>> Function() action,
  ) async {
    final notifier = ref.read(transactionOperationStateProvider.notifier);
    notifier.setLoading();
    final result = await action();
    result.when(
      success: (_) => notifier.setSuccess(),
      failure: (failure) => notifier.setFailure(failure, StackTrace.current),
    );
  }
}

class _TransactionBody extends StatelessWidget {
  const _TransactionBody({
    required this.data,
    required this.isBusy,
    required this.onRefresh,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onSaveDraft,
  });

  final _TransactionScreenData data;
  final bool isBusy;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreate;
  final ValueChanged<TransactionEntity> onEdit;
  final ValueChanged<TransactionEntity> onDelete;
  final ValueChanged<TransactionDraft> onSaveDraft;

  @override
  Widget build(BuildContext context) {
    if (data.categories.isEmpty || data.accounts.isEmpty) {
      return _MessageState(
        icon: Icons.tune_outlined,
        title: 'Setup required',
        message: data.categories.isEmpty
            ? 'Create at least one category before adding transactions.'
            : 'Create at least one account before adding transactions.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          if (isBusy)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (data.drafts.isNotEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _DraftSection(
                      drafts: data.drafts,
                      isBusy: isBusy,
                      onSaveDraft: onSaveDraft,
                    ),
                  ),
                ),
              ),
            ),
          if (data.transactions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyTransactions(onCreate: isBusy ? null : onCreate),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              sliver: SliverList.separated(
                itemCount: data.transactions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final transaction = data.transactions[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: _TransactionTile(
                        transaction: transaction,
                        category: data.categoryById[transaction.categoryId],
                        account: data.accountById[transaction.accountId],
                        isBusy: isBusy,
                        onEdit: () => onEdit(transaction),
                        onDelete: () => onDelete(transaction),
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
}

class _DraftSection extends StatelessWidget {
  const _DraftSection({
    required this.drafts,
    required this.isBusy,
    required this.onSaveDraft,
  });

  final List<TransactionDraft> drafts;
  final bool isBusy;
  final ValueChanged<TransactionDraft> onSaveDraft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pending drafts', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...drafts.map(
          (draft) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: Icon(transactionTypeIcon(draft.detectedType)),
                title: Text(formatIdr(draft.detectedAmount)),
                subtitle: Text(
                  draft.detectedText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: FilledButton.icon(
                  onPressed: isBusy ? null : () => onSaveDraft(draft),
                  icon: const Icon(Icons.check),
                  label: const Text('Review'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.category,
    required this.account,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionEntity transaction;
  final Category? category;
  final Account? account;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = transactionTypeColor(context, transaction.type);
    final signedAmount = transaction.type == TransactionType.income ? '+' : '-';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          foregroundColor: color,
          child: Icon(transactionTypeIcon(transaction.type)),
        ),
        title: Text(
          '$signedAmount${formatIdr(transaction.amount)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            category?.name ?? 'Unknown category',
            account?.name ?? 'Unknown account',
            formatDate(transaction.transactionDate),
            transactionSourceLabel(transaction.source),
            ?transaction.note.isNotEmpty ? transaction.note : null,
          ].join(' - '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Edit',
              onPressed: isBusy ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: isBusy ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.onCreate});

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
              'Add income or expenses to start tracking your money.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Add transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadedData {
  const _LoadedData._({this.isLoading = false, this.failure, this.data});

  final bool isLoading;
  final AppFailure? failure;
  final _TransactionScreenData? data;

  factory _LoadedData.fromStates({
    required String userId,
    required AsyncValue<Result<List<TransactionEntity>>> transactionsState,
    required AsyncValue<Result<List<TransactionDraft>>> draftsState,
    required AsyncValue<Result<List<Category>>> categoriesState,
    required AsyncValue<Result<List<Account>>> accountsState,
  }) {
    final states = [
      transactionsState,
      draftsState,
      categoriesState,
      accountsState,
    ];
    if (states.any((state) => state.isLoading)) {
      return const _LoadedData._(isLoading: true);
    }

    for (final state in states) {
      if (state.hasError) {
        return const _LoadedData._(
          failure: AppFailure(
            type: AppFailureType.unknown,
            message: 'Please try again.',
          ),
        );
      }
    }

    final transactionsResult = transactionsState.value;
    final draftsResult = draftsState.value;
    final categoriesResult = categoriesState.value;
    final accountsResult = accountsState.value;
    if (transactionsResult == null ||
        draftsResult == null ||
        categoriesResult == null ||
        accountsResult == null) {
      return const _LoadedData._(isLoading: true);
    }

    if (transactionsResult case Failure<List<TransactionEntity>>(
      :final failure,
    )) {
      return _LoadedData._(failure: failure);
    }
    if (draftsResult case Failure<List<TransactionDraft>>(:final failure)) {
      return _LoadedData._(failure: failure);
    }
    if (categoriesResult case Failure<List<Category>>(:final failure)) {
      return _LoadedData._(failure: failure);
    }
    if (accountsResult case Failure<List<Account>>(:final failure)) {
      return _LoadedData._(failure: failure);
    }

    return _LoadedData._(
      data: _TransactionScreenData(
        userId: userId,
        transactions:
            (transactionsResult as Success<List<TransactionEntity>>).value,
        drafts: (draftsResult as Success<List<TransactionDraft>>).value,
        categories: (categoriesResult as Success<List<Category>>).value,
        accounts: (accountsResult as Success<List<Account>>).value,
      ),
    );
  }
}

class _TransactionScreenData {
  _TransactionScreenData({
    required this.userId,
    required this.transactions,
    required this.drafts,
    required this.categories,
    required this.accounts,
  }) : categoryById = {
         for (final category in categories) category.id: category,
       },
       accountById = {for (final account in accounts) account.id: account};

  final String userId;
  final List<TransactionEntity> transactions;
  final List<TransactionDraft> drafts;
  final List<Category> categories;
  final List<Account> accounts;
  final Map<String, Category> categoryById;
  final Map<String, Account> accountById;
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({
    required this.body,
    this.action,
    this.floatingActionButton,
  });

  final Widget body;
  final Widget? action;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions'), actions: [?action]),
      body: body,
      floatingActionButton: floatingActionButton,
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
    return const Center(child: CircularProgressIndicator());
  }
}

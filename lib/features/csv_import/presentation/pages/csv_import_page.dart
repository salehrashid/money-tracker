import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/widgets/transaction_formatters.dart';
import '../../domain/entities/csv_import_preview.dart';
import '../providers/csv_import_providers.dart';

class CsvImportPage extends ConsumerWidget {
  const CsvImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Import CSV')),
      body: authState.when(
        loading: () => const _CenteredProgress(),
        error: (_, _) => const _MessageState(
          icon: Icons.error_outline,
          title: 'Unable to check sign-in status',
          message: 'Please restart the app and try again.',
        ),
        data: (result) => result.when(
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
                message: 'Sign in to import CSV transactions.',
              );
            }

            return _CsvImportContent(userId: user.id);
          },
        ),
      ),
    );
  }
}

class _CsvImportContent extends ConsumerStatefulWidget {
  const _CsvImportContent({required this.userId});

  final String userId;

  @override
  ConsumerState<_CsvImportContent> createState() => _CsvImportContentState();
}

class _CsvImportContentState extends ConsumerState<_CsvImportContent> {
  String? _accountId;
  String? _expenseCategoryId;
  String? _incomeCategoryId;

  @override
  Widget build(BuildContext context) {
    final transactionsState = ref.watch(transactionListProvider(widget.userId));
    final accountsState = ref.watch(accountListProvider(widget.userId));
    final categoriesState = ref.watch(categoryListProvider(widget.userId));
    final importState = ref.watch(csvImportControllerProvider);

    ref.listen<CsvImportState>(csvImportControllerProvider, (previous, next) {
      if (next.operation case AsyncError(:final error)) {
        final message = error is AppFailure
            ? error.message
            : 'CSV import failed. Please check the file and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
      final result = next.result;
      if (result != null && previous?.result != result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${result.importedRows} rows. Skipped ${result.skippedRows}.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final loaded = _LoadedData.fromStates(
      transactionsState: transactionsState,
      accountsState: accountsState,
      categoriesState: categoriesState,
    );

    return switch (loaded) {
      _LoadedData(isLoading: true) => const _CenteredProgress(),
      _LoadedData(failure: final failure?) => _MessageState(
        icon: Icons.error_outline,
        title: 'Unable to load import data',
        message: failure.message,
      ),
      _LoadedData(data: final data?) => _CsvImportBody(
        data: data,
        state: importState,
        accountId: _accountId,
        expenseCategoryId: _expenseCategoryId,
        incomeCategoryId: _incomeCategoryId,
        onAccountChanged: (value) => setState(() => _accountId = value),
        onExpenseCategoryChanged: (value) {
          setState(() => _expenseCategoryId = value);
        },
        onIncomeCategoryChanged: (value) {
          setState(() => _incomeCategoryId = value);
        },
        onPickFile: () => ref
            .read(csvImportControllerProvider.notifier)
            .pickAndPreview(existingTransactions: data.transactions),
        onConfirm: () => _confirmImport(data),
        onClear: () {
          setState(() {
            _accountId = null;
            _expenseCategoryId = null;
            _incomeCategoryId = null;
          });
          ref.read(csvImportControllerProvider.notifier).clear();
        },
      ),
      _ => const _MessageState(
        icon: Icons.error_outline,
        title: 'Unable to load import data',
        message: 'Please try again.',
      ),
    };
  }

  Future<void> _confirmImport(_CsvImportScreenData data) async {
    final preview = ref.read(csvImportControllerProvider).preview;
    if (preview == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import CSV rows?'),
        content: Text(
          'Import ${preview.validRows} transactions from ${preview.fileName}? '
          '${preview.invalidRows + preview.duplicateRows} rows will be skipped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await ref
        .read(csvImportControllerProvider.notifier)
        .confirm(
          userId: widget.userId,
          accountId: _accountId ?? data.accounts.firstOrNull?.id ?? '',
          expenseCategoryId:
              _expenseCategoryId ??
              data.expenseCategories.firstOrNull?.id ??
              '',
          incomeCategoryId:
              _incomeCategoryId ?? data.incomeCategories.firstOrNull?.id ?? '',
        );
  }
}

class _CsvImportBody extends StatelessWidget {
  const _CsvImportBody({
    required this.data,
    required this.state,
    required this.accountId,
    required this.expenseCategoryId,
    required this.incomeCategoryId,
    required this.onAccountChanged,
    required this.onExpenseCategoryChanged,
    required this.onIncomeCategoryChanged,
    required this.onPickFile,
    required this.onConfirm,
    required this.onClear,
  });

  final _CsvImportScreenData data;
  final CsvImportState state;
  final String? accountId;
  final String? expenseCategoryId;
  final String? incomeCategoryId;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<String?> onExpenseCategoryChanged;
  final ValueChanged<String?> onIncomeCategoryChanged;
  final VoidCallback onPickFile;
  final VoidCallback onConfirm;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview;
    final isBusy = state.operation.isLoading;
    final hasRequiredData =
        data.accounts.isNotEmpty &&
        data.expenseCategories.isNotEmpty &&
        data.incomeCategories.isNotEmpty;
    final canImport =
        preview?.hasImportableRows == true && hasRequiredData && !isBusy;

    return RefreshIndicator(
      onRefresh: () async {},
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ImportActions(
                        isBusy: isBusy,
                        canImport: canImport,
                        onPickFile: onPickFile,
                        onConfirm: onConfirm,
                        onClear: preview == null ? null : onClear,
                      ),
                      const SizedBox(height: 16),
                      if (!hasRequiredData)
                        const _MessageState(
                          icon: Icons.rule_folder_outlined,
                          title: 'Set up accounts and categories',
                          message:
                              'Create at least one account, income category, and expense category before importing.',
                        )
                      else
                        _ImportDefaults(
                          accounts: data.accounts,
                          expenseCategories: data.expenseCategories,
                          incomeCategories: data.incomeCategories,
                          accountId: accountId ?? data.accounts.first.id,
                          expenseCategoryId:
                              expenseCategoryId ??
                              data.expenseCategories.first.id,
                          incomeCategoryId:
                              incomeCategoryId ??
                              data.incomeCategories.first.id,
                          onAccountChanged: onAccountChanged,
                          onExpenseCategoryChanged: onExpenseCategoryChanged,
                          onIncomeCategoryChanged: onIncomeCategoryChanged,
                        ),
                      const SizedBox(height: 16),
                      if (preview == null)
                        const _MessageState(
                          icon: Icons.upload_file_outlined,
                          title: 'No CSV preview yet',
                          message:
                              'Choose a CSV file to validate rows before saving transactions.',
                        )
                      else ...[
                        _PreviewSummary(preview: preview),
                        const SizedBox(height: 16),
                        _PreviewTable(preview: preview),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportActions extends StatelessWidget {
  const _ImportActions({
    required this.isBusy,
    required this.canImport,
    required this.onPickFile,
    required this.onConfirm,
    required this.onClear,
  });

  final bool isBusy;
  final bool canImport;
  final VoidCallback onPickFile;
  final VoidCallback onConfirm;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: isBusy ? null : onPickFile,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Choose CSV'),
        ),
        OutlinedButton.icon(
          onPressed: isBusy ? null : onClear,
          icon: const Icon(Icons.clear),
          label: const Text('Clear'),
        ),
        FilledButton.icon(
          onPressed: canImport ? onConfirm : null,
          icon: isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_upload_outlined),
          label: const Text('Import valid rows'),
        ),
      ],
    );
  }
}

class _ImportDefaults extends StatelessWidget {
  const _ImportDefaults({
    required this.accounts,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.accountId,
    required this.expenseCategoryId,
    required this.incomeCategoryId,
    required this.onAccountChanged,
    required this.onExpenseCategoryChanged,
    required this.onIncomeCategoryChanged,
  });

  final List<Account> accounts;
  final List<Category> expenseCategories;
  final List<Category> incomeCategories;
  final String accountId;
  final String expenseCategoryId;
  final String incomeCategoryId;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<String?> onExpenseCategoryChanged;
  final ValueChanged<String?> onIncomeCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 820;
    final fields = [
      DropdownButtonFormField<String>(
        initialValue: accountId,
        decoration: const InputDecoration(labelText: 'Account'),
        items: accounts
            .map(
              (account) => DropdownMenuItem(
                value: account.id,
                child: Text(account.name),
              ),
            )
            .toList(growable: false),
        onChanged: onAccountChanged,
      ),
      DropdownButtonFormField<String>(
        initialValue: expenseCategoryId,
        decoration: const InputDecoration(labelText: 'Expense category'),
        items: expenseCategories
            .map(
              (category) => DropdownMenuItem(
                value: category.id,
                child: Text(category.name),
              ),
            )
            .toList(growable: false),
        onChanged: onExpenseCategoryChanged,
      ),
      DropdownButtonFormField<String>(
        initialValue: incomeCategoryId,
        decoration: const InputDecoration(labelText: 'Income category'),
        items: incomeCategories
            .map(
              (category) => DropdownMenuItem(
                value: category.id,
                child: Text(category.name),
              ),
            )
            .toList(growable: false),
        onChanged: onIncomeCategoryChanged,
      ),
    ];

    if (isWide) {
      return Row(
        children: fields
            .map(
              (field) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: field,
                ),
              ),
            )
            .toList(growable: false),
      );
    }

    return Column(
      children: fields
          .map(
            (field) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: field,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _PreviewSummary extends StatelessWidget {
  const _PreviewSummary({required this.preview});

  final CsvImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Total', preview.totalRows, Icons.table_rows_outlined),
      ('Valid', preview.validRows, Icons.check_circle_outline),
      ('Duplicate', preview.duplicateRows, Icons.content_copy_outlined),
      ('Invalid', preview.invalidRows, Icons.error_outline),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview.fileName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map(
                    (item) => _SummaryChip(
                      label: item.$1,
                      value: item.$2,
                      icon: item.$3,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text('$label: $value'));
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.preview});

  final CsvImportPreview preview;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Row')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Note')),
            DataColumn(label: Text('Message')),
          ],
          rows: preview.rows
              .map((row) {
                return DataRow(
                  cells: [
                    DataCell(Text(row.rowNumber.toString())),
                    DataCell(_StatusLabel(status: row.status)),
                    DataCell(Text(_dateText(row.transactionDate))),
                    DataCell(
                      Text(
                        row.type == null
                            ? '-'
                            : transactionTypeLabel(row.type!),
                      ),
                    ),
                    DataCell(
                      Text(row.amount == null ? '-' : formatIdr(row.amount!)),
                    ),
                    DataCell(SizedBox(width: 220, child: Text(row.note))),
                    DataCell(
                      SizedBox(width: 260, child: Text(row.errorMessage ?? '')),
                    ),
                  ],
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final CsvImportRowStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, label, color) = switch (status) {
      CsvImportRowStatus.valid => (
        Icons.check_circle_outline,
        'Valid',
        Colors.teal,
      ),
      CsvImportRowStatus.duplicate => (
        Icons.content_copy_outlined,
        'Duplicate',
        colorScheme.tertiary,
      ),
      CsvImportRowStatus.invalid => (
        Icons.error_outline,
        'Invalid',
        colorScheme.error,
      ),
      CsvImportRowStatus.imported => (
        Icons.file_download_done_outlined,
        'Imported',
        colorScheme.primary,
      ),
      CsvImportRowStatus.skipped => (
        Icons.block_outlined,
        'Skipped',
        colorScheme.outline,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _LoadedData {
  const _LoadedData._({this.data, this.failure, this.isLoading = false});

  final _CsvImportScreenData? data;
  final AppFailure? failure;
  final bool isLoading;

  factory _LoadedData.fromStates({
    required AsyncValue<Result<List<TransactionEntity>>> transactionsState,
    required AsyncValue<Result<List<Account>>> accountsState,
    required AsyncValue<Result<List<Category>>> categoriesState,
  }) {
    if (transactionsState.isLoading ||
        accountsState.isLoading ||
        categoriesState.isLoading) {
      return const _LoadedData._(isLoading: true);
    }

    final transactionFailure = _failureFromState(transactionsState);
    final accountFailure = _failureFromState(accountsState);
    final categoryFailure = _failureFromState(categoriesState);
    final failure = transactionFailure ?? accountFailure ?? categoryFailure;
    if (failure != null) {
      return _LoadedData._(failure: failure);
    }

    final transactions = _successValue(transactionsState) ?? const [];
    final accounts = (_successValue(accountsState) ?? const <Account>[])
        .where((account) => !account.isArchived)
        .toList(growable: false);
    final categories = (_successValue(categoriesState) ?? const <Category>[])
        .where((category) => !category.isArchived)
        .toList(growable: false);

    return _LoadedData._(
      data: _CsvImportScreenData(
        transactions: transactions,
        accounts: accounts,
        categories: categories,
      ),
    );
  }
}

class _CsvImportScreenData {
  const _CsvImportScreenData({
    required this.transactions,
    required this.accounts,
    required this.categories,
  });

  final List<TransactionEntity> transactions;
  final List<Account> accounts;
  final List<Category> categories;

  List<Category> get expenseCategories => categories
      .where((category) => category.type == TransactionType.expense)
      .toList(growable: false);

  List<Category> get incomeCategories => categories
      .where((category) => category.type == TransactionType.income)
      .toList(growable: false);
}

AppFailure? _failureFromState<T>(AsyncValue<Result<T>> state) {
  if (state case AsyncError(:final error)) {
    return error is AppFailure
        ? error
        : const AppFailure(
            type: AppFailureType.unknown,
            message: 'Something went wrong. Please try again.',
          );
  }

  final result = state.value;
  if (result case Failure<T>(:final failure)) {
    return failure;
  }

  return null;
}

T? _successValue<T>(AsyncValue<Result<T>> state) {
  final result = state.value;
  if (result case Success<T>(value: final successValue)) {
    return successValue;
  }

  return null;
}

String _dateText(DateTime? value) {
  if (value == null) {
    return '-';
  }

  return formatDate(value);
}

class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
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
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 16),
              Text(
                title,
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

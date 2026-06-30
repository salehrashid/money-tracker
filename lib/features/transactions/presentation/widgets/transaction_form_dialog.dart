import 'package:flutter/material.dart';

import '../../../../features/accounts/domain/entities/account.dart';
import '../../../../features/categories/domain/entities/category.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../application/usecases/transaction_commands.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_draft.dart';
import 'transaction_formatters.dart';

class TransactionFormDialog extends StatefulWidget {
  const TransactionFormDialog({
    required this.categories,
    required this.accounts,
    this.transaction,
    this.draft,
    super.key,
  });

  final List<Category> categories;
  final List<Account> accounts;
  final TransactionEntity? transaction;
  final TransactionDraft? draft;

  @override
  State<TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<TransactionFormDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late TransactionType _type;
  late DateTime _date;
  String? _categoryId;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    final draft = widget.draft;
    _type = transaction?.type ?? draft?.detectedType ?? TransactionType.expense;
    _date = transaction?.transactionDate.toLocal() ?? DateTime.now();
    _amountController = TextEditingController(
      text: _initialAmount(transaction, draft),
    );
    _noteController = TextEditingController(
      text: transaction?.note ?? draft?.detectedText ?? '',
    );
    _categoryId = transaction?.categoryId ?? draft?.suggestedCategoryId;
    _accountId = transaction?.accountId;
    _ensureValidSelections();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final draft = widget.draft;
    final availableCategories = _availableCategories();
    final activeAccounts = widget.accounts
        .where((account) => !account.isArchived || account.id == _accountId)
        .toList(growable: false);

    return AlertDialog(
      title: Text(
        transaction == null
            ? draft == null
                  ? 'Add transaction'
                  : 'Save draft'
            : 'Edit transaction',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    icon: Icon(Icons.remove_circle_outline),
                    label: Text('Expense'),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    icon: Icon(Icons.add_circle_outline),
                    label: Text('Income'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (values) {
                  setState(() {
                    _type = values.first;
                    _categoryId = null;
                    _ensureValidSelections();
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: availableCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: availableCategories.isEmpty
                    ? null
                    : (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Account',
                  border: OutlineInputBorder(),
                ),
                items: activeAccounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text('${account.name} (${account.currency})'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: activeAccounts.isEmpty
                    ? null
                    : (value) => setState(() => _accountId = value),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(formatDate(_date)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            final command = _command();
            if (command == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter a valid amount, category, and account.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }

            Navigator.of(context).pop(command);
          },
          icon: const Icon(Icons.check),
          label: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _date = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  SaveTransactionCommand? _command() {
    final amount = _parseAmount(_amountController.text);
    final categoryId = _categoryId;
    final accountId = _accountId;
    if (amount == null ||
        amount <= 0 ||
        categoryId == null ||
        accountId == null) {
      return null;
    }

    return SaveTransactionCommand(
      type: _type,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      note: _noteController.text,
      transactionDate: _date,
    );
  }

  List<Category> _availableCategories() {
    return widget.categories
        .where(
          (category) =>
              category.type == _type &&
              (!category.isArchived || category.id == _categoryId),
        )
        .toList(growable: false);
  }

  void _ensureValidSelections() {
    final categoryIds = _availableCategories()
        .map((category) => category.id)
        .toSet();
    if (!categoryIds.contains(_categoryId)) {
      _categoryId = categoryIds.isEmpty ? null : categoryIds.first;
    }

    final accountIds = widget.accounts
        .where((account) => !account.isArchived || account.id == _accountId)
        .map((account) => account.id)
        .toSet();
    if (!accountIds.contains(_accountId)) {
      _accountId = accountIds.isEmpty ? null : accountIds.first;
    }
  }
}

String _initialAmount(TransactionEntity? transaction, TransactionDraft? draft) {
  final amount = transaction?.amount ?? draft?.detectedAmount;
  if (amount == null) {
    return '';
  }
  if (amount == amount.roundToDouble()) {
    return amount.round().toString();
  }

  return amount.toString();
}

double? _parseAmount(String value) {
  final normalized = value
      .replaceAll('Rp', '')
      .replaceAll('rp', '')
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .trim();
  return double.tryParse(normalized);
}

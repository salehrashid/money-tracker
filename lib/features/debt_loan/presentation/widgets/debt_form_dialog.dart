import 'package:flutter/material.dart';

import '../../../../shared/models/finance_enums.dart';
import '../../application/usecases/debt_commands.dart';
import '../../domain/entities/debt.dart';
import 'debt_formatters.dart';

class DebtFormDialog extends StatefulWidget {
  const DebtFormDialog({this.debt, super.key});

  final Debt? debt;

  @override
  State<DebtFormDialog> createState() => _DebtFormDialogState();
}

class _DebtFormDialogState extends State<DebtFormDialog> {
  late final TextEditingController _personNameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DebtKind _kind;
  late DebtStatus _status;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    _kind = debt?.kind ?? DebtKind.debt;
    _status = debt?.status ?? DebtStatus.open;
    _dueDate = debt?.dueDate?.toLocal();
    _personNameController = TextEditingController(text: debt?.personName ?? '');
    _amountController = TextEditingController(text: _initialAmount(debt));
    _noteController = TextEditingController(text: debt?.note ?? '');
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debt = widget.debt;

    return AlertDialog(
      title: Text(debt == null ? 'Add debt record' : 'Edit debt record'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<DebtKind>(
                segments: const [
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
                selected: {_kind},
                onSelectionChanged: (values) {
                  setState(() => _kind = values.first);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _personNameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 72,
                decoration: const InputDecoration(
                  labelText: 'Person name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DebtStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                ),
                items: DebtStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(debtStatusLabel(status)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _dueDate == null
                          ? 'No due date'
                          : formatDebtDate(_dueDate!),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton.outlined(
                      tooltip: 'Clear due date',
                      onPressed: () => setState(() => _dueDate = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 160,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
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
                  content: Text('Enter a name and an amount above zero.'),
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

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _dueDate = DateTime(selected.year, selected.month, selected.day);
    });
  }

  SaveDebtCommand? _command() {
    final amount = _parseAmount(_amountController.text);
    if (_personNameController.text.trim().isEmpty ||
        amount == null ||
        amount <= 0) {
      return null;
    }

    return SaveDebtCommand(
      kind: _kind,
      personName: _personNameController.text,
      amount: amount,
      status: _status,
      dueDate: _dueDate,
      note: _noteController.text,
    );
  }
}

String _initialAmount(Debt? debt) {
  final amount = debt?.amount;
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

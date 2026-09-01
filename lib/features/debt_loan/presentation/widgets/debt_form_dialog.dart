import 'package:flutter/material.dart';

import '../../../../shared/models/finance_enums.dart';
import '../../../../shared/widgets/responsive_controls.dart';
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _personNameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DebtKind _kind;
  late DebtStatus _status;
  late DateTime _transactionDate;

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    _kind = debt?.kind ?? DebtKind.debt;
    _status = debt?.status ?? DebtStatus.open;
    _transactionDate = debt?.transactionDate.toLocal() ?? DateTime.now();
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
    final dialogWidth = responsiveDialogWidth(context);

    return AlertDialog(
      title: Text(debt == null ? 'Add debt record' : 'Edit debt record'),
      content: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: dialogWidth,
            maxWidth: dialogWidth,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ResponsiveSegmentedButton<DebtKind>(
                    segments: const [
                      ResponsiveSegment(
                        value: DebtKind.debt,
                        icon: Icons.call_made_outlined,
                        label: 'Debt',
                      ),
                      ResponsiveSegment(
                        value: DebtKind.receivable,
                        icon: Icons.call_received_outlined,
                        label: 'Receivable',
                      ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (values) {
                      setState(() => _kind = values.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _personNameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 72,
                    decoration: const InputDecoration(
                      labelText: 'Person / entity',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Enter a person or entity'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'Rp ',
                    ),
                    validator: (value) {
                      final amount = _parseAmount(value ?? '');
                      return amount == null || amount <= 0
                          ? 'Enter an amount above zero'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<DebtStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
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
                        onPressed: _pickTransactionDate,
                        icon: const Icon(Icons.event_outlined),
                        label: Text(_transactionDateLabel()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 160,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                ],
              ),
            ),
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
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            final command = _command();
            if (command == null) {
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

  Future<void> _pickTransactionDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _transactionDate = DateTime(selected.year, selected.month, selected.day);
    });
  }

  String _transactionDateLabel() {
    final label = _kind == DebtKind.receivable ? 'Lent date' : 'Borrowed date';
    return '$label: ${formatDebtDate(_transactionDate)}';
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
      transactionDate: _transactionDate,
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

import 'package:flutter/material.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../shared/models/finance_enums.dart';
import '../../../../shared/widgets/responsive_controls.dart';
import '../../application/usecases/debt_commands.dart';
import '../../domain/entities/debt.dart';
import '../services/transfer_proof_picker.dart';
import 'debt_formatters.dart';
import 'transfer_proof_preview.dart';

class DebtFormDialog extends StatefulWidget {
  const DebtFormDialog({
    this.debt,
    this.transferProofPicker = const TransferProofPicker(),
    super.key,
  });

  final Debt? debt;
  final TransferProofPicker transferProofPicker;

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
  String? _transferProofBase64;
  String? _transferProofError;
  bool _isPickingPhoto = false;

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
    _transferProofBase64 = debt?.transferProofBase64;
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
                  const SizedBox(height: 16),
                  _buildTransferProofField(context),
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
          onPressed: _isPickingPhoto
              ? null
              : () {
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

  Widget _buildTransferProofField(BuildContext context) {
    final proof = _transferProofBase64;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Transfer proof (optional)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          'Attach a transfer receipt photo, or save without one. JPG, PNG or '
          'WebP, up to 10 MB. Large photos are resized automatically.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (proof != null) ...[
          const SizedBox(height: 12),
          TransferProofPreview(base64Data: proof),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isPickingPhoto ? null : _pickTransferProof,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(proof == null ? 'Upload photo' : 'Replace photo'),
            ),
            if (proof != null)
              TextButton.icon(
                onPressed: _isPickingPhoto
                    ? null
                    : () => setState(() {
                        _transferProofBase64 = null;
                        _transferProofError = null;
                      }),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove photo'),
              ),
          ],
        ),
        if (_isPickingPhoto) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(semanticsLabel: 'Preparing photo'),
        ],
        if (_transferProofError != null) ...[
          const SizedBox(height: 8),
          Text(
            _transferProofError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickTransferProof() async {
    setState(() {
      _isPickingPhoto = true;
      _transferProofError = null;
    });

    try {
      final proof = await widget.transferProofPicker.pick();
      if (!mounted || proof == null) return;
      setState(() => _transferProofBase64 = proof);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _transferProofError = error is AppFailure
            ? error.message
            : 'Unable to open this photo. Please try another image.';
      });
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
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
      transferProofBase64: _transferProofBase64,
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

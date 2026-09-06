import 'package:flutter/material.dart';

import '../../../../shared/models/finance_enums.dart';
import '../../../accounts/application/usecases/account_commands.dart';
import '../../../accounts/domain/entities/account.dart';

class AccountFormDialog extends StatefulWidget {
  const AccountFormDialog({required this.accounts, this.account, super.key});
  final List<Account> accounts;
  final Account? account;

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late final TextEditingController _currency;
  late AccountType _type;
  String? _parentId;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _name = TextEditingController(text: account?.name ?? '');
    _balance = TextEditingController(
      text: account == null ? '' : _formatBalance(account.initialBalance),
    );
    _currency = TextEditingController(text: account?.currency ?? 'IDR');
    _type = account?.type ?? AccountType.bank;
    _parentId = account?.parentAccountId;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _currency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parents = widget.accounts
        .where(
          (item) =>
              item.id != widget.account?.id &&
              item.parentAccountId == null &&
              !item.isArchived,
        )
        .toList();
    return AlertDialog(
      title: Text(widget.account == null ? 'Add account' : 'Edit account'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Account name *',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an account name'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccountType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Account type *',
                  ),
                  items: AccountType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_typeLabel(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _type = value ?? _type),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: parents.any((item) => item.id == _parentId)
                      ? _parentId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Parent account (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String>(child: Text('None')),
                    ...parents.map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _parentId = value;
                    if (value != null) _type = AccountType.pocket;
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _balance,
                        decoration: const InputDecoration(
                          labelText: 'Initial balance',
                        ),
                        validator: (value) =>
                            value?.trim().isNotEmpty == true &&
                                double.tryParse(value!.trim()) == null
                            ? 'Enter a valid balance'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        controller: _currency,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    if (!(_key.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      SaveAccountCommand(
        name: _name.text,
        type: _parentId == null ? _type : AccountType.pocket,
        parentAccountId: _parentId,
        currency: _currency.text,
        initialBalance: double.tryParse(_balance.text.trim()) ?? 0,
        sortOrder: widget.account?.sortOrder ?? widget.accounts.length,
      ),
    );
  }
}

String _formatBalance(double value) {
  return value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();
}

String accountTypeLabel(AccountType type) => _typeLabel(type);
String _typeLabel(AccountType type) => switch (type) {
  AccountType.cash => 'Cash',
  AccountType.bank => 'Bank accounts',
  AccountType.eWallet => 'E-wallet',
  AccountType.card => 'Cards / stored value',
  AccountType.pocket => 'Pockets',
  AccountType.other => 'Other',
};

enum BackupValueType { text, number, integer, boolean, date }

class BackupField {
  const BackupField(this.column, this.key, this.type, {this.required = true});
  final String column;
  final String key;
  final BackupValueType type;
  final bool required;
}

class BackupDataset {
  const BackupDataset(this.name, this.collection, this.fields);
  final String name;
  final String collection;
  final List<BackupField> fields;
}

const backupDatasets = <BackupDataset>[
  BackupDataset('accounts', 'accounts', [
    BackupField('id', 'id', BackupValueType.text),
    BackupField('name', 'name', BackupValueType.text),
    BackupField('type', 'type', BackupValueType.text),
    BackupField('currency', 'currency', BackupValueType.text),
    BackupField('initial_balance', 'initialBalance', BackupValueType.number),
    BackupField('is_archived', 'isArchived', BackupValueType.boolean),
    BackupField(
      'parent_account_id',
      'parentAccountId',
      BackupValueType.text,
      required: false,
    ),
    BackupField('sort_order', 'sortOrder', BackupValueType.integer),
    BackupField('created_at', 'createdAt', BackupValueType.date),
    BackupField('updated_at', 'updatedAt', BackupValueType.date),
  ]),
  BackupDataset('categories', 'categories', [
    BackupField('id', 'id', BackupValueType.text),
    BackupField('name', 'name', BackupValueType.text),
    BackupField('type', 'type', BackupValueType.text),
    BackupField('icon', 'icon', BackupValueType.text),
    BackupField('color', 'color', BackupValueType.text),
    BackupField('is_default', 'isDefault', BackupValueType.boolean),
    BackupField('is_archived', 'isArchived', BackupValueType.boolean),
    BackupField('created_at', 'createdAt', BackupValueType.date),
    BackupField('updated_at', 'updatedAt', BackupValueType.date),
  ]),
  BackupDataset('subcategories', 'categories', [
    BackupField('id', 'id', BackupValueType.text),
    BackupField('category_id', 'parentCategoryId', BackupValueType.text),
    BackupField('name', 'name', BackupValueType.text),
    BackupField('type', 'type', BackupValueType.text),
    BackupField('icon', 'icon', BackupValueType.text),
    BackupField('color', 'color', BackupValueType.text),
    BackupField('is_default', 'isDefault', BackupValueType.boolean),
    BackupField('is_archived', 'isArchived', BackupValueType.boolean),
    BackupField('created_at', 'createdAt', BackupValueType.date),
    BackupField('updated_at', 'updatedAt', BackupValueType.date),
  ]),
  BackupDataset('transactions', 'transactions', [
    BackupField('id', 'id', BackupValueType.text),
    BackupField('type', 'type', BackupValueType.text),
    BackupField('amount', 'amount', BackupValueType.number),
    BackupField('currency', 'currency', BackupValueType.text),
    BackupField('category_id', 'categoryId', BackupValueType.text),
    BackupField(
      'account_id',
      'accountId',
      BackupValueType.text,
      required: false,
    ),
    BackupField('note', 'note', BackupValueType.text, required: false),
    BackupField('source', 'source', BackupValueType.text),
    BackupField('transaction_date', 'transactionDate', BackupValueType.date),
    BackupField('created_at', 'createdAt', BackupValueType.date),
    BackupField('updated_at', 'updatedAt', BackupValueType.date),
    BackupField(
      'deleted_at',
      'deletedAt',
      BackupValueType.date,
      required: false,
    ),
  ]),
  BackupDataset('debts', 'debts', [
    BackupField('id', 'id', BackupValueType.text),
    BackupField('kind', 'kind', BackupValueType.text),
    BackupField('person_name', 'personName', BackupValueType.text),
    BackupField('amount', 'amount', BackupValueType.number),
    BackupField('currency', 'currency', BackupValueType.text),
    BackupField('status', 'status', BackupValueType.text),
    BackupField('transaction_date', 'transactionDate', BackupValueType.date),
    BackupField('note', 'note', BackupValueType.text, required: false),
    BackupField(
      'transfer_proof_base64',
      'transferProofBase64',
      BackupValueType.text,
      required: false,
    ),
    BackupField('created_at', 'createdAt', BackupValueType.date),
    BackupField('updated_at', 'updatedAt', BackupValueType.date),
  ]),
  BackupDataset('loans', 'debts', [
    BackupField('id', 'id', BackupValueType.text),
    BackupField('kind', 'kind', BackupValueType.text),
    BackupField('person_name', 'personName', BackupValueType.text),
    BackupField('amount', 'amount', BackupValueType.number),
    BackupField('currency', 'currency', BackupValueType.text),
    BackupField('status', 'status', BackupValueType.text),
    BackupField('transaction_date', 'transactionDate', BackupValueType.date),
    BackupField('note', 'note', BackupValueType.text, required: false),
    BackupField(
      'transfer_proof_base64',
      'transferProofBase64',
      BackupValueType.text,
      required: false,
    ),
    BackupField('created_at', 'createdAt', BackupValueType.date),
    BackupField('updated_at', 'updatedAt', BackupValueType.date),
  ]),
  BackupDataset('settings', 'settings', [
    BackupField('id', 'id', BackupValueType.text),
    BackupField(
      'financial_cycle_day',
      'financialCycleDay',
      BackupValueType.integer,
    ),
    BackupField('is_dark_mode', 'isDarkMode', BackupValueType.boolean),
  ]),
];

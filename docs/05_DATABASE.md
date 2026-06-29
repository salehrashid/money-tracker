# Firebase Data Model

## Firestore Root Structure

Use user-scoped collections.

```text
users/{userId}/
  accounts/{accountId}
  categories/{categoryId}
  transactions/{transactionId}
  transaction_drafts/{draftId}
  debts/{debtId}
  receipt_ocr_results/{ocrId}
  notification_logs/{logId}
  csv_import_batches/{batchId}
  settings/app
```

## Transaction Document

```json
{
  "id": "string",
  "type": "income | expense",
  "amount": 50000,
  "currency": "IDR",
  "categoryId": "string",
  "accountId": "string",
  "note": "string",
  "source": "manual | ocr | csv | mybca_notification",
  "transactionDate": "timestamp",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "deletedAt": null
}
```

## Transaction Draft Document

```json
{
  "id": "string",
  "draftType": "ocr | csv | mybca_notification",
  "detectedType": "income | expense",
  "detectedAmount": 50000,
  "detectedCurrency": "IDR",
  "detectedText": "string",
  "suggestedCategoryId": "string|null",
  "status": "pending_review | saved | ignored | duplicate | invalid",
  "confidence": 0.95,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Category Document

```json
{
  "id": "string",
  "name": "Food",
  "type": "income | expense",
  "icon": "restaurant",
  "color": "#4CAF50",
  "isDefault": true,
  "isArchived": false,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Debt Document

```json
{
  "id": "string",
  "kind": "debt | receivable",
  "personName": "string",
  "amount": 100000,
  "currency": "IDR",
  "status": "open | paid | cancelled",
  "dueDate": "timestamp|null",
  "note": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Notification Log Document

```json
{
  "id": "string",
  "appName": "myBCA",
  "packageName": "string",
  "title": "Catatan Finansial",
  "body": "string",
  "detectedType": "income | expense | unknown",
  "detectedAmount": 50000,
  "status": "ignored_non_transaction | ignored_promo | ignored_low_confidence | pending_review | saved",
  "dedupeHash": "string",
  "receivedAt": "timestamp",
  "createdAt": "timestamp"
}
```

## Important Rules

- Use soft delete when practical.
- Use server timestamps for createdAt and updatedAt when possible.
- Keep draft and saved transaction documents separate.
- Do not store bank credentials.
- Create indexes only when required by Firestore query errors.

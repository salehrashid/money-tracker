# Product Requirements

## Functional Requirements

### Dashboard
- Show total balance.
- Show monthly income.
- Show monthly expense.
- Show net cash flow.
- Show recent transactions.
- Show simple chart summaries.

### Transactions
- Create income transaction.
- Create expense transaction.
- Edit transaction.
- Delete transaction.
- Assign category.
- Assign account/source.
- Add note.
- Add date and time.
- Support transaction drafts from OCR, CSV, and myBCA notifications.

### Categories
- Provide default categories.
- Support custom categories.
- Separate income and expense categories.
- Support icon and color metadata.

### Search and Filter
- Search by note, amount, category, and date.
- Filter by transaction type.
- Filter by date range.
- Filter by category.
- Filter by account.

### Statistics
- Show income vs expense.
- Show expense by category.
- Show monthly trend.
- Show highest expense categories.
- Show financial summary for selected date ranges.

### Debt and Receivables
- Track money borrowed from others.
- Track money lent to others.
- Store due date, status, note, amount, and person name.
- Mark as paid.

### Receipt OCR
- Android-first feature.
- Read receipt image from camera/gallery.
- Extract total amount, date, merchant when possible.
- Create transaction draft, not final transaction.

### CSV Import
- Import transaction records from CSV.
- Preview before saving.
- Validate required columns.
- Detect duplicates.

### myBCA Notification Reader
- Android only.
- Read myBCA notification through Notification Access.
- Only accept notifications with title `Catatan Finansial`.
- Body must contain `Pengeluaran sebesar IDR` or `Pemasukan sebesar IDR`.
- Create a pending draft transaction.
- Show local confirmation notification.
- User opens confirmation notification and lands on transaction detail page.
- User can edit and save.

## Non-Functional Requirements

- Use Flutter and Dart.
- Use Firebase as backend.
- Use Firebase Authentication for private login.
- Use Cloud Firestore for structured data.
- Use Firebase Storage for receipt images if needed.
- Use Riverpod for state management.
- Use GoRouter for navigation.
- Use Material 3 for UI.
- Do not use direct bank credential storage.
- The app must remain maintainable and modular.
- The code must be readable and testable.

## Data Safety Requirements

- Never save banking credentials.
- Do not auto-save notification-detected transactions.
- Keep draft records separate from saved transactions.
- Avoid destructive delete without confirmation.
- Store timestamps for create/update/delete flows.

## Personal Use Constraints

Because the app is for personal use, prioritize reliability and simplicity over large-scale user management. Avoid complex admin systems, organization roles, or billing systems.

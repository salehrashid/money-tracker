# Firestore Migration Audit

## Current Source of Truth

Financial records are stored in Cloud Firestore under the authenticated Firebase
UID:

- `users/{uid}/accounts/{accountId}`
- `users/{uid}/transactions/{transactionId}`
- `users/{uid}/categories/{categoryId}`
- `users/{uid}/debts/{debtId}`

The UID comes from Firebase Authentication and is exposed to feature providers
as `AuthUser.id`, which maps directly from `FirebaseAuth`'s `User.uid`.

## Local Storage Audit

No local database package is configured for financial data. The app does not use
Hive, SQLite, Drift, Flutter secure storage, SharedPreferences, or local JSON
files for accounts, transactions, categories, debts, or balances.

The only direct local persistence found is Android `SharedPreferences` in the
native notification bridge. That state is device-specific notification listener
configuration/processing state and is not the long-term financial source of
truth.

## Migration Decision

There is no financial local data store to migrate in the current codebase. A
one-time financial-data upload migration is therefore not implemented. If a
future version adds a legacy local database, migration should authenticate the
user first, check `users/{uid}` for existing cloud data, upload only missing
stable IDs, and mark migration completion in a device-local flag to avoid
duplicates.

## Security

Firestore rules are checked in at `firestore.rules` and restrict access to the
owner of `users/{uid}` and all nested financial collections with:

`request.auth != null && request.auth.uid == userId`

# Database Models

## Session Recommendation

Same chat as Firebase Foundation if stable, otherwise new chat

## Read These Files First

- docs/03_ARCHITECTURE.md
- docs/05_DATABASE.md
- docs/models/transaction.md
- docs/models/transaction_draft.md
- docs/models/category.md
- docs/models/account.md
- docs/models/debt.md
- docs/models/notification_log.md
- docs/models/receipt.md
- docs/models/csv_import.md

## Task

Implement domain entities, DTOs, enum mapping, and Firestore serialization for core models.

## Strict Rules

- Modify only files needed for this task.
- Do not refactor unrelated modules.
- Do not remove existing functionality.
- Follow Clean Architecture.
- Use Riverpod for state management.
- Use Firebase only through repositories/data sources.
- Keep Android-only code isolated from desktop/web builds.
- Stop after this task is complete.

## Output Expected

- Production-ready code changes for this task only.
- Short explanation of what changed.
- List of files modified.
- Any commands needed to run or test.

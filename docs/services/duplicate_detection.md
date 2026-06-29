# Service: Duplicate Detection

## Purpose

Duplicate detection for transactions, notification logs, OCR drafts, and CSV rows.

## Rules

- Keep service logic independent from UI widgets.
- Return typed results or typed failures.
- Avoid throwing raw exceptions to UI.
- Write unit tests for parsing and validation logic.

## Acceptance Criteria

- Service has clear input and output.
- Service behavior is documented.
- Service handles invalid input safely.
- Service does not depend on unrelated features.

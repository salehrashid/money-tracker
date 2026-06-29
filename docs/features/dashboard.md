# Feature: Dashboard

## Purpose

Dashboard displays total balance, monthly income, monthly expense, net cash flow, recent transactions, and simple charts. It must read from repositories/providers and never query Firestore directly from widgets.

## Scope

This document defines only this feature. Do not implement unrelated features while working from this file.

## Requirements

- Follow the architecture in `docs/03_ARCHITECTURE.md`.
- Follow coding rules in `docs/06_CODING_STANDARDS.md`.
- Keep UI consistent with `docs/07_UI_GUIDELINES.md`.
- Use Firebase through repositories only.
- Support loading, empty, error, and success states where UI exists.

## Data Flow

```text
User action or external input
  -> Provider / Use Case
  -> Repository Interface
  -> Firebase Repository Implementation
  -> Firestore / Storage
  -> UI state update
```

## Edge Cases

- Missing data.
- Invalid input.
- Network unavailable.
- Permission denied.
- Duplicate records where applicable.
- Unsupported platform for Android-only features.

## Acceptance Criteria

- The feature works on supported platforms.
- The implementation does not break other modules.
- The feature has clear error messages.
- The code is modular and testable.
- Existing documentation rules are followed.

## Codex Instruction

When implementing this feature, modify only files required for this feature. Do not refactor unrelated features.

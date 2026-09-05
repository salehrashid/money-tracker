# Feature: Debt Loan

## Purpose

Debt and receivables track money borrowed and money lent with person, amount, transaction date, status, notes, and an optional transfer receipt photo.

## Scope

This document defines only this feature. Do not implement unrelated features while working from this file.

## Requirements

- Follow the architecture in `docs/03_ARCHITECTURE.md`.
- Follow coding rules in `docs/06_CODING_STANDARDS.md`.
- Keep UI consistent with `docs/07_UI_GUIDELINES.md`.
- Use Firebase through repositories only.
- Support loading, empty, error, and success states where UI exists.
- Allow one optional transfer proof photo when adding or editing a record.
- Allow previewing, replacing, and removing the photo before saving. Cancelling the form leaves the saved photo unchanged.
- Continue allowing records without photos, including existing records created before photo support.
- Accept JPG, PNG, and WebP files up to 10 MiB. Validate the image and automatically resize large photos; show an error without discarding the existing photo if preparation fails.
- Persist the photo with the debt record so the existing offline queue and user-scoped Firestore synchronization also handle attachments.

## Transfer Proof Storage

The nullable `transferProofBase64` field stores the prepared image. The encoded image is limited to 600 KiB before base64 encoding (800 KiB encoded), leaving room for other fields within Firestore's [1 MiB document limit](https://firebase.google.com/docs/firestore/quotas#collections_documents_and_fields). This uses the existing offline persistence and synchronization without requiring a separate storage service. Each debt read includes its attached image.

Small images retain their original bytes; larger images are resized proportionally and encoded as PNG. The saved copy may be smaller than the original. Clearing a photo writes an explicit null, and changing only the record status preserves it.

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

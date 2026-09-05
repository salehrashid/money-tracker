# UI: Debt Loan

## Purpose

Define UI behavior and layout for debt loan.

## Requirements

- Use Material 3.
- Support loading, empty, error, and success states.
- Keep widgets small and reusable.
- Use Riverpod for state.
- Do not call Firebase directly from widgets.
- Support mobile and desktop responsive layout where applicable.

## UX Rules

- Confirm destructive actions.
- Show clear validation messages.
- Do not hide important financial information.
- Format currency as IDR.
- Show a `Transfer proof (optional)` field in add and edit forms, with an `Upload photo` action.
- Show a preview and `Replace photo` / `Remove photo` actions when attached. Photo changes apply only when the form is saved.
- Disable Save and attachment actions while preparing a selected photo; allow saving without a photo after cancellation or a selection error.
- Offer `View transfer proof` on records with an attachment, opening a zoomable image dialog.

## Acceptance Criteria

- UI renders correctly on phone width.
- UI renders correctly on desktop width.
- Empty state is meaningful.
- Error state is understandable.

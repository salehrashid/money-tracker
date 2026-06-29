# Service: Firebase

## Purpose

Firebase initialization, auth state, user-scoped collection references, and shared Firebase error mapping.

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

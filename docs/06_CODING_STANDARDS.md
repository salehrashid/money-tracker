# Coding Standards

## General Rules

- Write clean, readable Dart code.
- Use meaningful names.
- Keep functions small.
- Avoid large widgets.
- Avoid business logic inside widgets.
- Do not refactor unrelated modules during a feature task.

## Flutter Rules

- Prefer StatelessWidget and ConsumerWidget.
- Use Riverpod providers for state.
- Avoid setState except in tiny isolated UI-only widgets.
- Use Material 3 components.
- Keep UI responsive for mobile and desktop.

## Firebase Rules

- Do not call Firestore directly from widgets.
- Use repositories and data sources.
- Map Firestore errors to user-friendly messages.
- Use user-scoped paths.

## Platform Rules

- Guard Android-only features with platform checks.
- Desktop builds must not fail because of Android-only imports.
- Web builds must avoid unsupported plugins unless guarded.

## Error Handling

- Never show raw stack traces to the user.
- Log debug information only in development.
- Show friendly error messages.

## Git Rules

- Commit after each completed feature stage.
- Do not mix multiple unrelated features in one commit.
- Recommended commit style: Conventional Commits.

## Codex Rules

- Read only the requested documentation files.
- Modify only files required by the task.
- Do not remove existing functionality.
- Do not rename folders without explicit instruction.
- Do not change architecture unless the prompt asks for it.

# Architecture

## Architectural Style

Use a modular feature-based Clean Architecture approach.

## Layers

```text
Presentation Layer
  Flutter pages, widgets, controllers/providers

Application Layer
  Use cases, commands, orchestration

Domain Layer
  Entities, value objects, repository interfaces

Data Layer
  Firebase data sources, DTOs, repository implementations
```

## Dependency Direction

Outer layers may depend on inner layers. Inner layers must not depend on Flutter UI or Firebase implementation.

## Feature Module Pattern

Each feature should contain:

```text
features/<feature_name>/
  data/
  domain/
  presentation/
```

## Repository Pattern

- UI must not call Firebase directly.
- Providers call use cases or repositories.
- Repositories hide Firestore implementation details.

## Draft vs Saved Data

Data created from automation, OCR, or CSV preview should first become a draft or preview record. It must not become a saved transaction until the user confirms it.

## Platform Isolation

Android-only features must be isolated:

```text
features/notification_reader/
  android/
  domain/
  presentation/
```

Do not import Android-only packages in shared desktop/web code paths without guards.

## Error Handling

Use typed failures or consistent exception mapping. UI must show user-friendly errors.

## Testing Strategy

- Unit test parsers and services.
- Widget test main forms and empty/loading/error states.
- Integration test critical transaction flows.

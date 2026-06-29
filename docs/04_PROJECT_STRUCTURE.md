# Project Structure

Use this structure unless there is a strong reason to change it.

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
    bootstrap.dart
  core/
    constants/
    errors/
    extensions/
    formatting/
    platform/
    utils/
  shared/
    widgets/
    providers/
    models/
  features/
    auth/
    dashboard/
    transactions/
    categories/
    statistics/
    search_filter/
    debt_loan/
    receipt_ocr/
    csv_import/
    notification_reader/
    settings/
```

## Feature Structure

```text
features/transactions/
  data/
    datasources/
    dto/
    repositories/
  domain/
    entities/
    repositories/
    usecases/
  presentation/
    pages/
    widgets/
    providers/
```

## Rules

- Do not place feature business logic in `main.dart`.
- Do not place Firebase code in UI widgets.
- Do not create random folders outside this structure.
- Shared widgets go to `shared/widgets` only if used by more than one feature.
- Feature-private widgets stay inside the feature folder.

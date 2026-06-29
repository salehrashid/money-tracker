# Model: Category

## Purpose

Category entity for income and expense classification.

## Rules

- Use immutable models where possible.
- Include id, createdAt, and updatedAt when persisted.
- Keep Firestore DTO mapping separate from domain entities when needed.
- Validate required fields before saving.

## Common Fields

- `id`: string
- `createdAt`: DateTime
- `updatedAt`: DateTime

## Serialization

- Provide `fromFirestore` / `toFirestore` mapping in data layer.
- Do not expose raw Firestore maps directly to UI.

## Testing

- Test serialization.
- Test invalid data behavior.
- Test enum mapping.

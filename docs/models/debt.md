# Model: Debt

## Purpose

Debt/receivable entity.

## Rules

- Use immutable models where possible.
- Include id, createdAt, and updatedAt when persisted.
- Keep Firestore DTO mapping separate from domain entities when needed.
- Validate required fields before saving.

## Common Fields

- `id`: string
- `createdAt`: DateTime
- `updatedAt`: DateTime
- `transferProofBase64`: nullable string containing one prepared transfer receipt image; absent or empty values in older records mean no attachment.

## Serialization

- Provide `fromFirestore` / `toFirestore` mapping in data layer.
- Do not expose raw Firestore maps directly to UI.
- Serialize `transferProofBase64` as null when removed so updates clear the saved attachment.
- Keep the photo when copying a record unless `clearTransferProof` is explicitly requested.

## Testing

- Test serialization.
- Test invalid data behavior.
- Test enum mapping.

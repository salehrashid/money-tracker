# Decision 0002: No Direct Bank Integration

## Status
Accepted

## Context
Direct mobile banking integration requires credentials, bank APIs, or formal partnership.

## Decision
Do not connect directly to m-banking accounts. Use manual input, CSV import, OCR, and notification-based drafts instead.

## Consequences
- Safer for personal use.
- No bank credentials are stored.
- User confirmation is required before saving detected transactions.

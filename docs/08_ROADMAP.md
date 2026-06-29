# Roadmap and Codex Session Plan

## Important Workflow Rule

Do not ask Codex to implement the entire application in one chat. Use one focused session per major domain.

## Phase 1: Foundation

### Session 1: Project Setup — New Chat
Use `docs/prompts/00_SETUP_PROJECT.md`.
Commit: `chore: initialize flutter project structure`

### Session 2: Firebase Base — New Chat
Use `docs/prompts/01_FIREBASE_FOUNDATION.md`.
Commit: `chore: add firebase foundation`

### Session 3: Database Models — Same Chat as Session 2 if stable, otherwise New Chat
Use `docs/prompts/02_DATABASE_MODELS.md`.
Commit: `feat: add finance data models`

## Phase 2: Core Finance

### Session 4: Categories — New Chat
Use `docs/prompts/03_CATEGORIES.md`.
Commit: `feat: add category management`

### Session 5: Transactions — New Chat
Use `docs/prompts/04_TRANSACTIONS.md`.
Commit: `feat: add transaction management`

### Session 6: Dashboard — New Chat
Use `docs/prompts/05_DASHBOARD.md`.
Commit: `feat: add dashboard overview`

### Session 7: Search and Filter — Same Chat as Transactions only if context remains short
Use `docs/prompts/06_SEARCH_FILTER.md`.
Commit: `feat: add transaction search and filters`

### Session 8: Statistics — New Chat
Use `docs/prompts/07_STATISTICS.md`.
Commit: `feat: add finance statistics`

## Phase 3: Supporting Features

### Session 9: Debt and Receivables — New Chat
Use `docs/prompts/08_DEBT_LOAN.md`.
Commit: `feat: add debt and receivable tracking`

### Session 10: CSV Import — New Chat
Use `docs/prompts/09_CSV_IMPORT.md`.
Commit: `feat: add csv transaction import`

### Session 11: Receipt OCR — New Chat
Use `docs/prompts/10_RECEIPT_OCR.md`.
Commit: `feat: add receipt ocr drafts`

## Phase 4: Android Automation

### Session 12: Notification Listener — New Chat
Use `docs/prompts/11_NOTIFICATION_LISTENER.md`.
Commit: `feat: add android notification listener base`

### Session 13: myBCA Parser — Same Chat as Notification Listener if stable
Use `docs/prompts/12_MYBCA_PARSER.md`.
Commit: `feat: add mybca notification parser`

## Phase 5: Quality

### Session 14: Testing — New Chat
Use `docs/prompts/13_TESTING.md`.
Commit: `test: add core feature tests`

### Session 15: Final Review — New Chat
Use `docs/prompts/14_FINAL_REVIEW.md`.
Commit: `chore: final review and cleanup`

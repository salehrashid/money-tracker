# Master Workflow

Follow this file when working with Codex.

## How to Use These Documents

1. Open the prompt file for the current step from `docs/prompts/`.
2. Paste only that prompt into Codex.
3. Make sure the referenced documentation files exist in the repository.
4. Let Codex read only the referenced files.
5. Review the diff carefully.
6. Run tests/build.
7. Commit.
8. Move to the next prompt.

## Do Not

- Do not paste all documentation files into Codex at once.
- Do not ask Codex to build all features in one request.
- Do not let Codex refactor unrelated modules.
- Do not skip review before committing.

## Session Rule

Use a new Codex chat for every major feature unless the roadmap explicitly says the same chat is acceptable.

## Recommended Order

1. `00_SETUP_PROJECT.md`
2. `01_FIREBASE_FOUNDATION.md`
3. `02_DATABASE_MODELS.md`
4. `03_CATEGORIES.md`
5. `04_TRANSACTIONS.md`
6. `05_DASHBOARD.md`
7. `06_SEARCH_FILTER.md`
8. `07_STATISTICS.md`
9. `08_DEBT_LOAN.md`
10. `09_CSV_IMPORT.md`
11. `10_RECEIPT_OCR.md`
12. `11_NOTIFICATION_LISTENER.md`
13. `12_MYBCA_PARSER.md`
14. `13_TESTING.md`
15. `14_FINAL_REVIEW.md`

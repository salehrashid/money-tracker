# Tech Stack

## Main Framework

- Flutter
- Dart

## Backend

- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Messaging, optional
- Firebase Crashlytics, optional
- Firebase Analytics, optional and disabled by default for privacy

## State Management

- Riverpod
- Prefer Notifier/AsyncNotifier for business state.
- Avoid mixing multiple state management approaches.

## Routing

- GoRouter
- Use named routes.
- Keep route paths centralized.

## UI

- Material 3
- Responsive layouts for phone and desktop.
- Dark mode support.

## Android-Specific Packages

Use Android-specific implementation only behind platform checks.

- Notification listener plugin or custom platform channel for Notification Access.
- Local notifications for confirmation flow.
- Image picker/camera package for receipt OCR.
- Google ML Kit Text Recognition or equivalent OCR package.

## Desktop-Specific Packages

- file_picker for CSV import.
- path_provider for local temporary files.

## CSV

- csv package for parsing.
- Keep import validation in a dedicated service.

## Recommended Flutter Packages

- flutter_riverpod
- go_router
- firebase_core
- firebase_auth
- cloud_firestore
- firebase_storage
- intl
- uuid
- collection
- file_picker
- csv
- image_picker
- flutter_local_notifications

## Avoid Unless Needed

- Heavy local database packages if Firestore is the primary database.
- Direct bank API libraries.
- Unmaintained notification listener packages without fallback strategy.

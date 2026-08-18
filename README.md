# Money Tracker

Money Tracker is a private personal finance app built with Flutter, Riverpod,
Firebase Authentication, and Cloud Firestore. It tracks income, expenses,
categories, debts, receivables, dashboard summaries, statistics, CSV imports,
and Android-only myBCA notification transaction drafts.

## Supported Platforms

- Android: full feature set, including notification access for myBCA draft
  detection.
- Windows and Linux: core finance features, dashboard, statistics, categories,
  and CSV import.
- Web: optional core finance features when Firebase Web configuration is
  available.

## Configuration

Copy `assets/env.sample` to `.env` and fill in the Firebase values for the
target Firebase project. The app also accepts the same Firebase keys through
`--dart-define` values for build environments that do not use `.env`.

## Development Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk
```

Android native notification parser tests live under `android/app/src/test` and
can be run with:

```bash
cd android
./gradlew testDebugUnitTest
```

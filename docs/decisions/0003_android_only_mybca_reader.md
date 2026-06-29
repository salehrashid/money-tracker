# Decision 0003: Android-only myBCA Reader

## Status
Accepted

## Context
Notification Access is an Android feature and is unavailable on Windows/Linux/Web.

## Decision
Implement myBCA notification detection only on Android.

## Consequences
- Desktop builds must not import Android-only plugins directly.
- Shared code receives parsed draft results through platform-safe abstractions.

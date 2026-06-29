# Money Tracker Personal Finance App

This documentation is the source of truth for a personal-use Flutter finance tracking application.

## Product Summary

Money Tracker is a private, multi-platform personal finance app built with Flutter and Firebase. It helps the owner record income, expenses, categories, debts, receivables, receipt OCR results, CSV imports, and Android-only myBCA notification transaction drafts.

## Main Goal

Build a reliable personal finance tracker that is simple to maintain, safe for private financial data, and scalable enough to support Android, Windows, Linux, and Web from one Flutter codebase.

## Target User

The application is designed for personal use only. Do not optimize for public multi-tenant SaaS, team administration, paid subscription systems, or open banking integrations.

## Supported Platforms

- Android: full feature set, including OCR and myBCA notification detection.
- Windows: core finance features, dashboard, statistics, categories, CSV import.
- Linux: core finance features, dashboard, statistics, categories, CSV import.
- Web: optional core finance features if Firebase Web setup is available.

## Major Features

- Dashboard
- Transactions
- Categories
- Search and filters
- Statistics and analytics
- Debt and receivable tracking
- Receipt OCR
- CSV import
- Multi-platform support
- Android-only myBCA notification reader with user confirmation flow

## Non-Goals

- Do not integrate directly with mobile banking credentials.
- Do not store bank username, password, PIN, token, or session data.
- Do not implement public user registration flows beyond the owner's private login.
- Do not build a subscription system.
- Do not implement bank API / open banking unless explicitly requested later.

## Core Principle

Every detected financial event must be reviewed by the user before it becomes a saved transaction. Automation may create drafts, but final saving must be user-controlled.

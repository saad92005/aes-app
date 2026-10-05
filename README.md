# AES App — Field Operations & Business Management Platform

**One Flutter codebase that runs an engineering services company end to end: work orders, GPS attendance, payroll, double-entry accounting, inventory and role-based access for 12 roles.**

<img src="assets/images/store_screenshots/screenshot_3.jpg" alt="AES App dashboard: work orders by region and status" width="280">

A cross-platform (Android, iOS, Web, Windows) internal business management app built for **Al-Areesh Engineering Solutions (AES)**, a facilities/engineering services company. Built with Flutter and Firebase.

## What it does

A single app covering the full operational and financial workflow for a multi-region engineering services company:

- **Work Orders** — Gmail-sync auto-import, manual creation, region/status tracking, assignment to employees/vendors, quotation generation and PDF/Excel export
- **Attendance** — GPS-verified check-in/check-out, per-role attendance reports, biometric login
- **Leave Management** — submission and multi-stage approval workflow
- **Payroll** — employee payroll profiles, configurable working schedules and calculation rules (hourly/daily rate, late/overtime deduction methods), a full Draft → Processing → Approved → Finalized → Paid processing workflow, payslip PDF generation, a payroll dashboard with charts, 9 exportable report types, a holiday calendar, and a full audit log
- **Finance & Accounting** — Chart of Accounts, Journal Entries, General Ledger, Trial Balance, Balance Sheet, P&L, customer invoicing and receipts
- **Inventory** — stock tracking, tool assignments, transaction history
- **Expenses & Vendor Bills** — two-stage approval workflow
- **Role-based access control** — 12 distinct roles (CEO, Operational Manager, Finance, HSSE, BDM/HR, Store Manager, field employees, vendors, etc.), each with a tailored set of permissions and nav items
- **AI Assistant** — a Groq-backed chat assistant scoped to the signed-in user's own visible data

## Architecture

```mermaid
flowchart LR
    App[Flutter app<br/>Android · iOS · Web · Windows] --> Auth[Firebase Auth<br/>+ biometric login]
    App --> FS[(Cloud Firestore<br/>security rules per role)]
    App --> Gmail[Gmail API<br/>work-order import]
    App --> GPS[Geolocator<br/>verified check-in]
    App --> LLM[Groq LLM<br/>AI assistant]
    App --> Export[PDF / Excel / CSV export]
```

## Tech stack

- **Flutter** (single-codebase multi-platform: Android, iOS, Web, Windows)
- **Firebase** — Firestore (data), Firebase Auth (login), Firebase Hosting (web)
- **Google Sign-In / Gmail API** — automated work order ingestion from a shared mailbox
- **fl_chart** — dashboard charts
- **pdf / excel / share_plus** — in-app report and payslip export (PDF/Excel/CSV)

## Project structure

This app uses a single-library architecture: every screen/model/service file is a `part of '../main.dart'` file, all registered via `part` declarations in `lib/main.dart`. This keeps the whole app as one compilation unit without needing a state management library for cross-screen data access — shared in-memory lists (kept in sync with Firestore) are simply top-level variables any file can read.

```
lib/
  main.dart              # entry point + part registrations
  models/                # data models (WorkOrder, PayrollRecord, AppUser, ...)
  screens/                # one file per screen
  services/               # DataService (Firestore), AuthService, PayrollEngine, ExportService, ...
  widgets/                # shared UI components
```

## Known technical debt

Written down honestly for anyone reviewing the code:

- **Single compilation unit.** Every file is a `part of` `main.dart` and shares top-level state. This was fast to build, but it couples features together. A feature-based layout with a state-management layer (Riverpod or Bloc) is the planned refactor.
- **The LLM key lives on the client.** The AI assistant calls Groq directly, so a key compiled into the app can be extracted. `n8n/` contains a server-side proxy workflow (the key stays in n8n) that is the intended fix but is not wired in yet.
- **Tests.** `test/widget_test.dart` is still the Flutter template test. The payroll engine and accounting logic are the first candidates for real unit tests.

## Running this yourself

This is a showcase copy — the real Firebase project credentials have been replaced with placeholders (`lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `macos/Runner/GoogleService-Info.plist`) and the Groq API key has been removed. To run it against your own backend:

1. Create a Firebase project and run `flutterfire configure` to regenerate `lib/firebase_options.dart` and the platform config files with your own project's real values.
2. Deploy `firestore.rules` to your project.
3. (Optional) Add your own Groq API key to `groqApiKey` in `lib/main.dart` to enable the AI Assistant.
4. `flutter pub get`
5. `flutter run`

## License

Proprietary — built for internal use at Al-Areesh Engineering Solutions. Shared here as a portfolio/showcase of the work.

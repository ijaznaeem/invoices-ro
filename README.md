# Ledger — Invoices RO

Private, on-device invoicing and bookkeeping app for creating invoices, tracking payments, cash, and expenses. Data stays on the device unless you export a backup or enable Google Drive backups.

## Features

- **Invoices** — one-off and recurring schedules, PDF preview/share
- **Partial payments** — record any amount; status moves Pending → Partial → Paid
- **Accounts ledger** — invoices and payments posted automatically (AR, sales, tax, cash)
- **Cash receipts** — payment history plus standalone receipts
- **Expenses by head** — Office, Travel, Utilities, and custom categories
- **Tax rates** — manage % options in Settings; invoices pick from the list (default: No Tax)
- **Clients** — saved contacts for faster billing
- **Dashboard** — outstanding balance, cash/expense KPIs, and charts
- **Backup & restore** — local snapshots; optional Google Drive upload, browse, and restore
- **Business settings** — logo, currency, payment methods on PDFs, terms, signature

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) SDK `>=3.1.0`
- Android device or emulator (API 21+), or Windows / Chrome for desktop/web smoke tests

## Getting started

```bash
flutter pub get
flutter run
```

List devices, then target one explicitly:

```bash
flutter devices
flutter run -d <device_id>
```

## Install on Android phone

**Debug / development**

```bash
flutter run -d <phone_id>
```

**Release APK**

```bash
flutter build apk --release
flutter install -d <phone_id> --release
```

APK output:

```
build/app/outputs/flutter-apk/app-release.apk
```

Copy that file to the phone and open it to sideload, or use `adb install -r` with the same path.

## Google Drive setup

Follow [Google Drive setup](docs/google_drive_setup.md) to enable the API and register
the Android OAuth client for this package and signing certificate. Then connect
your account from **Backup & Restore** and tap **Back up now**.

## Project structure

```
lib/
  main.dart                 # App shell, navigation, drawer
  models/                   # Invoices, clients, ledger, tax, expenses
  db/                       # SQLite schema + recurring generation
  state/                    # AppState (ChangeNotifier)
  screens/                  # Dashboard, invoices, clients, accounts, settings
  widgets/                  # Shared UI pieces
  services/                 # Backup / Drive helpers
  util/                     # Dates, currency, PDF
  theme/                    # Material 3 theme
```

## How key flows work

| Action | Result |
|--------|--------|
| Create invoice | Full-screen form; tax from Settings list; posts to Accounts Receivable / Sales / Tax Payable |
| Record payment | Updates `amount_paid`, cash receipt, ledger Cash ↔ AR |
| Add expense | Debits expense head, credits Cash |
| Recurring due | Generation engine creates invoices when the app opens/resumes |

## Settings you should configure first

1. **Business identity** — name, logo, currency  
2. **Tax rates** — add your VAT/GST % (No Tax is seeded)  
3. **Expense heads** — categories for spending  
4. **Payment options** — bank/card text printed on PDF  

## Data & privacy

- Local SQLite database (`ledger.db`) on device  
- No required cloud account  
- Backup & Restore is optional and user-triggered (or scheduled from preferences)

## Build notes

```bash
flutter analyze
flutter build apk --release
```

Version is set in `pubspec.yaml` (`version: 1.0.0+1`).

## License

Private project — not published to pub.dev (`publish_to: 'none'`).
